provider "aws" {
  region = var.region
}

locals {
  name = "jgarcia-upgrade-spike"

  default_tags = {
    owner   = "jgarcia"
    project = "rds_upgrade_spike"
  }
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

  tags = local.default_tags
}

resource "aws_security_group" "rds" {
  name   = "${local.name}-source"
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

  tags = local.default_tags
}

resource "aws_db_subnet_group" "rds" {
  name       = local.name
  subnet_ids = module.vpc.public_subnets

  tags = local.default_tags
}


###########################
#     Source database     #
###########################

resource "aws_db_parameter_group" "source" {
  name   = "${local.name}-source"
  family = "postgres14"

  parameter {
    name  = "log_connections"
    value = "1"
  }

  tags = local.default_tags
}

resource "aws_db_instance" "source" {
  identifier             = "${local.name}-source"
  instance_class         = "db.t3.micro"
  allocated_storage      = 5
  engine                 = "postgres"
  engine_version         = "14.15"
  username               = "jgarcia"
  password               = var.db_password
  db_subnet_group_name   = aws_db_subnet_group.rds.name
  vpc_security_group_ids = [aws_security_group.rds.id]
  parameter_group_name   = aws_db_parameter_group.source.name
  publicly_accessible    = true
  skip_final_snapshot    = true

  tags = local.default_tags
}

###########################
#     Target database     #
###########################

resource "aws_db_parameter_group" "target" {
  name   = "${local.name}-target"
  family = "postgres17"

  parameter {
    name  = "log_connections"
    value = "1"
  }

  tags = local.default_tags
}

resource "aws_db_instance" "target" {
  identifier             = "${local.name}-target"
  instance_class         = "db.t3.micro"
  allocated_storage      = 5
  engine                 = "postgres"
  engine_version         = "17.2"
  username               = "jgarcia"
  password               = var.db_password
  db_subnet_group_name   = aws_db_subnet_group.rds.name
  vpc_security_group_ids = [aws_security_group.rds.id]
  parameter_group_name   = aws_db_parameter_group.target.name
  publicly_accessible    = true
  skip_final_snapshot    = true

  tags = local.default_tags
}

###########################
#    DMS Migrator Job     #
###########################

resource "aws_iam_role" "dms_access_role" {
  name = "dms-access-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "dms.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "dms_access_policy" {
  role       = aws_iam_role.dms_access_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonDMSVPCManagementRole"
}

resource "aws_dms_replication_instance" "education" {
  replication_instance_id     = local.name
  replication_instance_class  = "dms.t3.micro"
  allocated_storage           = 20
  vpc_security_group_ids      = [aws_security_group.rds.id]
  replication_subnet_group_id = aws_dms_replication_subnet_group.education.id

  tags = local.default_tags

  # NB: replication instances take so long to create that I decided to create
  # the other resources to enhance the feedback loop.
  depends_on = [aws_db_instance.source, aws_db_instance.target]
}

resource "aws_dms_replication_subnet_group" "education" {
  replication_subnet_group_id          = local.name
  replication_subnet_group_description = "DMS subnet group for education"
  subnet_ids                           = module.vpc.public_subnets

  tags = local.default_tags
}

resource "aws_dms_endpoint" "source" {
  endpoint_id   = "${local.name}-source"
  endpoint_type = "source"
  engine_name   = "postgres"

  server_name   = aws_db_instance.source.address
  port          = 5432
  database_name = "postgres"
  username      = aws_db_instance.source.username
  password      = aws_db_instance.source.password

  tags = local.default_tags
}

resource "aws_dms_endpoint" "target" {
  endpoint_id   = "${local.name}-target"
  endpoint_type = "target"
  engine_name   = "postgres"

  server_name   = aws_db_instance.target.address
  port          = 5432
  database_name = "postgres"
  username      = aws_db_instance.target.username
  password      = aws_db_instance.target.password

  tags = local.default_tags
}

resource "aws_dms_replication_task" "education" {
  replication_task_id      = local.name
  migration_type           = "full-load-and-cdc"
  replication_instance_arn = aws_dms_replication_instance.education.replication_instance_arn
  source_endpoint_arn      = aws_dms_endpoint.source.endpoint_arn
  target_endpoint_arn      = aws_dms_endpoint.target.endpoint_arn

  table_mappings = jsonencode({
    rules = [{
      "rule-type" = "selection"
      "rule-id"   = "1"
      "rule-name" = "all_tables"
      "object-locator" = {
        "schema-name" = "public"
        "table-name"  = "%"
      }
      "rule-action" = "include"
    }]
  })

  tags = local.default_tags
}
