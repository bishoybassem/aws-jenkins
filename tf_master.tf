resource "random_password" "admin_pass" {
  length  = 16
  special = true
}

resource "aws_secretsmanager_secret" "admin_pass" {
  name                    = "jenkins-admin-password"
  recovery_window_in_days = 0
}

resource "aws_secretsmanager_secret_version" "admin_pass" {
  secret_id     = aws_secretsmanager_secret.admin_pass.id
  secret_string = random_password.admin_pass.result
}

resource "random_password" "slave_pass" {
  length  = 16
  special = true
}

resource "aws_secretsmanager_secret" "slave_pass" {
  name                    = "jenkins-slave-password"
  recovery_window_in_days = 0
}

resource "aws_secretsmanager_secret_version" "slave_pass" {
  secret_id     = aws_secretsmanager_secret.slave_pass.id
  secret_string = random_password.slave_pass.result
}

data "aws_iam_policy_document" "ec2_assume_role_policy" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "jenkins_master_iam_role" {
  name               = "jenkins_master_iam_role"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume_role_policy.json
}

resource "aws_iam_role_policy" "jenkins_master_iam_role_policy" {
  name   = "jenkins_master_iam_role_policy"
  role   = aws_iam_role.jenkins_master_iam_role.id
  policy = <<-EOF
    {
      "Version": "2012-10-17",
      "Statement": [
        {
          "Effect": "Allow",
          "Action": "ec2:DescribeAddresses",
          "Resource": "*"
        },
        {
          "Effect": "Allow",
          "Action": "secretsmanager:GetSecretValue",
          "Resource": "${aws_secretsmanager_secret.admin_pass.arn}"
        },
        {
          "Effect": "Allow",
          "Action": "secretsmanager:GetSecretValue",
          "Resource": "${aws_secretsmanager_secret.slave_pass.arn}"
        }
      ]
    }
  EOF
}

resource "aws_iam_role_policy_attachment" "jenkins_master_iam_role_policy_attachment" {
  role       = aws_iam_role.jenkins_master_iam_role.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

resource "aws_iam_instance_profile" "jenkins_master_iam_role_instance_profile" {
  name = aws_iam_role.jenkins_master_iam_role.name
  role = aws_iam_role.jenkins_master_iam_role.name
}

data "aws_ami" "debian_buster_latest_ami" {
  most_recent = true
  owners      = ["136693071363"]

  filter {
    name   = "name"
    values = ["debian-10-amd64-*"]
  }
}

data "template_cloudinit_config" "jenkins_master_cloud_init" {
  part {
    content_type = "text/cloud-config"
    content      = templatefile("scripts/master-cloud-config.yml.tpl", {
      slaves_subnet   = aws_subnet.main_private.cidr_block
    })
  }
  part {
    content_type = "text/x-shellscript"
    content      = file("scripts/master-setup.sh")
  }
}

resource "aws_instance" "jenkins_master" {
  ami                         = data.aws_ami.debian_buster_latest_ami.id
  instance_type               = "t2.micro"
  associate_public_ip_address = true
  key_name                    = var.key_pair_name
  subnet_id                   = aws_subnet.main_public.id
  vpc_security_group_ids      = [aws_security_group.jenkins_master.id]
  user_data_base64            = data.template_cloudinit_config.jenkins_master_cloud_init.rendered

  // Disable source_dest_check as the master node acts as NAT server for the slaves to access the internet.
  source_dest_check    = false
  iam_instance_profile = aws_iam_instance_profile.jenkins_master_iam_role_instance_profile.name
  depends_on           = [aws_eip.jenkins_master_ip]
  tags = {
    Name               = "jenkins_master"
    JenkinsVersion     = var.jenkins_version
    SwarmPluginVersion = var.swarm_plugin_version
  }

  // Wait until the master node starts.
  provisioner "local-exec" {
    command = " while ! nc -zv -w 2 ${aws_instance.jenkins_master.public_dns} 443; do sleep 5s; done"
  }
}

resource "aws_cloudwatch_metric_alarm" "jenkins_recover_master" {
  alarm_name          = "jenkins_recover_master"
  alarm_description   = "Recover master machine in case the system check fails for 2 minutes"
  namespace           = "AWS/EC2"
  metric_name         = "StatusCheckFailed_System"
  period              = 60
  statistic           = "Minimum"
  comparison_operator = "GreaterThanThreshold"
  threshold           = 0
  evaluation_periods  = 2
  alarm_actions       = ["arn:aws:automate:${var.region}:ec2:recover"]

  dimensions = {
    InstanceId = aws_instance.jenkins_master.id
  }
}

resource "aws_cloudwatch_metric_alarm" "jenkins_restart_master" {
  alarm_name          = "jenkins_restart_master"
  alarm_description   = "Restart master machine in case the jenkins service is down for 3 minutes"
  namespace           = "CWAgent"
  metric_name         = "jenkins_service"
  period              = 60
  statistic           = "Minimum"
  comparison_operator = "LessThanThreshold"
  threshold           = 1
  evaluation_periods  = 3
  alarm_actions       = ["arn:aws:automate:${var.region}:ec2:reboot"]

  dimensions = {
    InstanceId  = aws_instance.jenkins_master.id
    metric_type = "gauge"
  }
}

resource "aws_cloudwatch_log_group" "jenkins_log_group" {
  name              = "jenkins"
  retention_in_days = 14
}
