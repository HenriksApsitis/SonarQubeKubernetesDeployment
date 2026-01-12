# Main Terraform configuration for SonarQube on Minikube
# This deploys PostgreSQL and SonarQube using Helm charts

# Create namespace for SonarQube and PostgreSQL
resource "kubernetes_namespace" "sonarqube" {
  metadata {
    name = var.sonarqube_namespace
    labels = {
      "managed-by" = "terraform"
      "app"        = "sonarqube"
    }
  }
}

# Deploy PostgreSQL using Bitnami Helm chart
resource "helm_release" "postgresql" {
  name       = "postgresql"
  repository = "https://charts.bitnami.com/bitnami"
  chart      = "postgresql"
  namespace  = kubernetes_namespace.sonarqube.metadata[0].name
  # Not pinning version to use latest available chart with matching images
  version    = "15.5.21"

  # Wait for deployment to complete
  wait    = true
  timeout = 600

  # Use latest PostgreSQL image tag to avoid image pull issues
  set {
    name  = "image.tag"
    value = "latest"
  }
  set{
    name  = "image.registry"
    value = "docker.io"
  }
  set{
    name  = "image.repository"
    value = "bitnami/postgresql"
  }

  # PostgreSQL configuration
  set {
    name  = "auth.username"
    value = var.postgresql_username
  }

  set {
    name  = "auth.password"
    value = var.postgresql_password
  }

  set {
    name  = "auth.database"
    value = var.postgresql_database
  }

  # Set postgres admin password directly (simpler approach)
  set {
    name  = "auth.postgresPassword"
    value = var.postgresql_password
  }

  # Persistence configuration
  set {
    name  = "primary.persistence.enabled"
    value = "true"
  }

  set {
    name  = "primary.persistence.size"
    value = "2Gi"
  }

  # Resource limits for minikube
  set {
    name  = "primary.resources.requests.memory"
    value = "256Mi"
  }

  set {
    name  = "primary.resources.requests.cpu"
    value = "250m"
  }

  set {
    name  = "primary.resources.limits.memory"
    value = "512Mi"
  }

  set {
    name  = "primary.resources.limits.cpu"
    value = "500m"
  }

  depends_on = [kubernetes_namespace.sonarqube]
}

# Create secret for SonarQube database connection
resource "kubernetes_secret" "sonarqube_db_secret" {
  metadata {
    name      = "sonarqube-db-secret"
    namespace = kubernetes_namespace.sonarqube.metadata[0].name
  }

  data = {
    "password" = var.postgresql_password
  }

  type = "Opaque"

  depends_on = [helm_release.postgresql]
}

# Deploy SonarQube using official Helm chart
resource "helm_release" "sonarqube" {
  name       = "sonarqube"
  repository = "https://SonarSource.github.io/helm-chart-sonarqube"
  chart      = "sonarqube"
  namespace  = kubernetes_namespace.sonarqube.metadata[0].name
  # Not pinning version to use latest available chart

  # Wait for deployment to complete
  wait    = true
  timeout = 900

  set {
    name  = "monitoringPasscode"
    value = var.sonarqube_monitoring_passcode
  }

  # Disable bundled PostgreSQL - use external one
  set {
    name  = "postgresql.enabled"
    value = "false"
  }

  # Configure external PostgreSQL connection via jdbcOverwrite
  set {
    name  = "jdbcOverwrite.enabled"
    value = "true"
  }

  set {
    name  = "jdbcOverwrite.jdbcUrl"
    value = "jdbc:postgresql://postgresql.${var.sonarqube_namespace}.svc.cluster.local:5432/${var.postgresql_database}"
  }

  set {
    name  = "jdbcOverwrite.jdbcUsername"
    value = var.postgresql_username
  }

  set {
    name  = "jdbcOverwrite.jdbcSecretName"
    value = kubernetes_secret.sonarqube_db_secret.metadata[0].name
  }

  set {
    name  = "jdbcOverwrite.jdbcSecretPasswordKey"
    value = "password"
  }

  # Persistence configuration for SonarQube data
  set {
    name  = "persistence.enabled"
    value = "true"
  }

  set {
    name  = "persistence.size"
    value = var.persistence_size
  }

  # Service configuration - NodePort for external access
  set {
    name  = "service.type"
    value = "NodePort"
  }

  set {
    name  = "service.nodePort"
    value = var.sonarqube_node_port
  }

  set {
    name  = "service.externalPort"
    value = "9000"
  }

  # Ingress configuration
  set {
    name  = "ingress.enabled"
    value = "true"
  }

  set {
    name  = "ingress.ingressClassName"
    value = "nginx"
  }

  set {
    name  = "ingress.hosts[0].name"
    value = var.sonarqube_ingress_host
  }

  set {
    name  = "ingress.hosts[0].path"
    value = "/"
  }

  set {
    name  = "ingress.hosts[0].pathType"
    value = "Prefix"
  }

  # Resource limits for minikube environment
  set {
    name  = "resources.requests.memory"
    value = "1Gi"
  }

  set {
    name  = "resources.requests.cpu"
    value = "400m"
  }

  set {
    name  = "resources.limits.memory"
    value = "2Gi"
  }

  set {
    name  = "resources.limits.cpu"
    value = "800m"
  }

  # Increase probes timing for slower environments
  set {
    name  = "readinessProbe.initialDelaySeconds"
    value = "120"
  }

  set {
    name  = "readinessProbe.periodSeconds"
    value = "30"
  }

  set {
    name  = "readinessProbe.failureThreshold"
    value = "10"
  }

  set {
    name  = "livenessProbe.initialDelaySeconds"
    value = "120"
  }

  set {
    name  = "livenessProbe.periodSeconds"
    value = "30"
  }

  set {
    name  = "livenessProbe.failureThreshold"
    value = "10"
  }

  set {
    name  = "startupProbe.initialDelaySeconds"
    value = "60"
  }

  set {
    name  = "startupProbe.periodSeconds"
    value = "30"
  }

  set {
    name  = "startupProbe.failureThreshold"
    value = "24"
  }

  # SonarQube edition - use community build
  set {
    name  = "edition"
    value = ""
  }
  set {
    name  = "community.enabled"
    value = "true"
  }

  depends_on = [
    helm_release.postgresql,
    kubernetes_secret.sonarqube_db_secret
  ]
}
