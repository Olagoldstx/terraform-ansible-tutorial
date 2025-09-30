# part2-terraform-ansible/terraform/main.tf

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # Optional: Store state remotely (uncomment if you want to use S3 backend)
  # backend "s3" {
  #   bucket = "your-terraform-state-bucket"
  #   key    = "part2/terraform.tfstate"
  #   region = "us-east-1"
  # }
}

provider "aws" {
  region = "us-east-1"
}

# Create VPC
resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"
  tags = {
    Name = "Part2-Tutorial-VPC"
  }
}

# Create Internet Gateway
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id
  tags = {
    Name = "Part2-Tutorial-IGW"
  }
}

# Create Subnet
resource "aws_subnet" "main" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = "us-east-1a"
  tags = {
    Name = "Part2-Tutorial-Subnet"
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
    Name = "Part2-Tutorial-Route-Table"
  }
}

# Associate Route Table with Subnet
resource "aws_route_table_association" "main" {
  subnet_id      = aws_subnet.main.id
  route_table_id = aws_route_table.main.id
}

# Create Security Group - Enhanced for Ansible
resource "aws_security_group" "web_server" {
  name        = "part2-web-server-sg"
  description = "Allow SSH, HTTP, and HTTPS for Ansible"
  vpc_id      = aws_vpc.main.id

  # SSH access for Ansible
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # HTTP access
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # HTTPS access
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Allow all outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "Part2-Web-Server-Security-Group"
  }
}

# Create Key Pair for SSH access (Ansible will use this)
resource "aws_key_pair" "ansible_key" {
  key_name   = "part2-ansible-key"
  public_key = file("~/.ssh/id_rsa.pub") # You'll need to create this
}

# Create EC2 Instance - SIMPLIFIED (No user_data - Ansible will handle configuration)
resource "aws_instance" "web_server" {
  ami           = "ami-0fc5d935ebf8bc3bc"  # Ubuntu 22.04 in us-east-1
  instance_type = "t2.micro"
  subnet_id     = aws_subnet.main.id
  vpc_security_group_ids = [aws_security_group.web_server.id]
  key_name      = aws_key_pair.ansible_key.key_name
  
  # Enable public IP
  associate_public_ip_address = true

  tags = {
    Name = "Part2-Terraform-Ansible-Web-Server"
  }

  # Wait for instance to be ready before Ansible runs
  provisioner "remote-exec" {
    inline = [
      "echo 'Instance is ready for Ansible configuration'"
    ]

    connection {
      type        = "ssh"
      user        = "ubuntu"
      private_key = file("~/.ssh/id_rsa")
      host        = self.public_ip
    }
  }
}

# Outputs for Ansible
output "web_server_public_ip" {
  description = "Public IP of the web server for Ansible"
  value       = aws_instance.web_server.public_ip
}

output "web_server_private_ip" {
  description = "Private IP of the web server"
  value       = aws_instance.web_server.private_ip
}

output "ssh_command" {
  description = "SSH command to connect to the instance"
  value       = "ssh -i ~/.ssh/id_rsa ubuntu@${aws_instance.web_server.public_ip}"
}

output "website_url" {
  description = "URL to access the web server"
  value       = "http://${aws_instance.web_server.public_ip}"
}
