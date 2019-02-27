variable "jenkins_version" {
  description = "The jenkins version to use (major.minor only!)"
  default     = "2.150"
}

resource "random_string" "admin_pass" {
  length  = 16
  special = true
}

data "template_file" "jenkins_master_cloud_init_part_1" {
  template = "${file("scripts/master-cloud-config.yml.tpl")}"
  vars {
    jenkins_version = "${var.jenkins_version}"
    admin_pass_hash = "admin_salt:${sha256("${random_string.admin_pass.result}{admin_salt}")}"
    init_groovy     = "${file("scripts/master-configure-security.groovy")}"
    nginx_conf      = "${file("scripts/master-nginx.conf")}"
    slaves_subnet   = "${aws_subnet.main_private.cidr_block}"
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
  ami                         = "ami-05449f21272b4ee56"
  instance_type               = "t2.micro"
  associate_public_ip_address = true
  key_name                    = "aws"
  subnet_id                   = "${aws_subnet.main_public.id}"
  vpc_security_group_ids      = ["${aws_security_group.jenkins_master.id}"]
  user_data_base64            = "${data.template_cloudinit_config.jenkins_master_init.rendered}"
  // Disable source_dest_check as the master node acts as NAT server for the slaves to access the internet.
  source_dest_check           = false
}

output "jenkins_master_public_dns" {
  value = "${aws_instance.jenkins_master.public_dns}"
}

output "admin_pass" {
  value = "${random_string.admin_pass.result}"
}