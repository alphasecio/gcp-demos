# GKE Ingress Web App with TLS and Identity-Aware Proxy

This repo demonstrates how to deploy a multi-route Nginx web application to a Google Kubernetes Engine (GKE) cluster using Ingress, TLS, and Identity-Aware Proxy (IAP).

## ✨ Features

* One deployment serving multiple routes (`/`, `/app1`, `/app2`, `/app3`)
* TailwindCSS-based HTML UI via Nginx
* TLS termination via a Google-managed certificate
* GKE Ingress with global static IP
* Configurable BackendConfig (with IAP support)

## 📁 Directory Structure

```
gke-iap-ingress/
├── app-code-configmap.yaml          # HTML + Nginx config as ConfigMaps
├── cleanup.sh                       # Script to tear down all resources
├── deployment.yaml                  # Nginx deployment with config mount
├── ingress.yaml                     # Ingress resource with TLS + paths
├── services-and-backendconfigs.yaml # Services + BackendConfigs (with IAP)
├── setup.sh                         # Script to create GKE cluster and deploy
```

## 🔧 Prerequisites

* Google Cloud SDK installed and authenticated
* A GCP project with billing and APIs enabled
* A DNS domain (for provisioning the cert)

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
 
⚠️ Replace `YOUR_PROJECT_ID`, `YOUR_ZONE`, and `YOUR_SUBNET` in the script, and `YOUR_DOMAIN` references in `ingress.yaml`.

### 2. Enable IAP
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
  gcloud projects add-iam-policy-binding YOUR_PROJECT_ID \
    --member="user:USER@YOUR_DOMAIN.com" \
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

⚠️ Replace `YOUR_ZONE` in the script.
