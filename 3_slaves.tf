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

resource "aws_instance" "jenkins_slave" {
  ami                         = "ami-05449f21272b4ee56"
  instance_type               = "t2.micro"
  associate_public_ip_address = false
  key_name                    = "aws"
  subnet_id                   = "${aws_subnet.main_private.id}"
  vpc_security_group_ids      = ["${aws_security_group.jenkins_slave.id}"]
  user_data                   = "${data.template_file.jenkins_slave_cloud_init.rendered}"
}

output "jenkins_slave_private_ip" {
  value = "${aws_instance.jenkins_slave.private_ip}"
}