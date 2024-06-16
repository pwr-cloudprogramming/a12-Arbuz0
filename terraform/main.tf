provider "aws" {
  region = "us-east-1"
}

resource "aws_s3_bucket" "ttt-bucket" {
  bucket = "ttt-bucket-janiak"
  tags   = {
    Name = "ttt-bucket-janiak"
  }
}

resource "aws_vpc" "l10_vpc" {
  cidr_block = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name        = "l10-vpc"
    Terraform   = "true"
    Environment = "dev"
  }
}

resource "aws_subnet" "l10_subnet" {
  vpc_id            = aws_vpc.l10_vpc.id
  cidr_block        = "10.0.101.0/24"
  availability_zone = "us-east-1b"

  tags = {
    Name = "l10-subnet"
  }
}

resource "aws_internet_gateway" "l10_igw" {
  vpc_id = aws_vpc.l10_vpc.id

  tags = {
    Name = "my-igw"
  }
}

resource "aws_route_table" "l10_rt" {
  vpc_id = aws_vpc.l10_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.l10_igw.id
  }

  tags = {
    Name = "l10_rt"
  }
}

resource "aws_route_table_association" "l10_rta" {
  subnet_id      = aws_subnet.l10_subnet.id
  route_table_id = aws_route_table.l10_rt.id
}

resource "aws_security_group" "allow_ssh_http" {
  name        = "allow_ssh_http"
  description = "Allow SSH and HTTP inbound traffic and all outbound traffic"
  vpc_id      = aws_vpc.l10_vpc.id

  tags = {
    Name = "allow-ssh-http"
  }
}

resource "aws_security_group_rule" "allow_all_outbound" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.allow_ssh_http.id
}

resource "aws_security_group_rule" "allow_http_https" {
  type              = "ingress"
  from_port         = 8080
  to_port           = 8081
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.allow_ssh_http.id
}

resource "aws_security_group_rule" "allow_ssh" {
  type              = "ingress"
  from_port         = 22
  to_port           = 22
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.allow_ssh_http.id
}

resource "aws_cognito_user_pool" "l10_user_pool" {
  name = "l10_user_pool"

  password_policy {
    minimum_length    = 8
    require_lowercase = true
    require_uppercase = true
    require_numbers   = true
    require_symbols   = false
  }

  admin_create_user_config {
    allow_admin_create_user_only = false
  }

  schema {
    attribute_data_type = "String"
    name                = "email"
    required            = true
    mutable             = false
  }

  auto_verified_attributes = ["email"]

  verification_message_template {
    email_message = "Your verification code is {####}"
    email_subject = "Verify your email"
    sms_message   = "Your verification code is {####}"
  }
}

resource "aws_cognito_user_pool_client" "l10_user_pool_client" {
  name                     = "l10_user_pool_client"
  user_pool_id             = aws_cognito_user_pool.l10_user_pool.id
  generate_secret          = false
  supported_identity_providers = ["COGNITO"]
}

resource "aws_cognito_user_pool_domain" "l10_user_pool_domain" {
  domain       = "mytic-tac-toe"
  user_pool_id = aws_cognito_user_pool.l10_user_pool.id
}

resource "aws_iam_instance_profile" "l10_instance_profile" {
  name = "LabRoleInstanceProfile"
  role = "LabRole"
}

resource "aws_instance" "l10_web_server" {
  ami                         = "ami-080e1f13689e07408"
  instance_type               = "t2.micro"
  key_name                    = "vockey"
  subnet_id                   = aws_subnet.l10_subnet.id
  associate_public_ip_address = true
  vpc_security_group_ids      = [aws_security_group.allow_ssh_http.id]
  iam_instance_profile        = aws_iam_instance_profile.l10_instance_profile.name
  user_data                   = <<-EOF
    #!/bin/bash
    apt update
    apt install -y docker docker-compose

    echo "export AWS_SDK_LOAD_CONFIG=1" >> /home/ubuntu/.bashrc
    source /home/ubuntu/.bashrc

    cd /home/ubuntu

    # Clone repository
    git clone https://github.com/pwr-cloudprogramming/a12-Arbuz0.git
    cd a12-Arbuz0
    cd app

    # Update cognito-config.js
    cat <<EOT > /home/ubuntu/a1-Arbuz0/frontend/src/js/cognito-config.js
    const COGNITO_USER_POOL_ID = '${aws_cognito_user_pool.l10_user_pool.id}';
    const COGNITO_CLIENT_ID = '${aws_cognito_user_pool_client.l10_user_pool_client.id}';
    const COGNITO_REGION = 'us-east-1';
    const S3_BUCKET_NAME = '${aws_s3_bucket.ttt-bucket.bucket}';
    EOT

    # Update application.properties
    cat <<EOT > /home/ubuntu/a1-Arbuz0/backend/src/main/resources/application.properties
    USER_POOL_ID=${aws_cognito_user_pool.l10_user_pool.id}
    USER_POOL_CLIENT_ID=${aws_cognito_user_pool_client.l10_user_pool_client.id}
    USER_POOL_DOMAIN=${aws_cognito_user_pool_domain.l10_user_pool_domain.domain}.auth.us-east-1.amazoncognito.com
    aws.region=us-east-1
    cloud.aws.region.static=us-east-1
    cloud.aws.s3.bucket=${aws_s3_bucket.ttt-bucket.bucket}
    EOT

    # Start the Docker containers
    docker-compose up -d
  EOF
  user_data_replace_on_change = true
  tags = {
    Name = "l10-TicTacToe"
  }
}


output "app_url" {
  value = "http://${aws_instance.l10_web_server.public_ip}:8081"
}
