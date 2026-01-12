# Outputs for the SonarQube deployment

output "sonarqube_namespace" {
  description = "Namespace where SonarQube is deployed"
  value       = kubernetes_namespace.sonarqube.metadata[0].name
}

output "sonarqube_url" {
  description = "URL to access SonarQube (add to /etc/hosts with minikube IP)"
  value       = "http://${var.sonarqube_ingress_host}"
}

output "sonarqube_default_credentials" {
  description = "Default SonarQube admin credentials"
  value       = "Username: admin, Password: admin (change on first login)"
}

output "postgresql_service" {
  description = "PostgreSQL service name for internal access"
  value       = "postgresql.${var.sonarqube_namespace}.svc.cluster.local:5432"
}

output "access_instructions" {
  description = "Instructions to access SonarQube"
  value       = <<-EOT
    
    ============================================
    SonarQube Deployment Complete!
    ============================================
    
    To access SonarQube:
    
    1. Get the Minikube IP:
       minikube ip
    
    2. Add to your /etc/hosts file:
       <minikube-ip> ${var.sonarqube_ingress_host}
    
    3. Or use minikube tunnel:
       minikube tunnel
       Then access: http://localhost
    
    4. Or use port-forward:
       kubectl port-forward svc/sonarqube-sonarqube -n ${var.sonarqube_namespace} 9000:9000
       Then access: http://localhost:9000
    
    Default credentials: admin / admin
    
    ============================================
  EOT
}
