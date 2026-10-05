output "arn" {
  description = "ARN of the ALB"
  value       = aws_lb.this.arn
}

output "arn_suffix" {
  description = "ARN suffix of the ALB, used as the LoadBalancer CloudWatch dimension"
  value       = aws_lb.this.arn_suffix
}

output "dns_name" {
  description = "Public DNS name of the ALB"
  value       = aws_lb.this.dns_name
}

output "http_listener_arn" {
  description = "ARN of the HTTP :80 listener that service modules attach rules to"
  value       = aws_lb_listener.http.arn
}
