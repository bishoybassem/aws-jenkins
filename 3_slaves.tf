variable "slave_count" {
  default = 1
}

variable "slave_max_count" {
  default = 3
}

data "template_file" "jenkins_slave_service" {
  template = "${file("scripts/slave-jenkins.service.tpl")}"

  vars {
    master_url = "http://${aws_instance.jenkins_master.private_ip}:8082"
  }
}

data "template_file" "jenkins_slave_cloud_init" {
  template = "${file("scripts/slave-cloud-config.yml.tpl")}"

  vars {
    swarm_plugin_version = "${var.swarm_plugin_version}"
    slave_service        = "${data.template_file.jenkins_slave_service.rendered}"
  }
}

resource "aws_launch_template" "jenkins_slave_launch_template" {
  image_id                    = "ami-05449f21272b4ee56"
  instance_type               = "t2.micro"
  key_name                    = "${var.key_pair_name}"
  vpc_security_group_ids      = ["${aws_security_group.jenkins_slave.id}"]
  user_data                   = "${base64encode(data.template_file.jenkins_slave_cloud_init.rendered)}"

  tag_specifications {
    resource_type = "instance"
    tags          = {
      Name = "jenkins_slave"
    }
  }
}

resource "aws_autoscaling_group" "jenkins_slaves_autoscaling_group" {
  name                = "jenkins_slaves"
  min_size            = "${var.slave_count}"
  max_size            = "${var.slave_max_count}"
  vpc_zone_identifier = ["${aws_subnet.main_private.id}"]
  health_check_type   = "EC2"

  launch_template {
    id      = "${aws_launch_template.jenkins_slave_launch_template.id}"
    version = "$$Latest"
  }
}

resource "aws_autoscaling_policy" "jenkins_slaves_scale_up_policy" {
  name                      = "jenkins_slaves_scale_up_policy"
  policy_type               = "StepScaling"
  adjustment_type           = "ChangeInCapacity"
  autoscaling_group_name    = "${aws_autoscaling_group.jenkins_slaves_autoscaling_group.name}"
  estimated_instance_warmup = 120

  step_adjustment {
    scaling_adjustment          = 1
    metric_interval_lower_bound = 0
  }
}

resource "aws_cloudwatch_metric_alarm" "jenkins_long_waiting_queue" {
  alarm_name          = "jenkins_long_waiting_queue"
  alarm_description   = "Trigger scaling up policy if queue has more than 2 builds waiting for at least 5 minutes"
  namespace           = "CWAgent"
  metric_name         = "jenkins_queue"
  period              = 60
  statistic           = "Average"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  threshold           = 2
  evaluation_periods  = 5
  alarm_actions       = ["${aws_autoscaling_policy.jenkins_slaves_scale_up_policy.arn}"]

  dimensions {
    InstanceId  = "${aws_instance.jenkins_master.id}"
    metric_type = "gauge"
  }
}