locals {
  region = "fra1"
}

terraform {
  required_providers {
    digitalocean = {
      source = "digitalocean/digitalocean"
      version = "2.3.0"
    }
  }
}

provider "digitalocean" {
  token = var.digitalocean_token
}

resource "digitalocean_project" "blog-dev" {
  name = "blog-dev"
  description = "msawicki.dev blog - DEV"
  environment = "Development"
}

resource "digitalocean_kubernetes_cluster" "blog-dev" {
  name = "blog-dev"
  region = local.region
  version = "1.19.3-do.2"

  node_pool {
    name = "worker-pool"
    size = "s-1vcpu-2gb"
    node_count = 2
  }
}


resource "digitalocean_project_resources" "blog-dev-resources" {
  project = digitalocean_project.blog-dev.id
  resources = [
    "do:kubernetes:${digitalocean_kubernetes_cluster.blog-dev.id}"
  ]
}
