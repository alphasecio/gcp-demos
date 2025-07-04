# Google Cloud Project ID
variable "project_id" {
  description = "The GCP project ID to deploy resources into."
  type        = string
}

# Google Cloud Region for Cloud Run and Artifact Registry
variable "region" {
  description = "The GCP region to deploy Cloud Run service and Artifact Registry."
  type        = string
}

# Name of the Cloud Run service
variable "service_name" {
  description = "The name for the Cloud Run service."
  type        = string
}

# Name of the Artifact Registry Docker repository
variable "artifact_repo_name" {
  description = "The name for the Artifact Registry Docker repository."
  type        = string
}

# Name of the IAP Client ID
variable "iap_client_id" {
  description = "The manually created IAP OAuth Client ID"
  type        = string
}
