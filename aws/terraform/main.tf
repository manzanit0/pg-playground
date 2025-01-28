provider "aws" {
  region = var.region
}

locals {
  name      = "jgarcia-rds-testing"
  owner_tag = "jgarcia"
}

data "aws_availability_zones" "available" {}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "5.18.0"

  name = local.name
  cidr = "10.0.0.0/16"

  azs             = data.aws_availability_zones.available.names
  private_subnets = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  public_subnets  = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]

  enable_nat_gateway     = true
  enable_vpn_gateway     = true
  single_nat_gateway     = true
  one_nat_gateway_per_az = false

  tags = {
    Owner = local.owner_tag
  }
}

resource "aws_db_subnet_group" "education" {
  name       = local.name
  subnet_ids = module.vpc.public_subnets

  tags = {
    Owner = local.owner_tag
  }
}

resource "aws_security_group" "rds" {
  name   = "education_rds"
  vpc_id = module.vpc.vpc_id

  ingress {
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Owner = local.owner_tag
  }
}

resource "aws_db_parameter_group" "education" {
  name   = local.name
  family = "postgres14"

  parameter {
    name  = "log_connections"
    value = "1"
  }

  tags = {
    Owner = local.owner_tag
  }
}

resource "aws_db_instance" "education" {
  identifier             = local.name
  instance_class         = "db.t3.micro"
  allocated_storage      = 5
  engine                 = "postgres"
  engine_version         = "14.15"
  username               = "jgarcia"
  password               = var.db_password
  db_subnet_group_name   = aws_db_subnet_group.education.name
  vpc_security_group_ids = [aws_security_group.rds.id]
  parameter_group_name   = aws_db_parameter_group.education.name
  publicly_accessible    = true
  skip_final_snapshot    = true

  tags = {
    Owner = local.owner_tag
  }
}
