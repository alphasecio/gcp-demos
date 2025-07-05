output "app_instance_name" {
  description = "App VM instance name"
  value = google_compute_instance.app_vm.name
}

output "https_load_balancer_ip" {
  description = "HTTPS load balancer IP address"
  value = google_compute_global_address.app_ip.address
}

output "dns_configuration" {
  description = "DNS configuration needed"
  value       = "Point ${var.domain_name} A record to ${google_compute_global_address.app_ip.address}"
}
