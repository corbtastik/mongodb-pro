# =============================================================================
# Ops Manager Configuration
# =============================================================================

variable "enable_tls" {
  description = "Enable TLS for Ops Manager"
  type        = bool
  default     = true
}

variable "ops_manager_org_id" {
  description = "Ops Manager Organization ID (from UI after initial setup)"
  type        = string
}

variable "ops_manager_api_public_key" {
  description = "Ops Manager API Public Key"
  type        = string
}

variable "ops_manager_api_private_key" {
  description = "Ops Manager API Private Key"
  type        = string
  sensitive   = true
}

# =============================================================================
# MongoDB Cluster Configuration
# =============================================================================

variable "deploy_cluster" {
  description = "Whether to deploy a MongoDB cluster"
  type        = bool
  default     = true
}

variable "cluster_name" {
  description = "Name for the MongoDB cluster/project"
  type        = string
  default     = "demo-01"
}

variable "cluster_type" {
  description = "MongoDB cluster type: Standalone or ReplicaSet"
  type        = string
  default     = "Standalone"
}

variable "cluster_members" {
  description = "Number of replica set members (ignored for Standalone)"
  type        = number
  default     = 3
}

variable "cluster_cpu_limit" {
  description = "CPU limit per MongoDB pod"
  type        = string
  default     = "2"
}

variable "cluster_memory_limit" {
  description = "Memory limit per MongoDB pod"
  type        = string
  default     = "4Gi"
}

# =============================================================================
# Version Triggers (change to force recreation)
# =============================================================================

variable "vm_version" {
  description = "Version trigger for VM"
  type        = string
  default     = "1.0"
}

variable "appdb_version" {
  description = "Version trigger for AppDB"
  type        = string
  default     = "1.0"
}

variable "ops_manager_version" {
  description = "Version trigger for Ops Manager"
  type        = string
  default     = "1.0"
}

variable "tls_version" {
  description = "Version trigger for TLS"
  type        = string
  default     = "1.0"
}

variable "operator_version" {
  description = "Version trigger for K8s Operator"
  type        = string
  default     = "1.0"
}

variable "cluster_version" {
  description = "Version trigger for MongoDB cluster"
  type        = string
  default     = "1.0"
}
