# =============================================================================
# MongoDB Clusters
# =============================================================================
# Ops Manager credentials are automatically read from control-plane state.
# You only need to define clusters here.

variable "clusters" {
  description = "Map of MongoDB clusters to deploy"
  type = map(object({
    type         = string                    # "Standalone" or "ReplicaSet"
    members      = optional(number, 3)       # ReplicaSet members (ignored for Standalone)
    cpu_limit    = optional(string, "2")     # CPU limit per pod
    memory_limit = optional(string, "4Gi")   # Memory limit per pod
    version      = optional(string, "1.0")   # Version trigger for recreation
  }))
  default = {}
}
