terraform {
  required_version = ">= 0.13.0"
  required_providers {
    google      = ">= 3.78"
    google-beta = ">= 3.78"
  }
  backend "gcs" {
    bucket = "drebes-lab-gke-iap-cip-816d"
  }
}

