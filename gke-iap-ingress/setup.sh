#!/bin/bash
set -e

# Set required variables
PROJECT_ID="YOUR-PROJECT-ID"
ZONE="YOUR-ZONE"
SUBNET="YOUR-SUBNET"

# Authenticate with Google Cloud
gcloud auth login

# Set the active project
gcloud config set project "$PROJECT_ID"

# Create a GKE cluster with secure and private networking settings
gcloud container clusters create webapp-cluster \
  --zone "$ZONE" \
  --subnetwork "$SUBNET" \
  --num-nodes 2 \
  --release-channel stable \
  --enable-network-policy \
  --enable-shielded-nodes \
  --shielded-integrity-monitoring \
  --shielded-secure-boot \
  --enable-private-nodes \
  --enable-ip-alias \
  --enable-master-authorized-networks \
  --master-authorized-networks=$(curl -s ifconfig.me)/32 \
  --master-ipv4-cidr 172.16.0.0/28 \
  --enable-intra-node-visibility

# Update master authorized networks to current IP
# OPTIONAL: Use only if your Cloud Shell connection gets disconnected or you create a new session
gcloud container clusters update webapp-cluster \
  --zone "$ZONE" \
  --enable-master-authorized-networks \
  --master-authorized-networks=$(curl -s ifconfig.me)/32

# Get cluster credentials for kubectl access
gcloud container clusters get-credentials webapp-cluster --zone "$ZONE"

# Reserve a global static IP for the ingress
gcloud compute addresses create webapp-static-ip --global

# Display the allocated static IP address
gcloud compute addresses describe webapp-static-ip --global

# Generate a dummy TLS private key
openssl genrsa -out dummy.key 2048

# Generate a self-signed certificate
openssl req -new -x509 -key dummy.key -out dummy.crt -days 365 -subj "/CN=dummy-cert"

# Create a Kubernetes TLS secret from the dummy cert and key
kubectl create secret tls webapp-tls-secret \
  --cert=dummy.crt \
  --key=dummy.key

# Confirm that the TLS secret was created
kubectl get secret webapp-tls-secret

# Apply the ConfigMap (HTML content + Nginx config)
kubectl apply -f app-code-configmap.yaml

# Apply the Deployment for the Nginx web app
kubectl apply -f deployment.yaml

# Verify pods are running and labeled correctly
kubectl get pods -l app=simple-webapp

# Apply services and BackendConfigs with IAP settings
kubectl apply -f services-and-backendconfigs.yaml

# List the created services
kubectl get services

# List the BackendConfig resources
kubectl get backendconfigs

# Apply the Ingress resource
kubectl apply -f ingress.yaml

# Describe the ingress to check provisioning status
kubectl describe ingress webapp-ingress
