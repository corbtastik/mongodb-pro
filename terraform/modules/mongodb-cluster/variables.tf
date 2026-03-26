variable "project_name" {
  description = "Name of the MongoDB project (used for namespace and resource names)"
  type        = string
}

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

variable "cluster_type" {
  description = "MongoDB cluster type: Standalone or ReplicaSet"
  type        = string
  default     = "Standalone"

  validation {
    condition     = contains(["Standalone", "ReplicaSet"], var.cluster_type)
    error_message = "cluster_type must be either 'Standalone' or 'ReplicaSet'"
  }
}

variable "members" {
  description = "Number of replica set members (ignored for Standalone)"
  type        = number
  default     = 3
}

variable "mongodb_version" {
  description = "MongoDB version"
  type        = string
  default     = "8.0.0-ent"
}

variable "cpu_limit" {
  description = "CPU limit per pod"
  type        = string
  default     = "2"
}

variable "memory_limit" {
  description = "Memory limit per pod"
  type        = string
  default     = "4Gi"
}

variable "cluster_version" {
  description = "Version trigger for cluster recreation"
  type        = string
  default     = "1.0"
}

variable "depends_on_resource_id" {
  description = "Resource ID to depend on (for ordering after operator setup)"
  type        = string
  default     = ""
}
