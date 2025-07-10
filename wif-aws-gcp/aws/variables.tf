variable "aws_region" {
  description = "AWS region"
  type        = string
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
}

variable "gcp_project_id" {
  description = "GCP Project ID"
  type        = string
}

variable "wif_pool_name" {
  description = "GCP WIF pool name"
  type        = string
}

variable "service_account_email" {
  description = "GCP Service Account Email"
  type        = string
}
