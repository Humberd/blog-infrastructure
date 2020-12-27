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

    labels = {
      type = "casual_worker"
    }
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

# Binding resources to a newly created project
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

  values = [
    templatefile("${path.module}/templates/elasticsearch-values.yaml", {
      es_ingress_enabled = true
      es_host = "elasticsearch.foobar"
    })
  ]
}

resource "kubernetes_deployment" "blog-backend" {
  metadata {
    name = "blog-backend-deployment"
    labels = {
      app = "blog-backend"
    }
  }
  spec {
    selector {
      match_labels = {
        app = "blog-backend"
      }
    }
    template {
      metadata {
        labels = {
          app = "blog-backend"
        }
      }
      spec {
        node_selector = {
          type = "casual_worker"
        }
        container {
          image = "humberd/blog-backend:2"
          name = "kotlin-spring"
          port {
            container_port = 8080
          }
        }
      }
    }
  }
}

resource "kubernetes_service" "blog-backend" {
  metadata {
    name = "blog-backend-service"
    labels = {
      app = "blog-backend"
    }
  }
  spec {
    type = "NodePort"

    selector = {
      app = "blog-backend"
    }

    port {
      node_port = 32100
      port = 8080
      target_port = 8080
    }
  }
}

resource "kubernetes_service" "blog-backend-lb" {
  metadata {
    name = "blog-backend-lb"
    labels = {
      app = "blog-backend"
    }
    annotations = {
      "service.beta.kubernetes.io/do-loadbalancer-name" = "blog.mydomain.com"
      "service.beta.kubernetes.io/do-loadbalancer-hostname" = "blog.mydomain.com"
    }
  }
  spec {
    type = "LoadBalancer"

    selector = {
      app = "blog-backend"
    }

    port {
      port = 8080
      target_port = 8080
    }
  }
}

//resource "kubernetes_ingress" "blog-backend" {
//  metadata {
//    name = "blog-backend-ingress"
//    annotations = {
//      "kubernetes.io/ingress.class" = "nginx"
//    }
//  }
//  spec {
//    rule {
//      host = "do.humberd.pl"
//      http {
//        path {
//          backend {
//            service_name = "blog-backend-service"
//            service_port = 8080
//          }
//          path = "/"
//        }
//      }
//    }
//  }
//}

resource "digitalocean_domain" "blog-backend-domain" {
  name = "blog.do.humberd.pl"
}
