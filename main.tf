terraform {
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.23"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.11"
    }
  }
}

provider "kubernetes" {
  config_path = "~/.kube/config"
}

provider "helm" {
  kubernetes {
    config_path = "~/.kube/config"
  }
}

# Create main namespace
resource "kubernetes_namespace" "main" {
  metadata {
    name = var.namespace
    labels = {
      name        = var.namespace
      environment = var.environment
    }
  }

  timeouts {
    create = "5m"
    delete = "5m"
  }
}

# Create monitoring namespace
resource "kubernetes_namespace" "monitoring" {
  metadata {
    name = "monitoring"
    labels = {
      name = "monitoring"
    }
  }

  timeouts {
    create = "5m"
    delete = "5m"
  }
}

# Storage Class for persistent volumes
resource "kubernetes_storage_class" "local_storage" {
  metadata {
    name = "local-storage"
  }

  storage_provisioner = "kubernetes.io/no-provisioner"
  reclaim_policy      = "Delete"

  volume_binding_mode = "WaitForFirstConsumer"
}

# Persistent Volume
resource "kubernetes_persistent_volume" "local_pv" {
  metadata {
    name = "local-pv"
  }

  spec {
    capacity = {
      storage = var.storage_size
    }

    access_modes       = ["ReadWriteOnce"]
    storage_class_name = kubernetes_storage_class.local_storage.metadata[0].name

    persistent_volume_source {
      local {
        path = "/data"
      }
    }

    node_affinity {
      required {
        node_selector_term {
          match_expressions {
            key      = "kubernetes.io/hostname"
            operator = "In"
            values   = ["minikube"]
          }
        }
      }
    }
  }
}

# Persistent Volume Claim for Database
resource "kubernetes_persistent_volume_claim" "db_storage" {
  metadata {
    name      = "postgres-pvc"
    namespace = kubernetes_namespace.main.metadata[0].name
  }

  spec {
    access_modes       = ["ReadWriteOnce"]
    storage_class_name = kubernetes_storage_class.local_storage.metadata[0].name

    resources {
      requests = {
        storage = var.storage_size
      }
    }
  }

  depends_on = [kubernetes_persistent_volume.local_pv]
}

# Nginx Deployment
resource "kubernetes_deployment" "nginx" {
  metadata {
    name      = "nginx"
    namespace = kubernetes_namespace.main.metadata[0].name
    labels = {
      app = "nginx"
    }
  }

  spec {
    replicas = var.nginx_replicas

    selector {
      match_labels = {
        app = "nginx"
      }
    }

    template {
      metadata {
        labels = {
          app = "nginx"
        }
      }

      spec {
        container {
          image             = "nginx:latest"
          name              = "nginx"
          image_pull_policy = "IfNotPresent"

          port {
            container_port = 80
            name           = "http"
          }

          resources {
            requests = {
              cpu    = var.nginx_cpu_request
              memory = var.nginx_memory_request
            }
            limits = {
              cpu    = var.nginx_cpu_limit
              memory = var.nginx_memory_limit
            }
          }

          liveness_probe {
            http_get {
              path = "/"
              port = 80
            }
            initial_delay_seconds = 10
            period_seconds        = 10
          }

          readiness_probe {
            http_get {
              path = "/"
              port = 80
            }
            initial_delay_seconds = 5
            period_seconds        = 5
          }
        }
      }
    }
  }

  timeouts {
    create = "5m"
    delete = "5m"
  }

  depends_on = [kubernetes_namespace.main]
}

# Nginx Service (NodePort)
resource "kubernetes_service" "nginx" {
  metadata {
    name      = "nginx-service"
    namespace = kubernetes_namespace.main.metadata[0].name
  }

  spec {
    selector = {
      app = "nginx"
    }

    port {
      port        = 80
      target_port = 80
      protocol    = "TCP"
      node_port   = 30080
      name        = "http"
    }

    type = "NodePort"
  }

  timeouts {
    create = "2m"
    delete = "2m"
  }

  depends_on = [kubernetes_deployment.nginx]
}

# PostgreSQL StatefulSet
resource "kubernetes_stateful_set" "postgres" {
  metadata {
    name      = "postgres"
    namespace = kubernetes_namespace.main.metadata[0].name
  }

  spec {
    service_name = kubernetes_service.postgres.metadata[0].name
    replicas     = 1

    selector {
      match_labels = {
        app = "postgres"
      }
    }

    template {
      metadata {
        labels = {
          app = "postgres"
        }
      }

      spec {
        container {
          image = "postgres:15"
          name  = "postgres"

          port {
            container_port = 5432
            name           = "postgres"
          }

          env {
            name  = "POSTGRES_DB"
            value = var.postgres_db
          }

          env {
            name = "POSTGRES_USER"
            value_from {
              secret_key_ref {
                name = kubernetes_secret.postgres_secret.metadata[0].name
                key  = "username"
              }
            }
          }

          env {
            name = "POSTGRES_PASSWORD"
            value_from {
              secret_key_ref {
                name = kubernetes_secret.postgres_secret.metadata[0].name
                key  = "password"
              }
            }
          }

          resources {
            requests = {
              cpu    = "250m"
              memory = "256Mi"
            }
            limits = {
              cpu    = "500m"
              memory = "512Mi"
            }
          }

          volume_mount {
            name       = "postgres-storage"
            mount_path = "/var/lib/postgresql/data"
          }

          liveness_probe {
            exec {
              command = ["pg_isready", "-U", var.postgres_user]
            }
            initial_delay_seconds = 30
            period_seconds        = 10
          }
        }
      }
    }

    volume_claim_template {
      metadata {
        name = "postgres-storage"
      }

      spec {
        access_modes       = ["ReadWriteOnce"]
        storage_class_name = kubernetes_storage_class.local_storage.metadata[0].name

        resources {
          requests = {
            storage = var.storage_size
          }
        }
      }
    }
  }

  timeouts {
    create = "5m"
    delete = "5m"
  }

  depends_on = [kubernetes_namespace.main, kubernetes_storage_class.local_storage]
}

# PostgreSQL Service
resource "kubernetes_service" "postgres" {
  metadata {
    name      = "postgres-service"
    namespace = kubernetes_namespace.main.metadata[0].name
  }

  spec {
    selector = {
      app = "postgres"
    }

    port {
      port        = 5432
      target_port = 5432
      protocol    = "TCP"
      name        = "postgres"
    }

    type = "ClusterIP"
  }

  depends_on = [kubernetes_stateful_set.postgres]
}

# PostgreSQL Secret
resource "kubernetes_secret" "postgres_secret" {
  metadata {
    name      = "postgres-secret"
    namespace = kubernetes_namespace.main.metadata[0].name
  }

  type = "Opaque"

  data = {
    username = base64encode(var.postgres_user)
    password = base64encode(var.postgres_password)
  }

  depends_on = [kubernetes_namespace.main]
}

# ConfigMap for nginx
resource "kubernetes_config_map" "nginx_config" {
  metadata {
    name      = "nginx-config"
    namespace = kubernetes_namespace.main.metadata[0].name
  }

  data = {
    "nginx.conf" = file("${path.module}/nginx.conf")
  }

  depends_on = [kubernetes_namespace.main]
}

# Ingress
resource "kubernetes_ingress_v1" "main_ingress" {
  metadata {
    name      = "main-ingress"
    namespace = kubernetes_namespace.main.metadata[0].name
  }

  spec {
    ingress_class_name = "nginx"

    rule {
      host = var.ingress_host

      http {
        path {
          path      = "/"
          path_type = "Prefix"

          backend {
            service {
              name = kubernetes_service.nginx.metadata[0].name
              port {
                number = 80
              }
            }
          }
        }

        path {
          path      = "/api"
          path_type = "Prefix"

          backend {
            service {
              name = kubernetes_service.nginx.metadata[0].name
              port {
                number = 80
              }
            }
          }
        }
      }
    }
  }

  depends_on = [kubernetes_service.nginx]
}

# Network Policy
resource "kubernetes_network_policy" "main_network_policy" {
  metadata {
    name      = "main-network-policy"
    namespace = kubernetes_namespace.main.metadata[0].name
  }

  spec {
    pod_selector {
      match_labels = {
        app = "nginx"
      }
    }

    policy_types = ["Ingress", "Egress"]

    ingress {
      from {
        pod_selector {
          match_labels = {
            app = "nginx"
          }
        }
      }

      ports {
        port     = "80"
        protocol = "TCP"
      }
    }

    egress {
      to {
        pod_selector {
          match_labels = {
            app = "postgres"
          }
        }
      }

      ports {
        port     = "5432"
        protocol = "TCP"
      }
    }

    egress {
      to {
        namespace_selector {
          match_labels = {
            name = "kube-system"
          }
        }
      }
    }
  }

  depends_on = [kubernetes_namespace.main]
}
