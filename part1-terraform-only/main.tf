# main.tf - Simplified working version

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

# Create VPC
resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"
  tags = {
    Name = "Tutorial-VPC"
  }
}

# Create Internet Gateway
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id
  tags = {
    Name = "Tutorial-IGW"
  }
}

# Create Subnet
resource "aws_subnet" "main" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = "us-east-1a"
  tags = {
    Name = "Tutorial-Subnet"
  }
}

# Create Route Table
resource "aws_route_table" "main" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }
  tags = {
    Name = "Tutorial-Route-Table"
  }
}

# Associate Route Table with Subnet
resource "aws_route_table_association" "main" {
  subnet_id      = aws_subnet.main.id
  route_table_id = aws_route_table.main.id
}

# Create Security Group
resource "aws_security_group" "web_server" {
  name        = "web-server-sg"
  description = "Allow SSH and HTTP traffic"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 80
    to_port     = 80
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
    Name = "Web-Server-Security-Group"
  }
}

# Create EC2 Instance with HARDCODED AMI (no data source)
resource "aws_instance" "my_web_server" {
  ami           = "ami-0fc5d935ebf8bc3bc"  # Ubuntu 22.04 in us-east-1
  instance_type = "t2.micro"
  subnet_id     = aws_subnet.main.id
  vpc_security_group_ids = [aws_security_group.web_server.id]
  associate_public_ip_address = true

  tags = {
    Name = "Terraform-Web-Server-Tutorial"
  }

  user_data = <<-EOF
              #!/bin/bash
              sudo apt-get update
              sudo apt-get install -y nginx
              sudo systemctl start nginx
              sudo systemctl enable nginx
              echo "<h1>Hello from Terraform!</h1>" | sudo tee /var/www/html/index.html
              EOF
}

output "public_ip" {
  description = "The public IP address of the web server"
  value       = aws_instance.my_web_server.public_ip
}

output "website_url" {
  description = "URL to access your web server"
  value       = "http://${aws_instance.my_web_server.public_ip}"
}
