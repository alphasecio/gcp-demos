# AWS Provider
provider "aws" {
  region = var.aws_region
}

# 1. IAM Policy for GCP WIF
resource "aws_iam_policy" "gcp_wif_policy" {
  name = "GCPWIFAccessPolicy"
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = "sts:GetCallerIdentity",
        Resource = "*"
      }
    ]
  })
}

# 2. IAM Role + Trust Policy for EC2
resource "aws_iam_role" "gcp_wif_role" {
  name = "GCPWIFAccessRole"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = {
          Service = "ec2.amazonaws.com"
        },
        Action = "sts:AssumeRole"
      }
    ]
  })
}

# 3. Attach policy to role
resource "aws_iam_role_policy_attachment" "gcp_wif_attach" {
  role       = aws_iam_role.gcp_wif_role.name
  policy_arn = aws_iam_policy.gcp_wif_policy.arn
}

# 4. Instance profile
resource "aws_iam_instance_profile" "gcp_wif_instance_profile" {
  name = aws_iam_role.gcp_wif_role.name
  role = aws_iam_role.gcp_wif_role.name
}

# 5. Security group - allow SSH from anywhere
resource "aws_security_group" "gcp_wif_sg" {
  name        = "gcp-wif-sg"
  description = "Allow SSH"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# 6. Get latest Amazon Linux 2023 AMI
data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["137112412989"] # Amazon

  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-kernel-6.1-x86_64"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }
}

# 7. Get default VPC and subnet
data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
  filter {
    name   = "availability-zone"
    values = ["${var.aws_region}a"]
  }
}

# 8. Get current AWS account ID
data "aws_caller_identity" "current" {}

# 9. EC2 Instance with gcloud CLI installation
resource "aws_instance" "gcp_wif_instance" {
  ami                    = data.aws_ami.amazon_linux.id
  instance_type          = var.instance_type
  subnet_id              = data.aws_subnets.default.ids[0]
  vpc_security_group_ids = [aws_security_group.gcp_wif_sg.id]
  iam_instance_profile   = aws_iam_instance_profile.gcp_wif_instance_profile.name

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 2
  }

  user_data = base64encode(templatefile("${path.module}/user_data.sh", {
    gcp_project_id        = var.gcp_project_id
    aws_account_id        = data.aws_caller_identity.current.account_id
    aws_role_name         = aws_iam_role.gcp_wif_role.name
    wif_pool_name         = var.wif_pool_name
    service_account_email = var.service_account_email
  }))
}

# 10. Save state information to file for GCP setup
resource "local_file" "aws_info" {
  content = jsonencode({
    aws_account_id = data.aws_caller_identity.current.account_id
    aws_role_name  = aws_iam_role.gcp_wif_role.name
    aws_role_arn   = aws_iam_role.gcp_wif_role.arn
    instance_ip    = aws_instance.gcp_wif_instance.public_ip
  })
  filename = "../shared/aws-info.json"
}
