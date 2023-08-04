resource "aws_db_subnet_group" "db_subnet_sg" {
  name       = "${var.deployment_name}-db_subnet_sg"
  subnet_ids = var.subnet_ids
  tags = {project=var.project}
}

resource "aws_db_instance" "this" {
  identifier                   = "${var.deployment_name}-rds-instance"
  allocated_storage            = 80
  instance_class               = var.rds_instance_class
  engine                       = "postgres"
  engine_version               = "13"
  db_name                      = "hammerhead_production"
  username                     = aws_secretsmanager_secret_version.rds_username.secret_string
  password                     = aws_secretsmanager_secret_version.rds_password.secret_string
  port                         = 5432
  publicly_accessible          = var.rds_publicly_accessible
  db_subnet_group_name         = aws_db_subnet_group.db_subnet_sg.name
  vpc_security_group_ids       = [aws_security_group.rds.id]
  performance_insights_enabled = var.rds_performance_insights_enabled

  backup_retention_period      = var.rds_backup_period

  skip_final_snapshot          = false
  apply_immediately            = true
  deletion_protection          = true
  tags = {project=var.project}

  snapshot_identifier = var.rds_existing_snapshot #default is null so this only works if a snapshot id is passed.

  # enable Multi-AZ deployment
  multi_az = true

  # enable Storage Autoscaling
  max_allocated_storage = 200 # set the max storage threshold, it will automatically increase storage when necessary
  
  # enable auto minor version upgrade
  auto_minor_version_upgrade = true
}
