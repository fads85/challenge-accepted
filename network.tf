// Creating VPC_Terraform
variable "aws_vpc_subnet" {
  type    = "string"
  default = "10.20.0.0/24"
}

variable "aws_vpc_subnet1" {
  type    = "string"
  default = "10.20.1.0/24"
}

variable "vpc_cidr" {
  type    = "string"
  default = "10.0.0.0/8"
}

provider "aws" {}

resource "aws_vpc" "VPC_Terraform" {
  cidr_block           = "${var.vpc_cidr}"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags {
    Name               = "VPC_Terraform"
  }
}

/*====
Creating Subnet
======*/
// Internet gateway
resource "aws_internet_gateway" "igw" {
  vpc_id        = "${aws_vpc.VPC_Terraform.id}"

  tags {
    Name        = "VPC_Terraform-igw"
  }
}

/* subnet */
resource "aws_subnet" "subnet" {
  vpc_id                  = "${aws_vpc.VPC_Terraform.id}"
  cidr_block              = "${var.aws_vpc_subnet}"
  map_public_ip_on_launch = true
  availability_zone       = "us-east-1a"
  tags {
    Name                  = "public-subnet-1a"
  }
}

resource "aws_subnet" "subnet1" {
  vpc_id                  = "${aws_vpc.VPC_Terraform.id}"
  cidr_block              = "${var.aws_vpc_subnet1}"
  map_public_ip_on_launch = true
  availability_zone       = "us-east-1b"

  tags {
    Name                  = "public-subnet-1b"
  }
}

/* Routing table for public subnet */
resource "aws_route_table" "rt-public" {
  vpc_id        = "${aws_vpc.VPC_Terraform.id}"

  tags {
    Name        = "public-route-table"
  }
}

resource "aws_route" "public_internet_gateway" {
  route_table_id         = "${aws_route_table.rt-public.id}"
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = "${aws_internet_gateway.igw.id}"
}

/* Route table associations */
resource "aws_route_table_association" "public" {
  subnet_id      = "${aws_subnet.subnet.id}"
  route_table_id = "${aws_route_table.rt-public.id}"
}

/*====
VPC's Default Security Group
======*/
resource "aws_security_group" "default" {
  name        = "SG-default"
  description = "Default security VPC"
  vpc_id      = "${aws_vpc.VPC_Terraform.id}"
  depends_on  = ["aws_vpc.VPC_Terraform"]

  ingress {
    from_port = "0"
    to_port   = "0"
    protocol  = "-1"
    self      = true
  }

  egress {
    from_port = "0"
    to_port   = "0"
    protocol  = "-1"
    self      = "true"
  }

}

resource "aws_eip" "gw" {
  vpc        = true
  depends_on = ["aws_internet_gateway.igw"]
}

resource "aws_nat_gateway" "ngw" {
  subnet_id     = "${aws_subnet.subnet.id}"
  allocation_id = "${aws_eip.gw.id}"
}

# Create a new route table for the private subnets
# And make it route non-local traffic through the NAT gateway to the internet
resource "aws_route_table" "private" {
  vpc_id = "${aws_vpc.VPC_Terraform.id}"

  route {
    cidr_block = "0.0.0.0/0"
    nat_gateway_id = "${aws_nat_gateway.ngw.id}"
  }
}

# Explicitely associate the newly created route tables to the private subnets (so they don't default to the main route table)
resource "aws_route_table_association" "private" {
  subnet_id      = "${aws_subnet.subnet1.id}"
  route_table_id = "${aws_route_table.private.id}"
}
