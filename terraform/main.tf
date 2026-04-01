# Sample Infrastructure with Compliance Violations
# This Terraform configuration intentionally contains violations for demo purposes

provider "aws" {
  region = "us-east-1"
}

# VIOLATION: S3 bucket without encryption (HIPAA, PCI-DSS)
resource "aws_s3_bucket" "patient_data" {
  bucket = "acme-patient-data-bucket"
  
  tags = {
    Name        = "Patient Data Storage"
    Environment = "production"
    DataClass   = "PHI"
  }
}

# VIOLATION: S3 bucket with public access (GDPR, HIPAA)
resource "aws_s3_bucket_public_access_block" "patient_data" {
  bucket = aws_s3_bucket.patient_data.id

  block_public_acls       = false  # Should be true
  block_public_policy     = false  # Should be true
  ignore_public_acls      = false  # Should be true
  restrict_public_buckets = false  # Should be true
}

# VIOLATION: RDS without encryption (PCI-DSS, HIPAA)
resource "aws_db_instance" "payment_db" {
  identifier           = "payment-database"
  engine               = "mysql"
  engine_version       = "8.0"
  instance_class       = "db.t3.medium"
  allocated_storage    = 100
  
  db_name              = "payments"
  username             = "admin"
  password             = "SuperSecret123!"  # VIOLATION: Hardcoded password
  
  storage_encrypted    = false  # VIOLATION: Should be true
  
  vpc_security_group_ids = [aws_security_group.db_sg.id]
  db_subnet_group_name   = aws_db_subnet_group.main.name
  
  backup_retention_period = 7
  
  tags = {
    Name        = "Payment Database"
    Environment = "production"
    Compliance  = "PCI-DSS"
  }
}

# VIOLATION: Security group with unrestricted SSH (SOC2, FedRAMP)
resource "aws_security_group" "web_server" {
  name        = "web-server-sg"
  description = "Security group for web servers"
  vpc_id      = aws_vpc.main.id

  # VIOLATION: SSH open to world
  ingress {
    description = "SSH from anywhere"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]  # Should be restricted
  }

  # VIOLATION: All ports open for debugging
  ingress {
    description = "Debug access"
    from_port   = 0
    to_port     = 65535
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "web-server-sg"
  }
}

# VIOLATION: Security group allowing unrestricted DB access
resource "aws_security_group" "db_sg" {
  name        = "database-sg"
  description = "Security group for databases"
  vpc_id      = aws_vpc.main.id

  # VIOLATION: MySQL open to public
  ingress {
    description = "MySQL access"
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]  # Should be VPC internal only
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# VIOLATION: IAM password policy too weak (FedRAMP, SOC2)
resource "aws_iam_account_password_policy" "strict" {
  minimum_password_length        = 8   # VIOLATION: Should be 14+
  require_lowercase_characters   = true
  require_numbers                = true
  require_uppercase_characters   = false  # VIOLATION: Should be true
  require_symbols                = false  # VIOLATION: Should be true
  allow_users_to_change_password = true
  max_password_age               = 0      # VIOLATION: Should have expiration
  password_reuse_prevention      = 0      # VIOLATION: Should prevent reuse
}

# VIOLATION: CloudTrail without encryption or log validation (GDPR, SOC2)
resource "aws_cloudtrail" "main" {
  name                          = "main-trail"
  s3_bucket_name                = aws_s3_bucket.cloudtrail_logs.id
  include_global_service_events = false  # VIOLATION: Should be true
  is_multi_region_trail         = false  # VIOLATION: Should be true for compliance
  enable_log_file_validation    = false  # VIOLATION: Should be true
  
  # Missing: kms_key_id for encryption
}

resource "aws_s3_bucket" "cloudtrail_logs" {
  bucket = "acme-cloudtrail-logs"
  # VIOLATION: No encryption configured
}

# VIOLATION: EBS volume without encryption (HIPAA)
resource "aws_ebs_volume" "data_volume" {
  availability_zone = "us-east-1a"
  size              = 500
  encrypted         = false  # VIOLATION: Should be true
  
  tags = {
    Name = "data-volume"
  }
}

# VIOLATION: Lambda without VPC (network isolation)
resource "aws_lambda_function" "data_processor" {
  filename         = "lambda.zip"
  function_name    = "data-processor"
  role             = aws_iam_role.lambda_role.arn
  handler          = "index.handler"
  runtime          = "nodejs18.x"
  
  # VIOLATION: Missing VPC configuration for sensitive data processing
  # Should have vpc_config block
  
  environment {
    variables = {
      DB_PASSWORD = "PlainTextPassword123"  # VIOLATION: Secrets in env vars
    }
  }
}

# Supporting resources
resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true
  
  tags = {
    Name = "main-vpc"
  }
}

resource "aws_subnet" "private_a" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = "us-east-1a"
}

resource "aws_subnet" "private_b" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = "us-east-1b"
}

resource "aws_db_subnet_group" "main" {
  name       = "main-db-subnet"
  subnet_ids = [aws_subnet.private_a.id, aws_subnet.private_b.id]
}

resource "aws_iam_role" "lambda_role" {
  name = "lambda-execution-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
}
