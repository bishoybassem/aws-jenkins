resource "aws_iam_role" "jenkins_slave_iam_role" {
  name               = "jenkins_slave_iam_role"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume_role_policy.json
}

resource "aws_iam_role_policy" "jenkins_slave_iam_role_policy" {
  name   = "jenkins_slave_iam_role_policy"
  role   = aws_iam_role.jenkins_slave_iam_role.id
  policy = <<-EOF
    {
      "Version": "2012-10-17",
      "Statement": [
        {
          "Effect": "Allow",
          "Action": "autoscaling:DescribeAutoScalingInstances",
          "Resource": "*"
        },
        {
          "Effect": "Allow",
          "Action": [
            "autoscaling:CompleteLifecycleAction",
            "autoscaling:RecordLifecycleActionHeartbeat"
          ],
          "Resource": "${aws_autoscaling_group.jenkins_slaves_autoscaling_group.arn}"
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

resource "aws_iam_role_policy_attachment" "jenkins_slave_iam_role_policy_attachment" {
  role       = aws_iam_role.jenkins_slave_iam_role.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

resource "aws_iam_instance_profile" "jenkins_slave_iam_role_instance_profile" {
  name = aws_iam_role.jenkins_slave_iam_role.name
  role = aws_iam_role.jenkins_slave_iam_role.name
}

data "template_cloudinit_config" "jenkins_slave_cloud_init" {
  part {
    content_type = "text/cloud-config"
    content      = templatefile("scripts/slave-cloud-config.yml.tpl", {})
  }
  part {
    content_type = "text/x-shellscript"
    content      = file("scripts/slave-setup.sh")
  }
}

resource "aws_launch_template" "jenkins_slave_launch_template" {
  image_id               = data.aws_ami.debian_buster_latest_ami.id
  instance_type          = var.instance_type_slave
  key_name               = var.key_pair_name
  vpc_security_group_ids = [aws_security_group.jenkins_slave.id]
  user_data              = data.template_cloudinit_config.jenkins_slave_cloud_init.rendered

  iam_instance_profile {
    name = aws_iam_instance_profile.jenkins_slave_iam_role_instance_profile.name
  }

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name               = "jenkins_slave"
      MasterHost         = aws_eip.jenkins_master_ip.public_dns
      SwarmPluginVersion = var.swarm_plugin_version
      NumExecutors       = var.num_executors_slave
    }
  }
}

resource "aws_autoscaling_group" "jenkins_slaves_autoscaling_group" {
  name                 = "jenkins_slaves"
  min_size             = var.slave_count
  max_size             = var.slave_max_count
  vpc_zone_identifier  = [aws_subnet.main_private_1.id, aws_subnet.main_private_2.id]
  health_check_type    = "EC2"
  termination_policies = ["OldestLaunchTemplate", "OldestInstance"]
  depends_on           = [null_resource.private_subnets_ready]

  launch_template {
    id      = aws_launch_template.jenkins_slave_launch_template.id
    version = "$Latest"
  }

  initial_lifecycle_hook {
    name                 = "slave_termination_hook"
    lifecycle_transition = "autoscaling:EC2_INSTANCE_TERMINATING"
    heartbeat_timeout    = 300
  }
}

resource "aws_autoscaling_policy" "jenkins_slaves_scale_out_policy" {
  name                      = "jenkins_slaves_scale_out_policy"
  policy_type               = "StepScaling"
  adjustment_type           = "ChangeInCapacity"
  autoscaling_group_name    = aws_autoscaling_group.jenkins_slaves_autoscaling_group.name
  estimated_instance_warmup = 300

  step_adjustment {
    scaling_adjustment          = 1
    metric_interval_lower_bound = 0
  }
}

resource "aws_cloudwatch_metric_alarm" "jenkins_long_waiting_queue" {
  alarm_name          = "jenkins_long_waiting_queue"
  alarm_description   = "Trigger scaling out policy if the queue has more than/equal ${var.slaves_scale_out_queue_size} builds waiting for at least ${var.slaves_scale_out_queue_size_period} minutes"
  namespace           = "CWAgent"
  metric_name         = "jenkins_queue"
  period              = 60
  statistic           = "Average"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  threshold           = var.slaves_scale_out_queue_size
  evaluation_periods  = var.slaves_scale_out_queue_size_period
  alarm_actions       = [aws_autoscaling_policy.jenkins_slaves_scale_out_policy.arn]

  dimensions = {
    InstanceId  = aws_instance.jenkins_master.id
    metric_type = "gauge"
  }
}

resource "aws_autoscaling_policy" "jenkins_slaves_scale_in_policy" {
  name                   = "jenkins_slaves_scale_in_policy"
  policy_type            = "SimpleScaling"
  adjustment_type        = "ChangeInCapacity"
  scaling_adjustment     = -1
  cooldown               = 120
  autoscaling_group_name = aws_autoscaling_group.jenkins_slaves_autoscaling_group.name
}

resource "aws_cloudwatch_metric_alarm" "jenkins_empty_queue" {
  alarm_name          = "jenkins_empty_queue"
  alarm_description   = "Trigger scaling in policy if the queue has less than ${var.slaves_scale_in_queue_size} builds for at least ${var.slaves_scale_in_queue_size_period} minutes"
  namespace           = "CWAgent"
  metric_name         = "jenkins_queue"
  period              = 60
  statistic           = "Average"
  comparison_operator = "LessThanThreshold"
  threshold           = var.slaves_scale_in_queue_size
  evaluation_periods  = var.slaves_scale_in_queue_size_period
  alarm_actions       = [aws_autoscaling_policy.jenkins_slaves_scale_in_policy.arn]

  dimensions = {
    InstanceId  = aws_instance.jenkins_master.id
    metric_type = "gauge"
  }
}