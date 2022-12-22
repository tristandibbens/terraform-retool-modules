resource "aws_rds_cluster" "this" {
  cluster_identifier    = var.deployment_name
  database_name         = "hammerhead_production"
  master_username       = aws_secretsmanager_secret_version.rds_username.secret_string
  master_password       = aws_secretsmanager_secret_version.rds_password.secret_string
  engine                = "aurora-postgresql"
  engine_version        = "13.6"
  engine_mode           = "serverless"
  vpc_security_group_ids       = [aws_security_group.rds.id]
  skip_final_snapshot = true
  storage_encrypted   = true

  scaling_configuration = {
    auto_pause               = true
    min_capacity             = 2
    max_capacity             = 8
    seconds_until_auto_pause = 300
    timeout_action           = "ForceApplyCapacityChange"
  }
  
  deletion_protection = true
}