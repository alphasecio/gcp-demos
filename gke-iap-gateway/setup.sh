#!/bin/bash

set -e

# Set required variables
PROJECT_ID="YOUR-PROJECT-ID"
ZONE="YOUR-ZONE"
SUBNET="YOUR-SUBNET"
CLIENT_ID="YOUR-OAUTH-CLIENT-ID"
CLIENT_SECRET="YOUR-OAUTH-CLIENT-SECRET"
DOMAIN="YOUR-DOMAIN"

# Authenticate with Google Cloud
gcloud auth login

# Set the active project
gcloud config set project "$PROJECT_ID"

# Create a GKE cluster with secure and private networking settings
gcloud container clusters create webappgw-cluster \
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
  --master-ipv4-cidr 172.16.1.0/28 \
  --enable-intra-node-visibility \
  --gateway-api=standard

# Update master authorized networks to current IP
# OPTIONAL: Use only if your Cloud Shell connection gets disconnected or you create a new session
gcloud container clusters update webappgw-cluster \
  --zone "$ZONE" \
  --enable-master-authorized-networks \
  --master-authorized-networks=$(curl -s ifconfig.me)/32

# Get cluster credentials for kubectl access
gcloud container clusters get-credentials webappgw-cluster --zone "$ZONE"

# Reserve a global static IP for the ingress
gcloud compute addresses create webappgw-static-ip --global

STATIC_IP=$(gcloud compute addresses describe webappgw-static-ip --global --format="value(address)")
echo "Please update your DNS A-record for $DOMAIN to point to $STATIC_IP"

# Create namespaces
kubectl create namespace gateway
kubectl create namespace app1
kubectl create namespace app2

# Generate dummy TLS cert and key (for Gateway TLS termination placeholder)
openssl genrsa -out dummy.key 2048
openssl req -new -x509 -key dummy.key -out dummy.crt -days 365 -subj "/CN=dummy-cert"

# Create TLS secret in gateway namespace
kubectl create secret tls webapp-tls-secret \
  --cert=dummy.crt \
  --key=dummy.key \
  -n gateway

# Clean up the dummy cert files
rm -f dummy.crt dummy.key

# Create placeholder IAP OAuth secrets
kubectl create secret generic iap-oauth-secret \
  --from-literal=client_secret="$CLIENT_SECRET" \
  -n app1

kubectl create secret generic iap-oauth-secret \
  --from-literal=client_secret="$CLIENT_SECRET" \
  -n app2

# Enable Certificate Manager API
gcloud services enable certificatemanager.googleapis.com

# Create certificate
gcloud certificate-manager certificates create iapgw-webapp-cert \
--domains="$DOMAIN" \
--location=global

# Create certificate map
gcloud certificate-manager maps create iapgw-webapp-cert-map

# Add certificate entry to certificate map
gcloud certificate-manager maps entries create iapgw-webapp-cert-entry \
--map=iapgw-webapp-cert-map \
--certificates=iapgw-webapp-cert \
--hostname="$DOMAIN"

# Apply the ConfigMap (HTML content + Nginx config)
kubectl apply -f app-code-configmap.yaml

# Apply the Deployment manifest for the Nginx web apps
kubectl apply -f deployment.yaml

# Apply Services and GCPBackendPolicy manifest
kubectl apply -f service-backendpolicy.yaml

# Apply the Gateway, HTTPRoute and ReferenceGrant manifest
kubectl apply -f gateway-httproute-grants.yaml

# Verify resources have been created successfully
kubectl get pods -A
kubectl get services -A
kubectl get deployment -A
kubectl get gatewayclass -A
kubectl get gateway -A
kubectl get httproute -A
kubectl get gcpbackendpolicy -A
