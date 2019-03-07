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
    tags = {
      Name = "jenkins_slave"
    }
  }
}

resource "aws_autoscaling_group" "jenkins_slave_autoscaling_group" {
  name                = "jenkins_slaves"
  desired_capacity    = "${var.slave_count}"
  min_size            = "${var.slave_count}"
  max_size            = "${var.slave_max_count}"
  vpc_zone_identifier = ["${aws_subnet.main_private.id}"]

  launch_template {
    id      = "${aws_launch_template.jenkins_slave_launch_template.id}"
    version = "$$Latest"
  }
}