locals {
  api_subdomain = "api"
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

    kubectl = {
      source = "gavinbunney/kubectl"
      version = "1.9.4"
    }
  }
}
######### PROVIDERS #########
provider "digitalocean" {
  token = var.do_token
}

provider "kubernetes" {
  load_config_file = false
  host = digitalocean_kubernetes_cluster.k8s_cluster.endpoint
  token = digitalocean_kubernetes_cluster.k8s_cluster.kube_config[0].token
  cluster_ca_certificate = base64decode(digitalocean_kubernetes_cluster.k8s_cluster.kube_config[0].cluster_ca_certificate)
}

provider "kubectl" {
  load_config_file = false
  host = digitalocean_kubernetes_cluster.k8s_cluster.endpoint
  token = digitalocean_kubernetes_cluster.k8s_cluster.kube_config[0].token
  cluster_ca_certificate = base64decode(digitalocean_kubernetes_cluster.k8s_cluster.kube_config[0].cluster_ca_certificate)
}

provider "helm" {
  kubernetes {
    host = digitalocean_kubernetes_cluster.k8s_cluster.endpoint
    token = digitalocean_kubernetes_cluster.k8s_cluster.kube_config[0].token
    cluster_ca_certificate = base64decode(digitalocean_kubernetes_cluster.k8s_cluster.kube_config[0].cluster_ca_certificate)
  }
}

######### DIGITAL OCEAN RESOURCES #########
resource "digitalocean_project" "project" {
  name = "blog-dev"
  description = "msawicki.dev blog - DEV"
  environment = "Development"
}

resource "digitalocean_kubernetes_cluster" "k8s_cluster" {
  name = "blog-dev"
  region = var.do_region
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

resource "digitalocean_kubernetes_node_pool" "k8s_cluster_nodes--elasticsearch" {
  cluster_id = digitalocean_kubernetes_cluster.k8s_cluster.id
  name = "elasticsearch-pool"
  size = "s-2vcpu-4gb"
  node_count = 1

  labels = {
    app = "elasticsearch"
  }
}

# Binding resources to a newly created project
resource "digitalocean_project_resources" "blog-dev-resources" {
  project = digitalocean_project.project.id
  resources = ["do:kubernetes:${digitalocean_kubernetes_cluster.k8s_cluster.id}"]
}

######### DOMAIN STUFF #########
resource "helm_release" "ingress-nginx" {
  repository = "https://kubernetes.github.io/ingress-nginx"
  chart = "ingress-nginx"
  name = "ingress-nginx"

  values = [
    templatefile("${path.module}/templates/ingress-nginx.yaml", {
      base_domain = var.base_domain
    })
  ]
}

resource "digitalocean_domain" "domain" {
  name = var.base_domain
}

resource "digitalocean_project_resources" "domain-attachment" {
  project = digitalocean_project.project.id
  resources = ["do:domain:${digitalocean_domain.domain.id}"]
}

######### APP MODULES #########
module "elasticsearch" {
  source = "../modules/elasticsearch"
}

module "cert-manager" {
  source = "../modules/cert-manager"

  email = var.cert_mail
}

module "backend" {
  source = "../modules/backend"

  elasticsearch_url = module.elasticsearch.master_node_ip
  api_domain = "${local.api_subdomain}.${var.base_domain}"
  cert_cluster_issuer_name = module.cert-manager.cert_cluster_issuer_name
}

resource "digitalocean_record" "backend-api" {
  domain = digitalocean_domain.domain.name
  name = local.api_subdomain
  type = "A"
  value = module.backend.public_ip
}
