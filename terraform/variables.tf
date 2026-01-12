# Variables for SonarQube deployment on Minikube

variable "postgresql_namespace" {
  description = "Kubernetes namespace for PostgreSQL"
  type        = string
  default     = "sonarqube"
}

variable "sonarqube_namespace" {
  description = "Kubernetes namespace for SonarQube"
  type        = string
  default     = "sonarqube"
}

variable "postgresql_password" {
  description = "PostgreSQL password for SonarQube database"
  type        = string
  default     = "sonarqube_password"
  sensitive   = true
}

variable "postgresql_database" {
  description = "PostgreSQL database name for SonarQube"
  type        = string
  default     = "sonarqube"
}

variable "postgresql_username" {
  description = "PostgreSQL username for SonarQube"
  type        = string
  default     = "sonarqube"
}

variable "sonarqube_monitoring_passcode" {
  description = "SonarQube monitoring passcode"
  type        = string
  default     = "admin123"
  sensitive   = true
}

variable "sonarqube_ingress_host" {
  description = "Hostname for SonarQube ingress"
  type        = string
  default     = "sonarqube.local"
}

variable "persistence_size" {
  description = "Size of persistent volume for SonarQube"
  type        = string
  default     = "5Gi"
}

variable "sonarqube_node_port" {
  description = "SonarQube service NodePort"
  type        = string
  default     = "30900"
}