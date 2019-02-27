
resource "aws_instance" "jenkins_slave" {
  ami                         = "ami-05449f21272b4ee56"
  instance_type               = "t2.micro"
  associate_public_ip_address = false
  key_name                    = "aws"
  subnet_id                   = "${aws_subnet.main_private.id}"
  vpc_security_group_ids      = ["${aws_security_group.jenkins_slave.id}"]
}

output "jenkins_slave_private_ip" {
  value = "${aws_instance.jenkins_slave.private_ip}"
}