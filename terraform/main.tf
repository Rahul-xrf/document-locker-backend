provider "aws" {
  region = var.region
}

# S3 Bucket
resource "aws_s3_bucket" "locker_bucket" {
  bucket = var.bucket_name
  force_destroy = true
}

# EC2 Key Pair (for SSH)
resource "aws_key_pair" "locker_key" {
  key_name   = var.key_name
  public_key = file("~/.ssh/id_rsa.pub")
}

# Security Group
resource "aws_security_group" "locker_sg" {
  name        = "locker-sg"

  ingress {
    description = "Allow SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Allow HTTP"
    from_port   = 5000
    to_port     = 5000
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

# IAM Role for EC2 to access S3
resource "aws_iam_role" "ec2_role" {
  name = "ec2_s3_access_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Principal = {
        Service = "ec2.amazonaws.com"
      },
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_policy_attachment" "s3_policy" {
  name       = "attach-s3-policy"
  roles      = [aws_iam_role.ec2_role.name]
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3FullAccess"
}

resource "aws_iam_instance_profile" "ec2_profile" {
  name = "ec2_instance_profile"
  role = aws_iam_role.ec2_role.name
}

# EC2 Instance
resource "aws_instance" "locker_instance" {
  ami           = "ami-03f4878755434977f"  # Ubuntu 22.04 (Mumbai)
  instance_type = var.instance_type
  key_name      = var.key_name
  security_groups = [aws_security_group.locker_sg.name]
  iam_instance_profile = aws_iam_instance_profile.ec2_profile.name

  tags = {
    Name = "Document-Locker-Backend"
  }

  user_data = <<-EOF
    #!/bin/bash
    apt update -y
    apt install docker.io python3-pip -y
    pip3 install flask flask-cors boto3 python-dotenv
    # You can later auto-pull your app code here using git
  EOF
}
