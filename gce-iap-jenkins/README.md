# Jenkins on GCP via Terraform

This Terraform module provisions a Jenkins LTS instance on Google Cloud Platform (GCP) with secure access via IAP, HTTPS load balancing, a managed SSL certificate, and necessary IAM permissions.

### Features

* GCP provider setup and API enablement
* VPC network, subnetwork, and firewall configuration
* Compute Engine VM with Jenkins pre-installed
* Service account with logging and monitoring roles
* HTTPS Load Balancer with managed SSL certificate
* Cloud Router and Cloud NAT for downloading updates
* IAM bindings for OS Login and IAP access
* DNS output guidance for custom domain configuration

### File Overview

| File                      | Description                                       |
| ------------------------- | ------------------------------------------------- |
| `main.tf`                 | Infrastructure definitions for Jenkins deployment |
| `variables.tf`            | Input variable declarations                       |
| `terraform.tfvars.sample` | Sample input values (copy to `terraform.tfvars`)  |
| `outputs.tf`              | Useful outputs like instance name and LB IP       |
| `install-jenkins.sh`      | Bash script to install Jenkins LTS with Nginx     |

### Requirements

* Terraform v1.5+
* Google Cloud SDK with authenticated session
* Enabled billing and permissions to create resources in the target project

### Usage

1. **Initialize the project**:

   ```bash
   terraform init
   ```

2. **Customize variables**: Copy and edit the sample:

   ```bash
   cp terraform.tfvars.sample terraform.tfvars
   ```

3. **Apply the configuration**:

   ```bash
   terraform apply
   ```

4. **Post-deploy**:

   * Update your DNS to point `domain_name` to the provided load balancer IP.
   * Access Jenkins securely via HTTPS and IAP.

### Outputs

* `jenkins_instance_name`: Name of the Jenkins VM instance
* `https_load_balancer_ip`: External IP address for HTTPS access
* `dns_configuration`: A record guidance for domain pointing

### Notes

* The Jenkins VM uses OS Login and IAP for SSH access (`roles/iap.tunnelResourceAccessor`)
* TLS is automatically handled by GCP's managed SSL certificate
* Startup script installs Jenkins with Java 17

### Security

* Secure Boot, vTPM, and integrity monitoring enabled
* Access to VM and web interface is restricted via IAM
