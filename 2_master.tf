variable "key_pair_name" {
  description = "Name of an existing EC2 key pair"
  default     = "aws"
}

variable "jenkins_version" {
  description = "The jenkins version to use (major.minor only!)"
  default     = "2.150"
}

variable "swarm_plugin_version" {
  description = "The swarm plugin version to use"
  default     = "3.15"
}

resource "random_string" "admin_pass" {
  length  = 16
  special = true
}

resource "random_string" "slave_pass" {
  length  = 16
  special = true
}

resource "random_string" "monitoring_pass" {
  length  = 16
  special = true
}

locals {
  # Workaround the issue that terraform doesn't update the public dns name of the instance after elastic ip association.
  master_public_dns = "ec2-${replace(aws_eip.jenkins_master_ip.public_ip, ".", "-")}.${var.region}.compute.amazonaws.com"
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

resource "aws_iam_role" "cloud_watch_ec2_role" {
  name               = "cloud-watch-ec2-role"
  assume_role_policy = "${data.aws_iam_policy_document.ec2_assume_role_policy.json}"
}

resource "aws_iam_role_policy_attachment" "cloud_watch_ec2_role_attachment" {
  role       = "${aws_iam_role.cloud_watch_ec2_role.name}"
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

resource "aws_iam_instance_profile" "cloud_watch_ec2_role_instance_profile" {
  name = "${aws_iam_role.cloud_watch_ec2_role.name}"
  role = "${aws_iam_role.cloud_watch_ec2_role.name}"
}

data "aws_ami" "debian_stretch_latest_ami" {
  most_recent      = true
  owners           = ["379101102735"]

  filter {
    name = "name"
    values = ["debian-stretch-hvm-x86_64-gp2-*"]
  }
}

data "template_file" "jenkins_master_nginx_config" {
  template = "${file("scripts/master-nginx.conf.tpl")}"

  vars {
    auth_header = "${base64encode("slave:${random_string.slave_pass.result}")}"
  }
}

data "template_file" "jenkins_master_cloud_init_part_1" {
  template = "${file("scripts/master-cloud-config.yml.tpl")}"

  vars {
    jenkins_version = "${var.jenkins_version}"
    admin_pass_hash = "admin_salt:${sha256("${random_string.admin_pass.result}{admin_salt}")}"
    slave_pass      = "${random_string.slave_pass.result}"
    monitoring_pass = "${random_string.monitoring_pass.result}"
    nginx_conf      = "${data.template_file.jenkins_master_nginx_config.rendered}"
    slaves_subnet   = "${aws_subnet.main_private.cidr_block}"
  }
}

data "template_file" "jenkins_master_cloud_init_part_2" {
  template = "${file("scripts/master-setup.sh.tpl")}"

  vars {
    jenkins_version      = "${var.jenkins_version}"
    swarm_plugin_version = "${var.swarm_plugin_version}"
    master_public_dns    = "${local.master_public_dns}"
  }
}

data "template_cloudinit_config" "jenkins_master_cloud_init" {
  part {
    content_type = "text/cloud-config"
    content      = "${data.template_file.jenkins_master_cloud_init_part_1.rendered}"
  }

  part {
    content_type = "text/x-shellscript"
    content      = "${data.template_file.jenkins_master_cloud_init_part_2.rendered}"
  }
}

resource "aws_instance" "jenkins_master" {
  ami                         = "${data.aws_ami.debian_stretch_latest_ami.id}"
  instance_type               = "t2.micro"
  associate_public_ip_address = true
  key_name                    = "${var.key_pair_name}"
  subnet_id                   = "${aws_subnet.main_public.id}"
  vpc_security_group_ids      = ["${aws_security_group.jenkins_master.id}"]
  user_data_base64            = "${data.template_cloudinit_config.jenkins_master_cloud_init.rendered}"
  // Disable source_dest_check as the master node acts as NAT server for the slaves to access the internet.
  source_dest_check           = false
  iam_instance_profile        = "${aws_iam_instance_profile.cloud_watch_ec2_role_instance_profile.name}"
  tags                        = {
    Name = "jenkins_master"
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

  dimensions {
    InstanceId = "${aws_instance.jenkins_master.id}"
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

  dimensions {
    InstanceId  = "${aws_instance.jenkins_master.id}"
    metric_type = "gauge"
  }
}

resource "aws_cloudwatch_log_group" "jenkins_log_group" {
  name              = "jenkins"
  retention_in_days = 14
}


output "jenkins_master_public_dns" {
  value = "${local.master_public_dns}"
}

output "admin_pass" {
  value = "${random_string.admin_pass.result}"
}