terraform {
  required_version = ">= 1.3"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# ---------------------------------------------------------------------------
# Dynamic AMI lookup (region-agnostic) - always resolves to the latest
# Amazon Linux 2 AMI available in whichever region var.aws_region points to.
# ---------------------------------------------------------------------------
data "aws_ami" "latest_amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# ---------------------------------------------------------------------------
# KMS key used to encrypt EBS volumes
# ---------------------------------------------------------------------------
resource "aws_kms_key" "ebs_kms_key" {
  description             = "KMS key for EBS volume encryption - smallcase devops assignment"
  deletion_window_in_days = 7
  enable_key_rotation     = true
}

resource "aws_kms_alias" "ebs_kms_key_alias" {
  name          = "alias/smallcase-devops-assignment-ebs"
  target_key_id = aws_kms_key.ebs_kms_key.key_id
}

# ---------------------------------------------------------------------------
# Security group: SSH + app port 8081
# ---------------------------------------------------------------------------
resource "aws_security_group" "app_sg" {
  name        = "smallcase-devops-assignment-sg"
  description = "Allow SSH and app traffic"
  vpc_id      = var.vpc_id

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.ssh_allowed_cidr]
  }

  ingress {
    description = "Application port"
    from_port   = 8081
    to_port     = 8081
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
    Name = "smallcase-devops-assignment-sg"
  }
}

# ---------------------------------------------------------------------------
# EC2 instance with public IP + KMS-encrypted root volume
# ---------------------------------------------------------------------------
resource "aws_instance" "app_server" {
  ami                         = data.aws_ami.latest_amazon_linux.id
  instance_type               = var.instance_type
  key_name                    = var.key_pair_name
  subnet_id                   = var.subnet_id
  vpc_security_group_ids      = [aws_security_group.app_sg.id]
  associate_public_ip_address = true

  root_block_device {
    volume_size = 8
    volume_type = "gp3"
    encrypted   = true
    kms_key_id  = aws_kms_key.ebs_kms_key.arn
  }

  user_data = file("${path.module}/user_data.sh")

  tags = {
    Name = "smallcase-devops-assignment"
  }
}

# ---------------------------------------------------------------------------
# Additional KMS-encrypted EBS volume, attached to the instance
# ---------------------------------------------------------------------------
resource "aws_ebs_volume" "data_volume" {
  availability_zone = aws_instance.app_server.availability_zone
  size              = var.ebs_volume_size
  type              = "gp3"
  encrypted         = true
  kms_key_id        = aws_kms_key.ebs_kms_key.arn

  tags = {
    Name = "smallcase-devops-assignment-data"
  }
}

resource "aws_volume_attachment" "data_attach" {
  device_name = "/dev/xvdf"
  volume_id   = aws_ebs_volume.data_volume.id
  instance_id = aws_instance.app_server.id
}