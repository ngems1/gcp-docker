locals {
  github_variables = {
    GCP_PROJECT_ID   = var.project_id
    GCP_REGION       = var.region
    GCP_ZONE         = var.zone
    GCP_WIF_PROVIDER = google_iam_workload_identity_pool_provider.github.name
    GCP_DEPLOYER_SA  = google_service_account.deployer.email
    GCP_AR_REPO      = google_artifact_registry_repository.images.name
    GCE_VM_NAME      = google_compute_instance.vm.name
  }
}

output "github_variables" {
  description = "Set these as GitHub Actions repository variables (not secrets)."
  value       = local.github_variables
}

output "gh_variable_commands" {
  description = "Paste into a shell with the GitHub CLI logged in."
  value = join("\n", [
    for k, v in local.github_variables : "gh variable set ${k} -R ${var.github_repo} -b '${v}'"
  ])
}

output "app_url" {
  description = "Public URL of the app (after the first deploy)."
  value       = "http://${google_compute_address.vm.address}"
}

output "mongo_url" {
  description = "Firestore (MongoDB compatibility) connection string. Contains no credentials."
  value       = local.mongo_url
}
