# =============================================================================
# Ops Manager Configuration
# =============================================================================

variable "enable_tls" {
  description = "Enable TLS for Ops Manager (HTTPS on port 8443)"
  type        = bool
  default     = true
}

# =============================================================================
# API Credentials
# =============================================================================
# Create these in Ops Manager UI after admin user setup:
# Organization → Access Manager → API Keys

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
# Version Triggers
# =============================================================================
# Increment these to force recreation of specific resources

variable "vm_version" {
  description = "Version trigger for VM recreation"
  type        = string
  default     = "1.0"
}

variable "appdb_version" {
  description = "Version trigger for AppDB reinstall"
  type        = string
  default     = "1.0"
}

variable "ops_manager_version" {
  description = "Version trigger for Ops Manager reinstall"
  type        = string
  default     = "1.0"
}

variable "tls_version" {
  description = "Version trigger for TLS reconfiguration"
  type        = string
  default     = "1.0"
}

variable "operator_version" {
  description = "Version trigger for K8s Operator redeployment"
  type        = string
  default     = "1.0"
}
