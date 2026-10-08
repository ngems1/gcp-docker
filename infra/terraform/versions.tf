terraform {
  required_version = ">= 1.6"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 8.0"
    }
  }

  # Remote state (recommended once it works). Create the bucket once:
  #   gcloud storage buckets create gs://<project>-tfstate --location=us-east1 \
  #     --uniform-bucket-level-access && gcloud storage buckets update gs://<project>-tfstate --versioning
  # then uncomment, set the bucket, and run `terraform init -migrate-state`.
  #
  # backend "gcs" {
  #   bucket = "<project>-tfstate"
  #   prefix = "profile-app"
  # }
}

provider "google" {
  project = var.project_id
  region  = var.region
  zone    = var.zone

  default_labels = {
    app        = "profile-app"
    managed-by = "terraform"
  }
}
