# GKE Ingress Web App with TLS and Identity-Aware Proxy

This repo demonstrates how to deploy a multi-route Nginx web application to a Google Kubernetes Engine (GKE) cluster using Ingress, TLS, and Identity-Aware Proxy (IAP).

## ✨ Features

* One deployment serving multiple routes (`/`, `/app1`, `/app2`, `/app3`)
* HTML UI styled with TailwindCSS via ConfigMaps
* TLS termination using a Google-managed certificate
* Global static IP setup via GKE Ingress
* IAP protection per backend using BackendConfig

## 📁 Directory Structure

```
gke-iap-ingress/
├── app-code-configmap.yaml          # ConfigMaps for HTML UI content
├── cleanup.sh                       # Script to delete all resources and cluster
├── deployment.yaml                  # Nginx deployment with config mount
├── ingress.yaml                     # Ingress resource with TLS and paths
├── services-and-backendconfigs.yaml # Services and BackendConfigs with IAP settings
├── setup.sh                         # Script to deploy GKE cluster and resources
```

## 🔧 Prerequisites

* Google Cloud SDK installed and authenticated
* An active GCP project with billing and required APIs enabled
* A domain name you control (for Google-managed TLS certificate)

## 🚀 Setup Instructions

### 1. Create GKE Cluster and TLS Setup

Run `setup.sh` to:
* Authenticate with GCP and configure the project.
* Create a GKE cluster with secure/private networking.
* Reserve a global static IP address.
* Generate a temporary self-signed TLS certificate (used until the Google-managed certificate is provisioned).
* Create the TLS secret and apply all necessary manifests:
  * HTML & Nginx config (`app-code-configmap.yaml`)
  * Nginx deployment (`deployment.yaml`)
  * Services & BackendConfigs with IAP settings (`services-and-backendconfigs.yaml`)
  * HTTPS Ingress with static IP and TLS (`ingress.yaml`)
 
⚠️ Update `PROJECT_ID`, `ZONE`, and `SUBNET` in the script, and `DOMAIN` references in `ingress.yaml` first.

### 2. Configure DNS

Point your domain's A record to the global static IP assigned to the Ingress.

### 3. Enable IAP

To enable Identity-Aware Proxy (IAP) protection:
* **Firewall Rule**: Allow IAP to reach your HTTPS load balancer by creating an ingress firewall rule:
  ```
  gcloud compute firewall-rules create allow-iap-traffic \
    --direction=INGRESS \
    --action=ALLOW \
    --rules=tcp:443 \
    --source-ranges=35.235.240.0/20 \
    --target-tags=iap-protected
  ```
* **Enable IAP**: Go to `Security` > `Identity-Aware Proxy` in the Console, locate your backend service and toggle IAP to `ON`.

* **Grant Access**: Grant the `IAP-Secured Web App User` role (`roles/iap.webAppUser`) to authorized users:
  ```
  gcloud projects add-iam-policy-binding PROJECT_ID \
    --member="user:USER@DOMAIN.com" \
    --role="roles/iap.webAppUser"`
  ```  

## 🌐 Accessing the App

The app serves multiple routes:
* `/` - Default landing page
* `/app1` - App 1 route
* `/app2` - App 2 route
* `/app3` - App 3 route

Each route is handled by the same Nginx pod and served via different paths in the config. TLS is enforced and IAP restricts access to authorized Google accounts.

## 🧼 Teardown

Run `cleanup.sh` to remove all resources:
* Deletes Ingress, Services, BackendConfigs, Deployment, and ConfigMaps.
* Removes the TLS secret and static IP.
* Deletes the GKE cluster.

⚠️ Update `ZONE` in the script first.
