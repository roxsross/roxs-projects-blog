terraform {
  required_providers {
    kind = {
      source  = "tehcyx/kind"
      version = "0.7.0"
    }

    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "2.33.0"
    }
  }

  required_version = ">= 1.0.0"
}
