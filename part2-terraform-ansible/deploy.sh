#!/bin/bash

# Part 2: Terraform + Ansible Deployment Script
# This script automates the entire infrastructure and configuration process

set -e  # Exit on any error

echo "🚀 Starting Terraform + Ansible Deployment..."
echo "=============================================="

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check prerequisites
check_prerequisites() {
    print_status "Checking prerequisites..."
    
    if ! command -v terraform &> /dev/null; then
        print_error "Terraform is not installed. Please install Terraform first."
        exit 1
    fi
    
    if ! command -v ansible &> /dev/null; then
        print_error "Ansible is not installed. Please install Ansible first."
        exit 1
    fi
    
    if [ ! -f ~/.ssh/id_rsa ]; then
        print_error "SSH key not found at ~/.ssh/id_rsa"
        print_status "Generating SSH key pair..."
        ssh-keygen -t rsa -b 4096 -f ~/.ssh/id_rsa -N "" -q
    fi
    
    print_status "All prerequisites satisfied!"
}

# Terraform deployment
deploy_infrastructure() {
    print_status "Deploying infrastructure with Terraform..."
    
    cd terraform
    
    print_status "Initializing Terraform..."
    terraform init
    
    print_status "Planning infrastructure..."
    terraform plan
    
    print_status "Applying infrastructure..."
    terraform apply -auto-approve
    
    # Get the public IP from Terraform output
    PUBLIC_IP=$(terraform output -raw web_server_public_ip)
    
    print_status "Infrastructure deployed! Server IP: $PUBLIC_IP"
    
    cd ..
}

# Update Ansible inventory
update_inventory() {
    print_status "Updating Ansible inventory with server IP..."
    
    cd terraform
    PUBLIC_IP=$(terraform output -raw web_server_public_ip)
    cd ..
    
    # Create dynamic inventory
    cat > ansible/inventory.ini << EOF
[web_servers]
$PUBLIC_IP

[web_servers:vars]
ansible_ssh_private_key_file=~/.ssh/id_rsa
ansible_user=ubuntu
ansible_ssh_common_args='-o StrictHostKeyChecking=no'
EOF
    
    print_status "Ansible inventory updated with IP: $PUBLIC_IP"
}

# Wait for SSH to be ready
wait_for_ssh() {
    print_status "Waiting for SSH to be ready on the server..."
    
    cd terraform
    PUBLIC_IP=$(terraform output -raw web_server_public_ip)
    cd ..
    
    until nc -z $PUBLIC_IP 22; do
        print_status "Waiting for SSH on $PUBLIC_IP..."
        sleep 10
    done
    
    print_status "SSH is ready!"
}

# Ansible configuration
run_ansible() {
    print_status "Starting Ansible configuration..."
    
    cd ansible
    
    print_status "Testing connection to the server..."
    ansible web_servers -m ping -i inventory.ini
    
    print_status "Running Ansible playbook..."
    ansible-playbook -i inventory.ini playbook.yml
    
    cd ..
}

# Display completion message
show_completion() {
    cd terraform
    WEBSITE_URL=$(terraform output -raw website_url)
    cd ..
    
    echo ""
    echo "🎉 🎉 🎉 DEPLOYMENT COMPLETE! 🎉 🎉 🎉"
    echo "========================================="
    echo ""
    echo "🌐 Your website is live at: $WEBSITE_URL"
    echo "📊 Server info page: ${WEBSITE_URL}/info.html"
    echo ""
    echo "✨ What was accomplished:"
    echo "   ✅ Terraform created AWS infrastructure"
    echo "   ✅ Ansible configured the web server"
    echo "   ✅ Nginx installed and running"
    echo "   ✅ Custom website deployed"
    echo "   ✅ Full automation complete!"
    echo ""
    echo "To destroy everything when done:"
    echo "  cd terraform && terraform destroy -auto-approve"
    echo ""
}

# Main execution
main() {
    print_status "Starting Part 2: Terraform + Ansible Magic!"
    
    check_prerequisites
    deploy_infrastructure
    update_inventory
    wait_for_ssh
    run_ansible
    show_completion
    
    print_status "DevOps pipeline execution complete! 🚀"
}

# Run the main function
main "$@"
