#!/bin/bash

# Update system and install required packages
yum update -y
yum install -y curl unzip python3 jq

# Download and install Google Cloud SDK as ec2-user
sudo -u ec2-user bash <<'EOC'
cd /home/ec2-user

# Download and install gcloud
curl -O https://dl.google.com/dl/cloudsdk/channels/rapid/downloads/google-cloud-cli-529.0.0-linux-x86_64.tar.gz
tar -xf google-cloud-cli-529.0.0-linux-x86_64.tar.gz
./google-cloud-sdk/install.sh --quiet

# Add gcloud to PATH
echo 'source /home/ec2-user/google-cloud-sdk/path.bash.inc' >> /home/ec2-user/.bashrc
source /home/ec2-user/google-cloud-sdk/path.bash.inc

# Create credential configuration file template
# Note: This will be populated with actual values after GCP resources are created
cat > /home/ec2-user/gcp-credentials-template.json << 'EOF'
{
  "universe_domain": "googleapis.com",
  "type": "external_account",
  "audience": "//iam.googleapis.com/WORKLOAD_IDENTITY_POOL_NAME",
  "subject_token_type": "urn:ietf:params:oauth:token-type:aws4_request",
  "token_url": "https://sts.googleapis.com/v1/token",
  "credential_source": {
    "environment_id": "aws1",
    "region_url": "http://169.254.169.254/latest/meta-data/placement/availability-zone",
    "url": "http://169.254.169.254/latest/meta-data/iam/security-credentials",
    "regional_cred_verification_url": "https://sts.{region}.amazonaws.com?Action=GetCallerIdentity&Version=2011-06-15",
    "imdsv2_session_token_url": "http://169.254.169.254/latest/api/token"
  },
  "token_info_url": "https://sts.googleapis.com/v1/introspect"
}
EOF

# Create setup script for after GCP resources are created
cat > /home/ec2-user/setup-gcp-credentials.sh << 'EOF'
#!/bin/bash
# Run this script after GCP resources are created
# Usage: ./setup-gcp-credentials.sh "POOL_NAME" "SERVICE_ACCOUNT_EMAIL"

if [ $# -ne 2 ]; then
    echo "Usage: $0 <workload_identity_pool_name> <service_account_email>"
    echo "Example: $0 'projects/123456789/locations/global/workloadIdentityPools/aws-wif-pool' 'aws-wif-sa@project.iam.gserviceaccount.com'"
    exit 1
fi

POOL_NAME="$1"
SERVICE_ACCOUNT_EMAIL="$2"

# Create the actual credential configuration file
sed "s|WORKLOAD_IDENTITY_POOL_NAME|${POOL_NAME}|g; s|SERVICE_ACCOUNT_EMAIL|${SERVICE_ACCOUNT_EMAIL}|g" \
    /home/ec2-user/gcp-credentials-template.json > /home/ec2-user/gcp-credentials.json

# Set up the environment
export GOOGLE_APPLICATION_CREDENTIALS=/home/ec2-user/gcp-credentials.json
echo 'export GOOGLE_APPLICATION_CREDENTIALS=/home/ec2-user/gcp-credentials.json' >> /home/ec2-user/.bashrc

# Set GCP project
source /home/ec2-user/google-cloud-sdk/path.bash.inc
/home/ec2-user/google-cloud-sdk/bin/gcloud config set project ${gcp_project_id}

echo "Credentials configured! Testing authentication..."
/home/ec2-user/google-cloud-sdk/bin/gcloud auth application-default print-access-token
EOF

chmod +x /home/ec2-user/setup-gcp-credentials.sh

# Create info file with AWS details
cat > /home/ec2-user/aws-info.txt << EOF
AWS Account ID: ${aws_account_id}
AWS Role Name: ${aws_role_name}
AWS Role ARN: arn:aws:iam::${aws_account_id}:role/${aws_role_name}

To complete setup after creating GCP resources, run:
./setup-gcp-credentials.sh "YOUR_POOL_NAME" "YOUR_SERVICE_ACCOUNT_EMAIL"
EOF

EOC

# Fix ownership
chown -R ec2-user:ec2-user /home/ec2-user/google-cloud-sdk
chown -R ec2-user:ec2-user /home/ec2-user/gcp-credentials*
chown -R ec2-user:ec2-user /home/ec2-user/setup-gcp-credentials.sh
chown -R ec2-user:ec2-user /home/ec2-user/aws-info.txt
