locals {
  region = "fra1"
}

terraform {
  required_providers {
    digitalocean = {
      source = "digitalocean/digitalocean"
      version = "2.3.0"
    }

    helm = {
      source = "hashicorp/helm"
      version = "2.0.1"
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
  tags = ["dev"]

  node_pool {
    name = "worker-pool"
    size = "s-1vcpu-2gb"
    node_count = 1
  }
}

resource "digitalocean_kubernetes_node_pool" "blog-dev-elasticsearch-nodes" {
  cluster_id = digitalocean_kubernetes_cluster.blog-dev.id
  name = "elasticsearch-pool"
  size = "s-2vcpu-4gb"
  node_count = 1

  labels = {
    app = "elasticsearch"
  }
}

resource "digitalocean_project_resources" "blog-dev-resources" {
  project = digitalocean_project.blog-dev.id
  resources = ["do:kubernetes:${digitalocean_kubernetes_cluster.blog-dev.id}"]
}

provider "kubernetes" {
  load_config_file = false
  host = digitalocean_kubernetes_cluster.blog-dev.endpoint
  token = digitalocean_kubernetes_cluster.blog-dev.kube_config[0].token
  cluster_ca_certificate = base64decode(digitalocean_kubernetes_cluster.blog-dev.kube_config[0].cluster_ca_certificate)
}

provider "helm" {
  kubernetes {
    host = digitalocean_kubernetes_cluster.blog-dev.endpoint
    token = digitalocean_kubernetes_cluster.blog-dev.kube_config[0].token
    cluster_ca_certificate = base64decode(digitalocean_kubernetes_cluster.blog-dev.kube_config[0].cluster_ca_certificate)
  }
}

resource "helm_release" "elasticsearch" {
  repository = "https://helm.elastic.co"
  chart = "elasticsearch"
  name = "elasticsearch"

  set {
    name = "replicas"
    value = 1
  }
}

//resource "kubernetes_deployment" "blog-backend" {
//  metadata {
//    name = "blog-backend-deployment"
//    labels = {
//      app = "kotlin-spring"
//    }
//  }
//  spec {
//    selector {
//      match_labels = {
//        app = "kotlin-spring"
//      }
//    }
//    template {
//      metadata {
//        labels = {
//          app = "kotlin-spring"
//        }
//      }
//      spec {
//        container {
//          image = "humberd/blog-backend:1"
//          name = "kotlin-spring"
//          port {
//            container_port = 8080
//          }
//        }
//      }
//    }
//  }
//}
