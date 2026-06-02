output "namespace" {
  value       = kubernetes_namespace.main.metadata[0].name
  description = "Kubernetes namespace"
}

output "nginx_node_port" {
  value       = kubernetes_service.nginx.spec[0].port[0].node_port
  description = "NodePort for nginx service"
}

output "nginx_service_name" {
  value       = kubernetes_service.nginx.metadata[0].name
  description = "Nginx service name"
}

output "postgres_service_name" {
  value       = kubernetes_service.postgres.metadata[0].name
  description = "PostgreSQL service name"
}

output "postgres_connection_string" {
  value       = "postgresql://${var.postgres_user}:${var.postgres_password}@${kubernetes_service.postgres.metadata[0].name}.${kubernetes_namespace.main.metadata[0].name}.svc.cluster.local:5432/${var.postgres_db}"
  description = "PostgreSQL connection string"
  sensitive   = true
}

output "access_instructions" {
  value = <<-EOT
    ╔════════════════════════════════════════════════════════════════╗
    ║         Kubernetes Deployment Complete! 🎉                     ║
    ╚════════════════════════════════════════════════════════════════╝
    
    📋 DEPLOYMENT DETAILS:
    ─────────────────────
    Namespace: ${kubernetes_namespace.main.metadata[0].name}
    Environment: ${var.environment}
    
    🌐 NGINX ACCESS:
    ────────────────
    NodePort: ${kubernetes_service.nginx.spec[0].port[0].node_port}
    
    Option 1 - Direct NodePort Access:
      minikube ip          # Get your Minikube IP
      curl http://<IP>:${kubernetes_service.nginx.spec[0].port[0].node_port}
    
    Option 2 - Port Forward:
      kubectl port-forward -n ${kubernetes_namespace.main.metadata[0].name} svc/nginx-service 8080:80
      curl http://localhost:8080
    
    Option 3 - Auto Open in Browser:
      minikube service nginx-service -n ${kubernetes_namespace.main.metadata[0].name}
    
    🗄️  DATABASE ACCESS:
    ──────────────────
    Service: ${kubernetes_service.postgres.metadata[0].name}
    Host: postgres-service.${kubernetes_namespace.main.metadata[0].name}.svc.cluster.local
    Port: 5432
    Database: ${var.postgres_db}
    User: ${var.postgres_user}
    
    From within cluster:
      psql -h postgres-service.${kubernetes_namespace.main.metadata[0].name}.svc.cluster.local -U ${var.postgres_user} -d ${var.postgres_db}
    
    📊 MONITORING SETUP:
    ───────────────────
    Run the following to install Prometheus and Grafana:
      kubectl apply -f monitoring/prometheus.yaml
      kubectl apply -f monitoring/grafana.yaml
    
    🔍 USEFUL COMMANDS:
    ──────────────────
    Check all resources:
      kubectl get all -n ${kubernetes_namespace.main.metadata[0].name}
    
    Check pods:
      kubectl get pods -n ${kubernetes_namespace.main.metadata[0].name}
    
    Check services:
      kubectl get svc -n ${kubernetes_namespace.main.metadata[0].name}
    
    View nginx logs:
      kubectl logs -n ${kubernetes_namespace.main.metadata[0].name} -l app=nginx -f
    
    View postgres logs:
      kubectl logs -n ${kubernetes_namespace.main.metadata[0].name} -l app=postgres -f
    
    Execute into nginx pod:
      kubectl exec -it -n ${kubernetes_namespace.main.metadata[0].name} $(kubectl get pod -n ${kubernetes_namespace.main.metadata[0].name} -l app=nginx -o jsonpath='{.items[0].metadata.name}') -- /bin/bash
    
    Execute into postgres pod:
      kubectl exec -it -n ${kubernetes_namespace.main.metadata[0].name} $(kubectl get pod -n ${kubernetes_namespace.main.metadata[0].name} -l app=postgres -o jsonpath='{.items[0].metadata.name}') -- /bin/bash
    
    Destroy everything:
      terraform destroy
    
    💾 STORAGE:
    ──────────
    Storage Class: local-storage
    PVC for PostgreSQL: postgres-pvc
    Total Storage Size: ${var.storage_size}
    
    🔒 SECURITY:
    ────────────
    Network Policy: main-network-policy (enabled)
    Secret Name: postgres-secret
  EOT
}

output "deployment_status" {
  value = {
    nginx_replicas = kubernetes_deployment.nginx.spec[0].replicas
    namespace      = kubernetes_namespace.main.metadata[0].name
    storage_class  = kubernetes_storage_class.local_storage.metadata[0].name
  }
  description = "Current deployment status"
}
