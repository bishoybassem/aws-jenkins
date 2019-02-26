provider "aws" {
  region = "eu-central-1"
}

variable "jenkins_version" {
  description = "The jenkins version to use (major.minor only!)"
  default = "2.150"
}

resource "aws_security_group" "jenkins_master" {
  name        = "jenkins_master"
  description = "Allow inbound traffic over port 80, 443 and 22"

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    cidr_blocks     = ["0.0.0.0/0"]
  }
}

resource "random_string" "admin_pass" {
  length = 16
  special = true
}

data "template_file" "jenkins_master_cloud_init_part_1" {
  template = "${file("scripts/master-cloud-config.yml.tpl")}"
  vars {
    jenkins_version = "${var.jenkins_version}"
    admin_pass_hash = "admin_salt:${sha256("${random_string.admin_pass.result}{admin_salt}")}"
    init_groovy = "${file("scripts/master-configure-security.groovy")}"
    nginx_conf = "${file("scripts/master-nginx.conf")}"
  }
}

data "template_file" "jenkins_master_cloud_init_part_2" {
  template = "${file("scripts/master-setup.sh.tpl")}"
  vars {
    jenkins_version = "${var.jenkins_version}"
  }
}

data "template_cloudinit_config" "jenkins_master_init" {
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
  ami              = "ami-05449f21272b4ee56"
  instance_type    = "t2.micro"
  key_name         = "aws"
  security_groups  = ["${aws_security_group.jenkins_master.name}"]
  user_data_base64 = "${data.template_cloudinit_config.jenkins_master_init.rendered}"
}

output "jenkins_master_public_dns" {
  value = "${aws_instance.jenkins_master.public_dns}"
}

output "admin_pass" {
  value = "${random_string.admin_pass.result}"
}