#!/bin/bash
set -e

# Set required variables
ZONE="YOUR_ZONE"

# Delete all Kubernetes resources
kubectl delete -f gateway-httproute-grants.yaml
kubectl delete -f service-backendpolicy.yaml
kubectl delete -f deployment.yaml
kubectl delete -f app-code-configmap.yaml

# Delete all secrets
kubectl delete secret webapp-tls-secret -n gateway
kubectl delete secret iap-oauth-secret -n app1
kubectl delete secret iap-oauth-secret -n app2

# Delete all certificate resources
gcloud certificate-manager maps entries delete iapgw-webapp-cert-entry --map=iapgw-webapp-cert-map --location=global --quiet
gcloud certificate-manager certificates delete iapgw-webapp-cert --location=global --quiet
gcloud certificate-manager maps delete iapgw-webapp-cert-map --location=global --quiet

# Delete all namespaces
kubectl delete namespace gateway
kubectl delete namespace app1
kubectl delete namespace app2

# Release the global static IP
gcloud compute addresses delete webappgw-static-ip --global --quiet

# Delete the GKE cluster
gcloud container clusters delete webappgw-cluster --zone "$ZONE" --quiet
