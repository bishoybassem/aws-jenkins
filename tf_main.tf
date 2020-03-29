terraform {
  required_version = ">= 0.12"
}

provider "aws" {
  region = var.region
}

resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  tags = {
    Name = "main"
  }
}

resource "aws_internet_gateway" "main_gateway" {
  vpc_id = aws_vpc.main.id
}

resource "aws_subnet" "main_public" {
  vpc_id     = aws_vpc.main.id
  cidr_block = "10.0.1.0/25"
  tags = {
    Name = "main_public"
  }
}

resource "aws_route_table" "main_public_route_table" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main_gateway.id
  }
}

resource "aws_route_table_association" "main_public_route_table_association" {
  subnet_id      = aws_subnet.main_public.id
  route_table_id = aws_route_table.main_public_route_table.id
}

resource "aws_network_acl" "main_public_acl" {
  vpc_id     = aws_vpc.main.id
  subnet_ids = [aws_subnet.main_public.id]

  ingress {
    rule_no    = 110
    action     = "allow"
    protocol   = "tcp"
    cidr_block = "0.0.0.0/0"
    from_port  = 80
    to_port    = 80
  }

  ingress {
    rule_no    = 120
    action     = "allow"
    protocol   = "tcp"
    cidr_block = aws_subnet.main_private.cidr_block
    from_port  = 8081
    to_port    = 8081
  }

  ingress {
    rule_no    = 130
    action     = "allow"
    protocol   = "tcp"
    cidr_block = "0.0.0.0/0"
    from_port  = 443
    to_port    = 443
  }

  ingress {
    rule_no    = 140
    action     = "allow"
    protocol   = "tcp"
    cidr_block = "0.0.0.0/0"
    from_port  = 22
    to_port    = 22
  }

  ingress {
    rule_no    = 150
    action     = "allow"
    protocol   = "tcp"
    cidr_block = "0.0.0.0/0"
    from_port  = 32768
    to_port    = 61000
  }

  egress {
    rule_no    = 160
    action     = "allow"
    protocol   = "tcp"
    cidr_block = "0.0.0.0/0"
    from_port  = 80
    to_port    = 80
  }

  egress {
    rule_no    = 170
    action     = "allow"
    protocol   = "tcp"
    cidr_block = "0.0.0.0/0"
    from_port  = 443
    to_port    = 443
  }

  egress {
    rule_no    = 180
    action     = "allow"
    protocol   = "tcp"
    cidr_block = "0.0.0.0/0"
    from_port  = 22
    to_port    = 22
  }

  egress {
    rule_no    = 190
    action     = "allow"
    protocol   = "tcp"
    cidr_block = "0.0.0.0/0"
    from_port  = 1024
    to_port    = 65535
  }
}

resource "aws_security_group" "jenkins_master" {
  name        = "jenkins_master"
  description = "Allow inbound traffic [ports: 80, 8081, 443, 22] and all outbound traffic"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  // Allow slaves to connect to JNLP port 8081
  ingress {
    from_port       = 8081
    to_port         = 8081
    protocol        = "tcp"
    security_groups = [aws_security_group.jenkins_slave.id]
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

resource "aws_subnet" "main_private" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.1.128/25"
  availability_zone = aws_subnet.main_public.availability_zone
  tags = {
    Name = "main_private"
  }
}

resource "aws_route_table" "main_private_route_table" {
  vpc_id = aws_vpc.main.id

  # Route the traffic to the internet through the master node, i.e. the master node acts as a NAT server.
  route {
    cidr_block  = "0.0.0.0/0"
    instance_id = aws_instance.jenkins_master.id
  }
}

resource "aws_route_table_association" "main_private_route_table_association" {
  subnet_id      = aws_subnet.main_private.id
  route_table_id = aws_route_table.main_private_route_table.id
}

resource "aws_network_acl" "main_private_acl" {
  vpc_id     = aws_vpc.main.id
  subnet_ids = [aws_subnet.main_private.id]

  ingress {
    rule_no    = 210
    action     = "allow"
    protocol   = "tcp"
    cidr_block = aws_subnet.main_public.cidr_block
    from_port  = 22
    to_port    = 22
  }

  ingress {
    rule_no    = 220
    action     = "allow"
    protocol   = "tcp"
    cidr_block = "0.0.0.0/0"
    from_port  = 32768
    to_port    = 61000
  }

  egress {
    rule_no    = 230
    action     = "allow"
    protocol   = "tcp"
    cidr_block = "0.0.0.0/0"
    from_port  = 80
    to_port    = 80
  }

  egress {
    rule_no    = 240
    action     = "allow"
    protocol   = "tcp"
    cidr_block = "0.0.0.0/0"
    from_port  = 443
    to_port    = 443
  }

  egress {
    rule_no    = 250
    action     = "allow"
    protocol   = "tcp"
    cidr_block = "0.0.0.0/0"
    from_port  = 8081
    to_port    = 8081
  }

  egress {
    rule_no    = 260
    action     = "allow"
    protocol   = "tcp"
    cidr_block = "0.0.0.0/0"
    from_port  = 32768
    to_port    = 61000
  }
}

resource "aws_security_group" "jenkins_slave" {
  name        = "jenkins_slave"
  description = "Allow inbound traffic [ports: 22] and all outbound traffic"
  vpc_id      = aws_vpc.main.id
}

# Only allow ssh connections from the master node, i.e. the master node acts as a bastion host.
resource "aws_security_group_rule" "jenkins_slave_ingress_allow_ssh" {
  type                     = "ingress"
  from_port                = 22
  to_port                  = 22
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.jenkins_master.id
  security_group_id        = aws_security_group.jenkins_slave.id
}

resource "aws_security_group_rule" "jenkins_slave_egress_allow_all" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.jenkins_slave.id
}

resource "aws_eip" "jenkins_master_ip" {
  vpc        = true
  depends_on = [aws_internet_gateway.main_gateway]

  tags = {
    Name = "jenkins_master"
  }
}

# Use ip association to avoid changing the ip in case the master instance changes.
resource "aws_eip_association" "jenkins_master_ip_association" {
  allocation_id = aws_eip.jenkins_master_ip.id
  instance_id   = aws_instance.jenkins_master.id
}