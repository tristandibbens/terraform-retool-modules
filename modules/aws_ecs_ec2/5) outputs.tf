output "ecs_alb_url" {
  value       = aws_lb.this.dns_name
  description = "Retool ALB DNS url (where Retool is running)"
}

output "ecs_alb_arn" {
  value       = aws_lb.this.arn
  description = "Retool ALB arn"
}

output "ecs_cluster_name" {
  value       = aws_ecs_cluster.this.name
  description = "Name of AWS ECS Cluster"
}

output "ecs_cluster_arn" {
  value       = aws_ecs_cluster.this.arn
  description = "ARN of AWS ECS Cluster"
}

output "ecs_cluster_id" {
  value       = aws_ecs_cluster.this.id
  description = "ID of AWS ECS Cluster"
}

output "rds_instance_id" {
  value       = aws_db_instance.this.id
  description = "ID of AWS RDS instance"
}

output "rds_instance_address" {
  value       = aws_db_instance.this.address
  description = "Hostname of the RDS instance"
}

output "rds_instance_arn" {
  value       = aws_db_instance.this.arn
  description = "ARN of RDS instance"
}

output "aws_security_group_ec2_id" {
  value       = aws_security_group.ec2.id
  description = "EC2 security group"
}

output "ec2_role" {
  value       = aws_iam_role.ec2
  description = "EC2 runtime role to append permissions to"
}