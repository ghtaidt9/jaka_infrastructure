output "vpc_id" {
  description = "ID of the VPC"
  value       = aws_vpc.this.id
}

output "public_subnet_ids" {
  description = "Public subnet IDs, in the same order as var.azs"
  value       = [for az in var.azs : aws_subnet.public[az].id]
}

output "private_subnet_ids" {
  description = "Private subnet IDs, in the same order as var.azs"
  value       = [for az in var.azs : aws_subnet.private[az].id]
}

output "nat_public_ips" {
  description = "Public IPs of the NAT gateways (outbound IPs of the private subnets)"
  value       = [for eip in aws_eip.nat : eip.public_ip]
}

output "alb_sg_id" {
  description = "Security group for the ALB"
  value       = aws_security_group.alb.id
}

output "ec2_sg_id" {
  description = "Security group for the service EC2 instances"
  value       = aws_security_group.ec2.id
}

output "rds_sg_id" {
  description = "Security group for the RDS instances"
  value       = aws_security_group.rds.id
}

output "redis_sg_id" {
  description = "Security group for the ElastiCache replication group"
  value       = aws_security_group.redis.id
}
