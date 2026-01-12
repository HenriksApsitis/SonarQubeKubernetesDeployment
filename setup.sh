#!/bin/bash

#=============================================================================
# SonarQube on Minikube - Automated Setup Script
# 
# This script installs all packages and deploys SonarQube on Minikube
# using Terraform and Helm.
#
# Execution Environment: Clean Ubuntu Server with minimal packages
# Required: bash, git
#
# NOTE: This script should NOT be run as root. It will use sudo only when
# necessary for specific commands.
#
# Usage: ./setup.sh [options]
#   Options:
#     --skip-deps    Skip package installation (if already installed)
#     --destroy      Destroy the deployment
#     --help         Show this help message
#=============================================================================

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
MINIKUBE_MEMORY="4096"
MINIKUBE_CPUS="2"
MINIKUBE_DRIVER="docker"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)" # Gets path to current script exectution directory
TERRAFORM_DIR="${SCRIPT_DIR}/terraform"

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if running as root - we should NOT run as root
check_not_root() {
    if [[ $EUID -eq 0 ]]; then
        log_error "This script should NOT be run as root!"
        log_error "Please run as a regular user: ./setup.sh"
        log_error "The script will use 'sudo' when necessary."
        exit 1
    fi
}

# Update system packages
update_system() {
    log_info "Updating system packages..."
    sudo apt update -y
    sudo apt upgrade -y
    log_success "System packages updated"
}

# Install Docker
install_docker() {
    if command -v docker &> /dev/null; then
        log_info "Docker is already installed: $(docker --version)"
    else
        log_info "Installing Docker..."
        
        # Remove old versions
        sudo apt remove -y docker docker-engine docker.io containerd runc 2>/dev/null || true
        
        # Install packages
        sudo apt install -y \
            apt-transport-https \
            ca-certificates \
            curl \
            gnupg \
            lsb-release
        
        # Add Docker's official GPG key
        sudo install -m 0755 -d /etc/apt/keyrings
        curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
        sudo chmod a+r /etc/apt/keyrings/docker.gpg
        
        # Set up the repository
        echo \
            "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
            $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
            sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
        
        # Install Docker Engine
        sudo apt update -y
        sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
        
        # Start and enable Docker
        sudo systemctl start docker
        sudo systemctl enable docker
        
        log_success "Docker installed successfully"
    fi
    
    # Add current user to docker group if not already
    if ! groups $USER | grep -q docker; then
        log_info "Adding user $USER to docker group..."
        sudo usermod -aG docker $USER
        log_warning "You've been added to the docker group."
        log_warning "Please run: newgrp docker"
        log_warning "Or log out and back in"
        log_warning ""
        log_warning "After that, run: ./setup.sh --skip-deps"
        exit 0
    fi
    
    # Verify docker works without sudo
    if ! docker ps &> /dev/null; then
        log_warning "Docker requires group membership to be active."
        log_warning "Please run: newgrp docker"
        log_warning "Or log out and back in."
        log_warning "After that, run: ./setup.sh --skip-deps"

        exit 0
    fi
}

# Install kubectl
install_kubectl() {
    if command -v kubectl &> /dev/null; then
        log_info "kubectl is already installed: $(kubectl version --client --short 2>/dev/null || kubectl version --client)"
        return 0
    fi
    
    log_info "Installing kubectl..."
    
    # Download the latest stable version
    KUBECTL_VERSION=$(curl -L -s https://dl.k8s.io/release/stable.txt)
    curl -LO "https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/amd64/kubectl"
    
    # Verify checksum
    curl -LO "https://dl.k8s.io/${KUBECTL_VERSION}/bin/linux/amd64/kubectl.sha256"
    echo "$(cat kubectl.sha256)  kubectl" | sha256sum --check
    
    # Install kubectl
    sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
    
    # Clean up
    rm kubectl kubectl.sha256
    
    log_success "kubectl installed: $(kubectl version --client --short 2>/dev/null || kubectl version --client)"
}

# Install Minikube
install_minikube() {
    if command -v minikube &> /dev/null; then
        log_info "Minikube is already installed: $(minikube version --short)"
        return 0
    fi
    
    log_info "Installing Minikube..."
    
    # Download latest minikube
    curl -LO https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64
    
    # Install minikube
    sudo install minikube-linux-amd64 /usr/local/bin/minikube
    
    # Clean up
    rm minikube-linux-amd64
    
    log_success "Minikube installed: $(minikube version --short)"
}

# Install Helm
install_helm() {
    if command -v helm &> /dev/null; then
        log_info "Helm is already installed: $(helm version --short)"
        return 0
    fi
    
    log_info "Installing Helm..."
    
    # Download and install Helm
    curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-4 | bash
    
    log_success "Helm installed: $(helm version --short)"
}

# Install Terraform
install_terraform() {
    if command -v terraform &> /dev/null; then
        log_info "Terraform is already installed: $(terraform version | head -n1)"
        return 0
    fi
    
    log_info "Installing Terraform..."
    
    # Install packages
    sudo apt install -y gnupg software-properties-common
    
    # Add Hashicorp GPG key
    wget -O- https://apt.releases.hashicorp.com/gpg | \
        gpg --dearmor | \
        sudo tee /usr/share/keyrings/hashicorp-archive-keyring.gpg > /dev/null
    
    # Verify the key
    gpg --no-default-keyring \
        --keyring /usr/share/keyrings/hashicorp-archive-keyring.gpg \
        --fingerprint
    
    # Add the official Hashicorp repository
    echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] \
        https://apt.releases.hashicorp.com $(lsb_release -cs) main" | \
        sudo tee /etc/apt/sources.list.d/hashicorp.list
    
    # Install Terraform
    sudo apt update -y
    sudo apt install -y terraform
    
    log_success "Terraform installed: $(terraform version | head -n1)"
}

# Start Minikube cluster
start_minikube() {
    log_info "Starting Minikube cluster..."
    
    # Check if minikube is already running
    if minikube status 2>/dev/null | grep -q "Running"; then
        log_info "Minikube is already running"
    else
        # Start minikube with Docker driver (as non-root user)
        minikube start \
            --driver=${MINIKUBE_DRIVER} \
            --memory=${MINIKUBE_MEMORY} \
            --cpus=${MINIKUBE_CPUS} \
            --addons=storage-provisioner \
            --addons=default-storageclass
    fi
    
    # Verify cluster is running
    minikube status
    
    log_success "Minikube cluster is running"
}

# Enable Ingress addon
enable_ingress() {
    log_info "Enabling NGINX Ingress Controller..."
    
    minikube addons enable ingress
    
    # Wait for ingress controller to be ready
    log_info "Waiting for Ingress Controller to be ready..."
    kubectl wait --namespace ingress-nginx \
        --for=condition=ready pod \
        --selector=app.kubernetes.io/component=controller \
        --timeout=300s || {
            log_warning "Ingress controller may still be starting. Continuing..."
        }
    
    log_success "NGINX Ingress Controller enabled"
}

# Initialize and apply Terraform
deploy_with_terraform() {
    log_info "Deploying SonarQube with Terraform..."
    
    cd "${TERRAFORM_DIR}"
    
    # Copy example tfvars if not exists
    if [[ ! -f terraform.tfvars ]]; then
        cp terraform.tfvars.example terraform.tfvars
        log_info "Created terraform.tfvars from example"
    fi
    
    # Initialize Terraform
    log_info "Initializing Terraform..."
    terraform init
    
    # Plan the deployment
    log_info "Planning Terraform deployment..."
    terraform plan -out=tfplan
    
    # Apply the deployment
    log_info "Applying Terraform deployment..."
    terraform apply tfplan
    
    # Remove plan file
    rm -f tfplan
    
    cd "${SCRIPT_DIR}"
    
    log_success "Terraform deployment complete"
}

# Show access instructions
show_access_info() {
    local namespace="sonarqube"
    local host_ip=$(hostname -I | awk '{print $1}')
    
    echo ""
    echo "============================================"
    echo -e "${GREEN}SonarQube Deployment Complete!${NC}"
    echo "============================================"
    echo ""
    echo "Cluster Status:"
    kubectl get pods -n $namespace
    echo ""
    echo "Services:"
    kubectl get svc -n $namespace
    echo ""
    echo "Ingress:"
    kubectl get ingress -n $namespace
    echo ""
    echo "============================================"
    echo "Access Method:"
    echo "============================================"
    echo ""
    echo "Port Forward for External Access"
    echo "  kubectl port-forward svc/sonarqube-sonarqube -n $namespace 9000:9000 --address 0.0.0.0"
    echo "  Then access from other machines:"
    echo "    http://${host_ip}:9000"
    echo ""
    echo "============================================"
    echo "Default Credentials:"
    echo "  Username: admin"
    echo "  Password: admin"
    echo "  (You will be prompted to change the password on first login)"
    echo "============================================"
    echo ""
}

# Destroy deployment
destroy_deployment() {
    log_info "Destroying SonarQube deployment..."
    
    cd "${TERRAFORM_DIR}"
    
    if [[ -f terraform.tfstate ]]; then
        terraform destroy -auto-approve
    else
        log_warning "No Terraform state found. Nothing to destroy."
    fi
    
    cd "${SCRIPT_DIR}"
    
    log_success "Deployment destroyed"
}

# Main function
main() {
    local skip_deps=false
    local destroy=false
    
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --skip-deps)
                skip_deps=true
                shift
                ;;
            --destroy)
                destroy=true
                shift
                ;;
            *)
                log_error "Unknown option: $1"
                exit 1
                ;;
        esac
    done
    
    # Handle destroy
    if [[ "$destroy" == "true" ]]; then
        destroy_deployment
        exit 0
    fi
    
    echo "============================================"
    echo "SonarQube on Minikube - Automated Setup"
    echo "============================================"
    echo ""
    
    check_not_root
    
    # Install packages
    if [[ "$skip_deps" != "true" ]]; then
        update_system
        install_kubectl
        install_minikube
        install_helm
        install_terraform
        install_docker
    else
        log_info "Skipping package installation"
    fi
    
    # Start Minikube
    start_minikube
    
    # Enable Ingress
    enable_ingress
    
    # Deploy with Terraform
    deploy_with_terraform
    
    # Show access information
    show_access_info
    
    log_success "Setup complete!"
}

# Run main function
main "$@"
