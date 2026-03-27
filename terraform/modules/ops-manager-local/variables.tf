variable "scripts_path" {
  description = "Absolute path to the scripts directory"
  type        = string
}

variable "enable_tls" {
  description = "Enable TLS for Ops Manager (runs 03a-configure-tls.sh)"
  type        = bool
  default     = true
}

variable "vm_version" {
  description = "Version trigger for VM recreation"
  type        = string
  default     = "1.0"
}

variable "appdb_version" {
  description = "Version trigger for AppDB reinstallation"
  type        = string
  default     = "1.0"
}

variable "ops_manager_version" {
  description = "Version trigger for Ops Manager reinstallation"
  type        = string
  default     = "1.0"
}

variable "tls_version" {
  description = "Version trigger for TLS reconfiguration"
  type        = string
  default     = "1.0"
}
