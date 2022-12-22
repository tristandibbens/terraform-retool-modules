resource "aws_rds_cluster" "this" {
  cluster_identifier    = "${var.deployment_name}-rds-instance"
  db_name               = "hammerhead_production"
  username              = aws_secretsmanager_secret_version.rds_username.secret_string
  password              = aws_secretsmanager_secret_version.rds_password.secret_string
  engine                = "aurora-postgresql"
  engine_verions        = "13.6"
  engine_mode           = "serverless"
  replica_scale_enabled = false
  replica_count         = 0
  subnets             = var.subnet_ids
  vpc_id              = var.vpc_id
  vpc_security_group_ids       = [aws_security_group.rds.id]
  monitoring_interval = 60
  skip_final_snapshot = true
  storage_encrypted   = true
  publicly_accessible          = var.rds_publicly_accessible

  scaling_configuration = {
    auto_pause               = true
    min_capacity             = 2
    max_capacity             = 8
    seconds_until_auto_pause = 300
    timeout_action           = "ForceApplyCapacityChange"
  }
  
  deletion_protection = true
}