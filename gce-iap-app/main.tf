# Configure the Google Cloud provider
terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 6.40"
    }
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
}

# Enable required Google Cloud APIs
resource "google_project_service" "enabled_apis" {
  for_each = toset([
    "compute.googleapis.com",
    "oslogin.googleapis.com",
    "iam.googleapis.com",
    "iap.googleapis.com",
    "cloudresourcemanager.googleapis.com",
    "certificatemanager.googleapis.com"
  ])

  project            = var.project_id
  service            = each.value
  disable_on_destroy = false
}

# Set up custom network, subnet and firewall rules
resource "google_compute_network" "app_network" {
  name                    = "app-network"
  auto_create_subnetworks = false

  depends_on              = [google_project_service.enabled_apis]
}

resource "google_compute_subnetwork" "app_subnet" {
  name          = "app-subnet"
  ip_cidr_range = "10.140.1.0/24"
  network       = google_compute_network.app_network.id
  region        = var.region
}

resource "google_compute_firewall" "allow_iap_ssh" {
  name    = "allow-iap-ssh"
  network = google_compute_network.app_network.name

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  source_ranges = ["35.235.240.0/20"]
  target_tags   = ["app-vm"]
}

resource "google_compute_firewall" "allow_health_check" {
  name    = "allow-health-check"
  network = google_compute_network.app_network.name

  allow {
    protocol = "tcp"
    ports    = ["80", "443"]
  }

  # Source ranges for Google Cloud Load Balancer health checks and traffic
  source_ranges = ["130.211.0.0/22", "35.191.0.0/16"]
  target_tags   = ["app-vm"]
}

# Create custom service account and IAM bindings
resource "google_service_account" "app_sa" {
  account_id   = "app-vm-sa"
  display_name = "App VM Service Account"
  
  depends_on   = [google_project_service.enabled_apis]
}

resource "google_project_iam_member" "app_sa_log_writer" {
  project = var.project_id
  role    = "roles/logging.logWriter"
  member  = "serviceAccount:${google_service_account.app_sa.email}"
}

resource "google_project_iam_member" "app_sa_monitoring_writer" {
  project = var.project_id
  role    = "roles/monitoring.metricWriter"
  member  = "serviceAccount:${google_service_account.app_sa.email}"
}

# Create Compute instance 
resource "google_compute_instance" "app_vm" {
  name         = "app-vm"
  machine_type = "e2-medium"
  zone         = var.zone
  tags         = ["app-vm"]

  boot_disk {
    initialize_params {
      image = var.image_name
    }
  }

  network_interface {
    network    = google_compute_network.app_network.id
    subnetwork = google_compute_subnetwork.app_subnet.id
  }

  service_account {
    email  = google_service_account.app_sa.email
    scopes = ["cloud-platform"]
  }

  metadata = {
    enable-oslogin = "TRUE"
    startup-script = var.startup_script
  }

  shielded_instance_config {
    enable_secure_boot          = true
    enable_vtpm                 = true
    enable_integrity_monitoring = true
  }

  lifecycle {
    create_before_destroy = true
  }
}

# Create unmanaged instance group
resource "google_compute_instance_group" "app_uig" {
  name        = "app-ig"
  zone        = var.zone
  instances   = [google_compute_instance.app_vm.id]
  named_port {
    name = "http"
    port = 80
  }
  named_port {
    name = "https"
    port = 443
  }
}

# Create HTTPS Load Balancer related resources
resource "google_compute_health_check" "app_hc" {
  name               = "app-health-check"
  check_interval_sec = 10
  timeout_sec        = 5
  healthy_threshold  = 2
  unhealthy_threshold = 3
  http_health_check {
    port = 80
    request_path = "/"
  }
}

resource "google_compute_backend_service" "app_backend" {
  name                            = "app-backend"
  port_name                       = "http"
  protocol                        = "HTTP"
  load_balancing_scheme           = "EXTERNAL"
  timeout_sec                     = 30
  health_checks                   = [google_compute_health_check.app_hc.id]
  backend {
    group = google_compute_instance_group.app_uig.id
  }
}

resource "google_compute_url_map" "app_url_map" {
  name            = "app-url-map"
  default_service = google_compute_backend_service.app_backend.id
}

resource "google_compute_url_map" "app_redirect_map" {
  name            = "app-redirect-map"
  
  default_url_redirect {
    https_redirect         = true
    strip_query            = false
    redirect_response_code = "MOVED_PERMANENTLY_DEFAULT"
  }
}

resource "google_compute_global_address" "app_ip" {
  name = "app-ip"
}

resource "google_compute_managed_ssl_certificate" "app_cert" {
  name = "app-cert"
  managed {
    domains = [var.domain_name]
  }
}

resource "google_compute_target_https_proxy" "app_https_proxy" {
  name             = "app-https-proxy"
  url_map          = google_compute_url_map.app_url_map.id
  ssl_certificates = [google_compute_managed_ssl_certificate.app_cert.id]
}

resource "google_compute_target_http_proxy" "app_http_proxy" {
  name    = "app-http-proxy"
  url_map = google_compute_url_map.app_redirect_map.id
}

resource "google_compute_global_forwarding_rule" "app_https_forwarding_rule" {
  name                  = "https-forwarding-rule"
  target                = google_compute_target_https_proxy.app_https_proxy.id
  ip_address            = google_compute_global_address.app_ip.id
  port_range            = "443"
  load_balancing_scheme = "EXTERNAL"
  ip_protocol           = "TCP"
}

resource "google_compute_global_forwarding_rule" "app_http_forwarding_rule" {
  name                  = "http-forwarding-rule"
  target                = google_compute_target_http_proxy.app_http_proxy.id
  ip_address            = google_compute_global_address.app_ip.id
  port_range            = "80"
  load_balancing_scheme = "EXTERNAL"
  ip_protocol           = "TCP"
}

# Create a Cloud Router, and configure Cloud NAT on the router
resource "google_compute_router" "app_router" {
  name    = "app-router"
  region  = var.region
  network = google_compute_network.app_network.id
}

resource "google_compute_router_nat" "app_nat" {
  name                          = "app-nat"
  router                        = google_compute_router.app_router.name
  region                        = google_compute_router.app_router.region
  nat_ip_allocate_option        = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"
  log_config {
    enable = true
    filter = "ERRORS_ONLY"
  }
}

# Grant the IAP-Secured Tunnel User, IAP-Secured Web User and OS Login User roles
resource "google_iap_tunnel_instance_iam_member" "iap_tunnel_accessor" {
  project  = var.project_id
  zone     = var.zone
  instance = google_compute_instance.app_vm.name
  role     = "roles/iap.tunnelResourceAccessor"
  member        = "user:${var.iap_user_email}"

  depends_on    = [google_project_service.enabled_apis]
}

resource "google_iap_web_backend_service_iam_member" "iap_web_user" {
  project             = var.project_id
  web_backend_service = google_compute_backend_service.app_backend.name
  role                = "roles/iap.httpsResourceAccessor"
  member        = "user:${var.iap_user_email}"

  depends_on    = [google_project_service.enabled_apis]
}

resource "google_compute_instance_iam_member" "os_login_user" {
  project       = var.project_id
  zone          = var.zone
  instance_name = google_compute_instance.app_vm.name
  role          = "roles/compute.osLogin"        # Use "roles/compute.osAdminLogin" instead for administrative (sudo) access
  member        = "user:${var.iap_user_email}"

  depends_on    = [google_project_service.enabled_apis]
}
