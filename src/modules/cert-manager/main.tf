locals {
  cert_secret_name = "letsencrypt-private-key"
  cert_cluster_issuer_name = "letsencrypt"
}

terraform {
  required_version = ">= 0.13"

  required_providers {
    kubectl = {
      source = "gavinbunney/kubectl"
      version = "1.9.4"
    }
  }
}

resource "helm_release" "cert-manager" {
  repository = "https://charts.jetstack.io"
  chart = "cert-manager"
  name = "cert-manager"

  set {
    name = "installCRDs"
    value = "true"
  }
}

resource "kubectl_manifest" "letsencrypt-issuer" {
  depends_on = [helm_release.cert-manager]
  yaml_body = templatefile("${path.module}/templates/cert-issuer.yaml", {
    cert_cluster_issuer_name = local.cert_cluster_issuer_name
    email = var.email
    secret_name = local.cert_secret_name
  })
}
