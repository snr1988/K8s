variable "namespace" {
  type        = string
  default     = "terraform-managed"
  description = "Kubernetes namespace"
}

variable "environment" {
  type        = string
  default     = "development"
  description = "Environment name (development, staging, production)"
}

variable "storage_size" {
  type        = string
  default     = "5Gi"
  description = "Storage size for persistent volumes"
}

# Nginx variables
variable "nginx_replicas" {
  type        = number
  default     = 2
  description = "Number of nginx replicas"
}

variable "nginx_cpu_request" {
  type        = string
  default     = "100m"
  description = "CPU request for nginx"
}

variable "nginx_cpu_limit" {
  type        = string
  default     = "200m"
  description = "CPU limit for nginx"
}

variable "nginx_memory_request" {
  type        = string
  default     = "128Mi"
  description = "Memory request for nginx"
}

variable "nginx_memory_limit" {
  type        = string
  default     = "256Mi"
  description = "Memory limit for nginx"
}

# PostgreSQL variables
variable "postgres_user" {
  type        = string
  default     = "postgres"
  description = "PostgreSQL username"
  sensitive   = true
}

variable "postgres_password" {
  type        = string
  default     = "postgres123"
  description = "PostgreSQL password"
  sensitive   = true
}

variable "postgres_db" {
  type        = string
  default     = "myapp_db"
  description = "PostgreSQL database name"
}

# Ingress variables
variable "ingress_host" {
  type        = string
  default     = "localhost"
  description = "Ingress host"
}
