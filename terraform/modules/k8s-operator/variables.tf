variable "scripts_path" {
  description = "Absolute path to the scripts directory"
  type        = string
}

variable "project_path" {
  description = "Absolute path to the project root directory"
  type        = string
}

variable "ops_manager_url" {
  description = "Ops Manager URL (http or https)"
  type        = string
}

variable "ops_manager_org_id" {
  description = "Ops Manager Organization ID"
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

variable "operator_version" {
  description = "Version trigger for operator reinstallation"
  type        = string
  default     = "1.0"
}

variable "depends_on_resource_id" {
  description = "Resource ID to depend on (for ordering after Ops Manager setup)"
  type        = string
  default     = ""
}
