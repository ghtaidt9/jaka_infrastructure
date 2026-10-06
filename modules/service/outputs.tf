output "container_name" {
  description = "Docker container name, e.g. order-service"
  value       = local.container_name
}

output "asg_name" {
  description = "Auto Scaling Group name (AutoScalingGroupName dimension)"
  value       = aws_autoscaling_group.this.name
}

output "target_group_arn" {
  description = "Target group ARN"
  value       = aws_lb_target_group.this.arn
}

output "target_group_arn_suffix" {
  description = "Target group ARN suffix (TargetGroup dimension)"
  value       = aws_lb_target_group.this.arn_suffix
}

output "log_group_name" {
  description = "CloudWatch log group receiving the container logs"
  value       = aws_cloudwatch_log_group.app.name
}

output "ecr_repository_url" {
  description = "ECR repository URL for this service's images"
  value       = aws_ecr_repository.this.repository_url
}

output "image_tag_parameter_name" {
  description = "SSM parameter holding the image tag the ASG boots"
  value       = aws_ssm_parameter.image_tag.name
}

output "role_name" {
  description = "IAM role of the instances"
  value       = aws_iam_role.app.name
}
