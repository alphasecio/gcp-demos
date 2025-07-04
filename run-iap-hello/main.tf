# Configure the Google Cloud provider
terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 6.40"
    }
  }
}

# Configure the Google Cloud provider
provider "google" {
  project = var.project_id
  region  = var.region
}

# Data source to fetch the current project's numeric ID
data "google_project" "current" {
  project_id = var.project_id
}

# 1. Enable required Google Cloud APIs
resource "google_project_service" "enabled_apis" {
  for_each = toset([
    "run.googleapis.com",              # Cloud Run API
    "artifactregistry.googleapis.com", # Artifact Registry API for Docker images
    "cloudresourcemanager.googleapis.com", # Required for some IAM operations
    "iam.googleapis.com",              # IAM API
    "iap.googleapis.com",              # Identity-Aware Proxy API for access control
    "secretmanager.googleapis.com",    # Secret Manager API to store IAP Client ID
  ])
  project = var.project_id
  service = each.key
  disable_on_destroy = false # Set to true if you want to disable APIs on terraform destroy
}

# 2. Store IAP Client ID in Secret Manager
resource "google_project_service" "secretmanager" {
  project = var.project_id
  service = "secretmanager.googleapis.com"
  disable_on_destroy = false
}

resource "google_secret_manager_secret" "iap_client_id" {
  project   = var.project_id
  secret_id = "iap-client-id"
  
  replication {
    auto {}
  }
  
  depends_on = [google_project_service.secretmanager]
}

resource "google_secret_manager_secret_version" "iap_client_id" {
  secret      = google_secret_manager_secret.iap_client_id.id
  secret_data = var.iap_client_id
}

# 3. Create an Artifact Registry repository for Docker images
resource "google_artifact_registry_repository" "docker_repo" {
  provider      = google
  location      = var.region
  repository_id = var.artifact_repo_name
  description   = "Docker repository for Cloud Run service ${var.service_name}"
  format        = "DOCKER"
  
  depends_on = [
    google_project_service.enabled_apis["artifactregistry.googleapis.com"]
  ]
}

# 4. Build and push Docker image locally using null_resource with local-exec
# This step requires Docker and gcloud CLI to be installed and configured on the machine running Terraform.
resource "null_resource" "build_and_push_docker_image" {
  # Trigger this resource if any file in the current module directory changes.
  # This ensures the Docker image is rebuilt and pushed when your application code changes.
  triggers = {
    dir_checksum = filebase64sha256("${path.module}/Dockerfile") # Trigger on Dockerfile changes
    app_checksum = filebase64sha256("${path.module}/main.py")     # Trigger on main.py changes
    auth_checksum = filebase64sha256("${path.module}/auth.py")   # Trigger on auth.py changes
    req_checksum = filebase64sha256("${path.module}/requirements.txt") # Trigger on requirements.txt changes
    index_html_checksum = filebase64sha256("${path.module}/templates/index.html")
  }

  # Ensure Artifact Registry is ready before attempting to push.
  depends_on = [
    google_artifact_registry_repository.docker_repo
  ]

  provisioner "local-exec" {
    # Login Docker to Artifact Registry.
    # This assumes gcloud CLI is already authenticated to your GCP project.
    command = "gcloud auth configure-docker ${var.region}-docker.pkg.dev"
  }

  provisioner "local-exec" {
    # Build the Docker image. The context for the build is the current module path.
    # The image is tagged with the full Artifact Registry path.
    command = "docker build -t ${var.region}-docker.pkg.dev/${var.project_id}/${var.artifact_repo_name}/${var.service_name}:latest ."
    working_dir = path.module # Run docker build from the current directory
  }

  provisioner "local-exec" {
    # Push the Docker image to Artifact Registry.
    command = "docker push ${var.region}-docker.pkg.dev/${var.project_id}/${var.artifact_repo_name}/${var.service_name}:latest"
  }
}

# 5. Deploy the Cloud Run service
resource "google_cloud_run_v2_service" "default" {
  provider = google
  name     = var.service_name
  location = var.region
  project  = var.project_id

  template {
    containers {
      image = "${var.region}-docker.pkg.dev/${var.project_id}/${var.artifact_repo_name}/${var.service_name}:latest"

      env {
        name = "IAP_CLIENT_ID"
        value_source {
          secret_key_ref {
            secret  = google_secret_manager_secret.iap_client_id.secret_id
            version = "latest"
          }
        }
      }
    }

    # Ensure the service account has access to secrets
    service_account = "${data.google_project.current.number}-compute@developer.gserviceaccount.com"
  }

  # Configure traffic to send 100% to the latest revision
  traffic {
    type           = "TRAFFIC_TARGET_ALLOCATION_TYPE_LATEST"
    percent        = 100
  }

  # Enable Identity-Aware Proxy (IAP) for external access control.
  # "INGRESS_TRAFFIC_ALL" allows requests from both external and internal sources,
  # which is necessary for IAP to proxy traffic to the service.
  ingress = "INGRESS_TRAFFIC_ALL"

  # Allow Terraform to delete this service.
  # This must be set to false and `terraform apply` run successfully before `terraform destroy` will work.
  deletion_protection = false

  # Ensure the Docker image is built and pushed before deploying the service
  depends_on = [
    null_resource.build_and_push_docker_image
  ]
}

# 6. Grant Cloud Run Invoker role to the IAP service agent for this specific service.
# This allows the Google-managed IAP service account to invoke your Cloud Run service.
resource "google_cloud_run_service_iam_member" "iap_service_agent_invoker" {
  provider = google
  location = google_cloud_run_v2_service.default.location
  service  = google_cloud_run_v2_service.default.name
  role     = "roles/run.invoker"
  member   = "serviceAccount:service-${data.google_project.current.number}@gcp-sa-iap.iam.gserviceaccount.com"
  
  depends_on = [
    google_project_service.enabled_apis["run.googleapis.com"],
    google_cloud_run_v2_service.default
  ]
}

# 7. Grant Cloud Run service account access to the secret
resource "google_secret_manager_secret_iam_member" "secret_accessor" {
  project   = var.project_id
  secret_id = google_secret_manager_secret.iap_client_id.secret_id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${data.google_project.current.number}-compute@developer.gserviceaccount.com"
}

# 8. TODO: Allow app access via IAP for members of iap_members group
