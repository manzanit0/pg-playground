output "source_rds_hostname" {
  description = "RDS instance hostname"
  value       = aws_db_instance.source.address
  sensitive   = true
}

output "source_rds_port" {
  description = "RDS instance port"
  value       = aws_db_instance.source.port
  sensitive   = true
}

output "source_rds_username" {
  description = "RDS instance root username"
  value       = aws_db_instance.source.username
  sensitive   = true
}

output "target_rds_hostname" {
  description = "RDS instance hostname"
  value       = aws_db_instance.target.address
  sensitive   = true
}

output "target_rds_port" {
  description = "RDS instance port"
  value       = aws_db_instance.target.port
  sensitive   = true
}

output "target_rds_username" {
  description = "RDS instance root username"
  value       = aws_db_instance.target.username
  sensitive   = true
}
