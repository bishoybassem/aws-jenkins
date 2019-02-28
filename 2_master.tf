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
    nginx_conf      = "${data.template_file.jenkins_master_nginx_config.rendered}"
    slaves_subnet   = "${aws_subnet.main_private.cidr_block}"
  }
}

data "template_file" "jenkins_master_cloud_init_part_2" {
  template = "${file("scripts/master-setup.sh.tpl")}"
  vars {
    jenkins_version      = "${var.jenkins_version}"
    swarm_plugin_version = "${var.swarm_plugin_version}"
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
  ami                         = "ami-05449f21272b4ee56"
  instance_type               = "t2.micro"
  associate_public_ip_address = true
  key_name                    = "${var.key_pair_name}"
  subnet_id                   = "${aws_subnet.main_public.id}"
  vpc_security_group_ids      = ["${aws_security_group.jenkins_master.id}"]
  user_data_base64            = "${data.template_cloudinit_config.jenkins_master_init.rendered}"
  // Disable source_dest_check as the master node acts as NAT server for the slaves to access the internet.
  source_dest_check           = false

  // Wait until the master node starts.
  provisioner "local-exec" {
    command = " while ! nc -zv -w 2 ${aws_instance.jenkins_master.public_dns} 443; do sleep 5s; done"
  }
}

output "jenkins_master_public_dns" {
  value = "${aws_instance.jenkins_master.public_dns}"
}

output "admin_pass" {
  value = "${random_string.admin_pass.result}"
}