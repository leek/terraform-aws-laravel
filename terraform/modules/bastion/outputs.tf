output "public_ip" {
  description = "Public IP of bastion host"
  value       = aws_instance.bastion.public_ip
}

output "private_ip" {
  description = "Private IP of bastion host"
  value       = aws_instance.bastion.private_ip
}

output "security_group_id" {
  description = "Security group ID of bastion host"
  value       = aws_security_group.bastion.id
}

output "ssh_command" {
  description = "SSH command to connect to bastion"
  value       = "ssh -i ~/.ssh/${var.key_name}.pem ec2-user@${aws_instance.bastion.public_ip}"
}

output "mysql_tunnel_command" {
  description = "Command to create MySQL tunnel"
  value       = "ssh -i ~/.ssh/${var.key_name}.pem -L 3306:RDS_ENDPOINT:3306 ec2-user@${aws_instance.bastion.public_ip}"
}

output "redis_tunnel_command" {
  description = "Command to create Redis tunnel"
  value       = "ssh -i ~/.ssh/${var.key_name}.pem -L 6379:REDIS_ENDPOINT:6379 ec2-user@${aws_instance.bastion.public_ip}"
}
