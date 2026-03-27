# =============================================================================
# Ops Manager Configuration
# =============================================================================

variable "enable_tls" {
  description = "Enable TLS for Ops Manager"
  type        = bool
  default     = true
}

# API credentials - create in Ops Manager UI after admin user setup
variable "ops_manager_org_id" {
  description = "Ops Manager Organization ID"
  type        = string
  default     = ""
}

variable "ops_manager_api_public_key" {
  description = "Ops Manager API Public Key"
  type        = string
  default     = ""
}

variable "ops_manager_api_private_key" {
  description = "Ops Manager API Private Key"
  type        = string
  default     = ""
  sensitive   = true
}

# =============================================================================
# MongoDB Cluster Configuration
# =============================================================================

variable "clusters" {
  description = "Map of MongoDB clusters to deploy"
  type = map(object({
    type         = string           # "Standalone" or "ReplicaSet"
    members      = optional(number, 3)
    cpu_limit    = optional(string, "2")
    memory_limit = optional(string, "4Gi")
    version      = optional(string, "1.0")
  }))
  default = {}
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
