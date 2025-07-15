# GKE Gateway Web App with TLS and Identity-Aware Proxy

This repository demonstrates how to deploy two Nginx web applications to a Google Kubernetes Engine (GKE) cluster using Gateway API, Google-managed TLS, and Identity-Aware Proxy (IAP).

## ✨ Features

* Two separate Nginx deployments, served via Gateway API HTTP routing
* HTML UI styled with TailwindCSS via ConfigMaps
* TLS termination using a Google-managed certificate
* Global static IP setup via Gateway API
* IAP protection per backend using GCPBackendPolicy

## 📁 Directory Structure

```
gke-iapgateway/
├── app-code-configmap.yaml         # ConfigMaps for HTML UI content
├── cleanup.sh                      # Script to delete all resources and cluster
├── deployment.yaml                 # Nginx deployments for app1 and app2
├── gateway-httproute-grants.yaml   # Gateway, HTTPRoute, and ReferenceGrants
├── service-backendpolicy.yaml      # Services and GCPBackendPolicy with IAP settings
├── setup.sh                        # Script to deploy GKE cluster and resources
```

## 🔧 Prerequisites

* Google Cloud SDK installed and authenticated
* An active GCP project with billing and required APIs enabled
* A domain name you control (for Google-managed TLS certificate)

## 🚀 Setup Instructions

### 1. Configure OAuth Client for IAP
Before running `setup.sh`, you must create an OAuth 2.0 Client ID for a Web application in the [Google Cloud Console](https://console.cloud.google.com/apis/credentials). This is required for IAP to authenticate users.

Configure the client with the following parameters (replace placeholders as needed):
* Authorized JavaScript origins: `https://DOMAIN` e.g. `https://iapgw-webapp.your-domain.com`
* Authorized redirect URIs: `https://iap.googleapis.com/v1/oauth/clientIds/CLIENT_ID:handleRedirect` (replace your `CLIENT_ID`)
* Once the client is created, note down the Client ID and Client Secret in a secure location.

### 2. Configure and Run `setup.sh`

First, update `CLIENT_ID` references in `service-backendpolicy.yaml`

Then, run `setup.sh` to:

* Create a GKE private cluster with secure networking features
* Reserve a global static IP and instruct you to update your DNS A-record (out-of-band)
* Generate and apply TLS secret (dummy cert used until Google cert is ready)
* Enable Certificate Manager and create a cert + map for TLS
* Create namespaces, ConfigMaps, Deployments, Services, and BackendPolicies
* Deploy Gateway API components: Gateway, HTTPRoute, ReferenceGrants

⚠️ Update `PROJECT_ID`, `ZONE`, `SUBNET`, `CLIENT_SECRET`, and `DOMAIN` in the script first.

### 3. Configure DNS

Point your domain's A record to the global static IP printed by the setup script.

### 4. Enable IAP

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
* **Enable IAP**: Go to `Security` > `Identity-Aware Proxy` in the Console, locate the two backend services and toggle IAP to `ON`.

* **Grant Access**: Grant the `IAP-Secured Web App User` role (`roles/iap.webAppUser`) to authorized users:
  ```
  gcloud projects add-iam-policy-binding PROJECT_ID \
    --member="user:USER@DOMAIN.com" \
    --role="roles/iap.webAppUser"`
  ```  

## 🌐 Accessing the Apps

Once DNS is propagated and IAP access is granted, navigate to your domain in a browser, and provide your consent. The traffic will be routed either to App 1 or App 2, each served via a separate Nginx pod and namespace. 

ℹ️ IAP seems to maintain session affinity, so the apps aren't being served 50:50 per request, but rather per user session.

## 🧼 Teardown

Run `cleanup.sh` to remove all resources:
* Deletes Ingress, Services, BackendConfigs, Deployment, and ConfigMaps.
* Removes the TLS secret and static IP.
* Deletes the GKE cluster.

⚠️ Update `ZONE` in the script first.


## ⚠️ Disclaimer
This project is a proof of concept intended for educational and demonstration purposes only. It is not officially supported or certified by Google, and is definitely not production-ready. Use at your own risk. Features, APIs, and configurations may change and require adaptation. Before using in a real-world environment, thorough testing, hardening, and security reviews are strongly recommended.
