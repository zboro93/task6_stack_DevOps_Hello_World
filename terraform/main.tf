terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.5.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.1"
    }
  }
}

provider "aws" {
  region = "eu-central-1"

}

data "aws_ami" "ubuntu" {
  most_recent = true
  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"]
  }

  owners = ["099720109477"]
}

resource "aws_vpc" "my_vpc" {
  cidr_block = "10.0.0.0/16"
}

resource "aws_internet_gateway" "internet_gateway" {
  vpc_id = aws_vpc.my_vpc.id

  tags = {
    build = "Terraform"
  }
}

resource "aws_subnet" "public_subnet_1" {
  vpc_id            = aws_vpc.my_vpc.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = "eu-central-1a"
  tags = {
    build = "Terraform"
  }
}

resource "aws_security_group" "sg_allow_required_ports" {
  name        = "sg_allow_required_ports"
  description = "Allow SSH and HTTP"
  vpc_id      = aws_vpc.my_vpc.id

  tags = {
    build = "Terraform"
  }
}


resource "aws_route_table" "route_table" {
  vpc_id = aws_vpc.my_vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.internet_gateway.id
  }
  tags = {
    build = "Terraform"
  }
}

resource "aws_route_table_association" "rt_association" {
  subnet_id      = aws_subnet.public_subnet_1.id
  route_table_id = aws_route_table.route_table.id
}

resource "aws_vpc_security_group_ingress_rule" "rule_allow_ssh_in" {
  security_group_id = aws_security_group.sg_allow_required_ports.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 22
  ip_protocol       = "tcp"
  to_port           = 22
}

resource "aws_vpc_security_group_ingress_rule" "rule_allow_http_in" {
  security_group_id = aws_security_group.sg_allow_required_ports.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 80
  ip_protocol       = "tcp"
  to_port           = 80
}

resource "aws_vpc_security_group_egress_rule" "rule_allow_http_out" {
  security_group_id = aws_security_group.sg_allow_required_ports.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 80
  ip_protocol       = "tcp"
  to_port           = 80
}

resource "aws_vpc_security_group_ingress_rule" "rule_allow_https_in" {
  security_group_id = aws_security_group.sg_allow_required_ports.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 443
  ip_protocol       = "tcp"
  to_port           = 443
}

resource "aws_vpc_security_group_egress_rule" "rule_allow_https_out" {
  security_group_id = aws_security_group.sg_allow_required_ports.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 443
  ip_protocol       = "tcp"
  to_port           = 443
}

resource "aws_key_pair" "deployer" {
  key_name   = "MyAWSKey"
  public_key = file("~/.ssh/MyAWSKey.pub")
}

resource "aws_instance" "app_server" {
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = "t2.micro"
  subnet_id                   = aws_subnet.public_subnet_1.id
  vpc_security_group_ids      = [aws_security_group.sg_allow_required_ports.id]
  associate_public_ip_address = true
  key_name                    = aws_key_pair.deployer.key_name
  tags = {
    build = "Terraform"
  }
}

output "ubuntu_public_ip" {
  value = aws_instance.app_server.public_ip
}

