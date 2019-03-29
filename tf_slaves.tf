variable "slave_count" {
  default     = 1
  description = "Minimum number of slaves to have"
}

variable "slave_max_count" {
  default     = 3
  description = "Maximum number of slaves possible"
}

resource "aws_iam_role" "jenkins_slave_iam_role" {
  name               = "jenkins_slave_iam_role"
  assume_role_policy = "${data.aws_iam_policy_document.ec2_assume_role_policy.json}"
}

data "aws_iam_policy_document" "jenkins_slave_iam_policy_document" {
  statement {
    actions   = [
      "autoscaling:DescribeAutoScalingInstances",
      "ec2:DescribeAddresses"
    ]
    resources = ["*"]
  }

  statement {
    actions   = [
      "autoscaling:CompleteLifecycleAction",
      "autoscaling:RecordLifecycleActionHeartbeat"
    ]
    resources = ["arn:aws:autoscaling:${var.region}:${data.aws_caller_identity.current.account_id}:autoScalingGroup:*:autoScalingGroupName/jenkins_slaves"]
  }
}

resource "aws_iam_role_policy" "jenkins_slave_iam_role_policy" {
  name   = "jenkins_slave_iam_role_policy"
  role   = "${aws_iam_role.jenkins_slave_iam_role.id}"
  policy = "${data.aws_iam_policy_document.jenkins_slave_iam_policy_document.json}"
}

resource "aws_iam_role_policy_attachment" "jenkins_slave_iam_role_policy_attachment" {
  role       = "${aws_iam_role.jenkins_slave_iam_role.name}"
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

resource "aws_iam_instance_profile" "jenkins_slave_iam_role_instance_profile" {
  name = "${aws_iam_role.jenkins_slave_iam_role.name}"
  role = "${aws_iam_role.jenkins_slave_iam_role.name}"
}

data "template_file" "jenkins_slave_cloud_init_part_1" {
  template = "${file("scripts/slave-cloud-config.yml.tpl")}"
}

data "template_cloudinit_config" "jenkins_slave_cloud_init" {
  part {
    content_type = "text/cloud-config"
    content      = "${data.template_file.jenkins_slave_cloud_init_part_1.rendered}"
  }

  part {
    content_type = "text/x-shellscript"
    content      = "${file("scripts/slave-setup.sh")}"
  }
}

resource "aws_launch_template" "jenkins_slave_launch_template" {
  image_id                    = "${data.aws_ami.debian_stretch_latest_ami.id}"
  instance_type               = "t2.micro"
  key_name                    = "${var.key_pair_name}"
  vpc_security_group_ids      = ["${aws_security_group.jenkins_slave.id}"]
  user_data                   = "${data.template_cloudinit_config.jenkins_slave_cloud_init.rendered}"

  iam_instance_profile {
    name = "${aws_iam_instance_profile.jenkins_slave_iam_role_instance_profile.name}"
  }

  tag_specifications {
    resource_type = "instance"
    tags          = {
      Name               = "jenkins_slave"
      SwarmPluginVersion = "${var.swarm_plugin_version}"
    }
  }
}

resource "aws_autoscaling_group" "jenkins_slaves_autoscaling_group" {
  name                 = "jenkins_slaves"
  min_size             = "${var.slave_count}"
  max_size             = "${var.slave_max_count}"
  vpc_zone_identifier  = ["${aws_subnet.main_private.id}"]
  health_check_type    = "EC2"
  termination_policies = ["OldestLaunchTemplate", "OldestInstance"]
  depends_on           = ["aws_instance.jenkins_master"]

  launch_template {
    id      = "${aws_launch_template.jenkins_slave_launch_template.id}"
    version = "$$Latest"
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
  autoscaling_group_name    = "${aws_autoscaling_group.jenkins_slaves_autoscaling_group.name}"
  estimated_instance_warmup = 300

  step_adjustment {
    scaling_adjustment          = 1
    metric_interval_lower_bound = 0
  }
}

resource "aws_cloudwatch_metric_alarm" "jenkins_long_waiting_queue" {
  alarm_name          = "jenkins_long_waiting_queue"
  alarm_description   = "Trigger scaling out policy if the queue has more than 2 builds waiting for at least 5 minutes"
  namespace           = "CWAgent"
  metric_name         = "jenkins_queue"
  period              = 60
  statistic           = "Average"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  threshold           = 2
  evaluation_periods  = 5
  alarm_actions       = ["${aws_autoscaling_policy.jenkins_slaves_scale_out_policy.arn}"]

  dimensions {
    InstanceId  = "${aws_instance.jenkins_master.id}"
    metric_type = "gauge"
  }
}

resource "aws_autoscaling_policy" "jenkins_slaves_scale_in_policy" {
  name                      = "jenkins_slaves_scale_in_policy"
  policy_type               = "SimpleScaling"
  adjustment_type           = "ChangeInCapacity"
  scaling_adjustment        = -1
  cooldown                  = 120
  autoscaling_group_name    = "${aws_autoscaling_group.jenkins_slaves_autoscaling_group.name}"
}

resource "aws_cloudwatch_metric_alarm" "jenkins_empty_queue" {
  alarm_name          = "jenkins_empty_queue"
  alarm_description   = "Trigger scaling in policy if the queue is empty for at least 10 minutes"
  namespace           = "CWAgent"
  metric_name         = "jenkins_queue"
  period              = 60
  statistic           = "Average"
  comparison_operator = "LessThanThreshold"
  threshold           = 1
  evaluation_periods  = 10
  alarm_actions       = ["${aws_autoscaling_policy.jenkins_slaves_scale_in_policy.arn}"]

  dimensions {
    InstanceId  = "${aws_instance.jenkins_master.id}"
    metric_type = "gauge"
  }
}