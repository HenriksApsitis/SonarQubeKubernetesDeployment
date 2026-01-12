# SonarQube on Minikube with Terraform

This project automates the deployment of SonarQube on a Minikube Kubernetes cluster using Terraform and Helm charts.

## Overview

This solution deploys:
- **Minikube**: Local Kubernetes cluster
- **NGINX Ingress Controller**: Via Minikube addon for HTTP routing
- **PostgreSQL**: Deployed via Bitnami Helm chart as an external database
- **SonarQube**: Deployed via official SonarSource Helm chart with persistent storage

## Prerequisites

The setup script handles installation of all prerequisites on a clean Ubuntu Server.

## Quick Start

1. **Clone or extract this repository:**
   ```bash
   git clone https://github.com/HenriksApsitis/SonarQubeKubernetesDeployment.git
   cd sonarqube-minikube
   ```

2. **Make the setup script executable:**
   ```bash
   chmod +x setup.sh
   ```

3. **Optional: create terraform.tfvars file with new vairable values**
   ```bash
   cp terraform/terraform.tfvars.example terraform/terraform.tfvars
   ```

4. **Run the setup script:**
   ```bash
   ./setup.sh
   ```

   The script will:
   - Install all dependencies
   - Start a Minikube cluster
   - Enable the NGINX Ingress Controller
   - Deploy PostgreSQL
   - Deploy SonarQube with persistent storage
   - Display access instructions

## Setup Script Options

```bash
# Full installation (default)
./setup.sh

# Skip dependency installation (if already installed)
./setup.sh --skip-deps

# Destroy the deployment
./setup.sh --destroy

```

### Useful Kubectl Commands

```bash
# Check pod status
kubectl get pods -n sonarqube

# View pod logs
kubectl logs -f deployment/sonarqube-sonarqube -n sonarqube

# Check services
kubectl get svc -n sonarqube

# Check ingress
kubectl get ingress -n sonarqube

# Describe a pod for troubleshooting
kubectl describe pod -l app=sonarqube -n sonarqube
```

## Security Considerations

This deployment is intended for **development and testing purposes**. For production use:

1. Use strong, unique passwords
2. Enable TLS/HTTPS on ingress
3. Configure proper backup strategies
