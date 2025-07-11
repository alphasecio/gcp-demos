#!/bin/bash

# Delete the Ingress resource
kubectl delete -f ingress.yaml

# Delete services and BackendConfigs
kubectl delete -f services-and-backendconfigs.yaml

# Delete the Deployment
kubectl delete -f deployment.yaml

# Delete the ConfigMap
kubectl delete -f app-code-configmap.yaml

# Delete the TLS secret
kubectl delete secret webapp-tls-secret

# Delete local TLS files
rm -f dummy.crt dummy.key

# Release the global static IP
gcloud compute addresses delete webapp-static-ip --global --quiet

# Delete the GKE cluster
gcloud container clusters delete webapp-cluster --zone YOUR_ZONE --quiet
