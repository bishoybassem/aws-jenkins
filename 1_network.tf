provider "aws" {
  region = "eu-central-1"
}

resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
}

resource "aws_internet_gateway" "main_gateway" {
  vpc_id = "${aws_vpc.main.id}"
}

resource "aws_subnet" "main_public" {
  vpc_id     = "${aws_vpc.main.id}"
  cidr_block = "10.0.1.0/25"
}

resource "aws_route_table" "main_public_route_table" {
  vpc_id = "${aws_vpc.main.id}"

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = "${aws_internet_gateway.main_gateway.id}"
  }
}

resource "aws_route_table_association" "main_public_route_table_association" {
  subnet_id      = "${aws_subnet.main_public.id}"
  route_table_id = "${aws_route_table.main_public_route_table.id}"
}

resource "aws_subnet" "main_private" {
  vpc_id     = "${aws_vpc.main.id}"
  cidr_block = "10.0.1.128/25"
}

resource "aws_route_table" "main_private_route_table" {
  vpc_id = "${aws_vpc.main.id}"

  // Route the traffic to the internet through the master node, i.e. the master node acts as a NAT server.
  route {
    cidr_block = "0.0.0.0/0"
    instance_id = "${aws_instance.jenkins_master.id}"
  }
}

resource "aws_route_table_association" "main_private_route_table_association" {
  subnet_id      = "${aws_subnet.main_private.id}"
  route_table_id = "${aws_route_table.main_private_route_table.id}"
}

resource "aws_security_group" "jenkins_master" {
  name        = "jenkins_master"
  description = "Allow inbound traffic over port 80, 443 and 22"
  vpc_id      = "${aws_vpc.main.id}"

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
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "jenkins_slave" {
  name        = "jenkins_slave"
  description = "Allow inbound traffic over port 80, 443 and 22"
  vpc_id      = "${aws_vpc.main.id}"

  // Only allow ssh connections from the master node, i.e. the master node acts as a bastion host.
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    security_groups = ["${aws_security_group.jenkins_master.id}"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

