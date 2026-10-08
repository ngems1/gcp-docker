variable "project_id" {
  description = "GCP project ID to deploy into."
  type        = string
}

variable "github_repo" {
  description = "GitHub repository allowed to deploy, as owner/repo."
  type        = string

  validation {
    condition     = can(regex("^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$", var.github_repo))
    error_message = "github_repo must look like owner/repo."
  }
}

variable "deploy_branch" {
  description = "Only workflow runs on this branch can get GCP credentials."
  type        = string
  default     = "main"
}

variable "region" {
  description = "Region for the subnet, static IP, Artifact Registry and Firestore."
  type        = string
  default     = "us-east1"
}

variable "zone" {
  description = "Zone for the VM."
  type        = string
  default     = "us-east1-b"
}

variable "name" {
  description = "Base name used for most resources."
  type        = string
  default     = "profile-app"
}

variable "machine_type" {
  description = "VM machine type."
  type        = string
  default     = "e2-small"
}

variable "subnet_cidr" {
  description = "Primary range of the VM subnet."
  type        = string
  default     = "10.10.0.0/24"
}

variable "vm_internal_ip" {
  description = "Fixed internal IP of the VM (must be inside subnet_cidr)."
  type        = string
  default     = "10.10.0.10"
}

variable "firestore_database_id" {
  description = "Firestore database ID. The app uses it as the MongoDB database name (MONGO_DB_NAME)."
  type        = string
  default     = "user-account"
}

variable "protect_database" {
  description = "true = enable Firestore delete protection and keep the database on terraform destroy."
  type        = bool
  default     = false
}

variable "wif_pool_id" {
  description = "Workload Identity Pool ID. Deleted pools keep their ID reserved for 30 days, so change this if you destroy and re-create within that window."
  type        = string
  default     = "github-pool"
}

variable "wif_provider_id" {
  description = "Workload Identity Pool provider ID."
  type        = string
  default     = "github-provider"
}
