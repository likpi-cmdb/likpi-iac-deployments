variable "environment" {
  type        = string
  description = "Target deployment environment"
  default     = "PROD"
}

variable "app_name" {
  type        = string
  description = "Application name in CMDB"
  default     = "app-billing-backend"
}

variable "app_id" {
  type        = string
  description = "Unique Identifier for the application"
  default     = "APP-BILLING-EU-01"
}

variable "db_cluster_name" {
  type        = string
  description = "Target Database CI name"
  default     = "db-postgres-prod"
}
