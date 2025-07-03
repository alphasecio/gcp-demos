output "aws_account_id" {
  description = "AWS Account ID"
  value       = data.aws_caller_identity.current.account_id
}

output "aws_role_name" {
  description = "AWS IAM Role Name"
  value       = aws_iam_role.gcp_wif_role.name
}

output "aws_role_arn" {
  description = "AWS IAM Role ARN"
  value       = aws_iam_role.gcp_wif_role.arn
}
