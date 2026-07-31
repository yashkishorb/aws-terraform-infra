output "alb_security_group_id" {
  description = "Security group ID attached to the ALB"
  value       = aws_security_group.alb.id
}

output "ec2_security_group_id" {
  description = "Security group ID attached to the EC2 instances"
  value       = aws_security_group.ec2.id
}

output "ec2_instance_profile_name" {
  description = "IAM instance profile name attached to the launch template"
  value       = aws_iam_instance_profile.ec2.name
}

output "ec2_role_arn" {
  description = "ARN of the IAM role used by EC2 instances"
  value       = aws_iam_role.ec2.arn
}
