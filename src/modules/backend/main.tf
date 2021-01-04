resource "kubernetes_deployment" "blog-backend" {
  metadata {
    name = "blog-backend-deployment"
    labels = {
      app = "blog-backend"
    }
  }
  spec {
    replicas = 3

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
          image = "humberd/blog-backend:3"
          name = "kotlin-spring"
          port {
            container_port = 8080
          }

          env {
            name = "elasticsearch.url"
            value = var.elasticsearch_url
          }
        }
      }
    }
  }
}

resource "kubernetes_service" "blog-backend" {
  depends_on = [kubernetes_deployment.blog-backend]

  metadata {
    name = "blog-backend-service"
    labels = {
      app = "blog-backend"
    }
  }
  spec {
    type = "ClusterIP"

    selector = {
      app = "blog-backend"
    }

    port {
      port = 8080
      target_port = 8080
    }
  }
}

resource "kubernetes_ingress" "blog-backend-ingress" {
  depends_on = [kubernetes_service.blog-backend]
  wait_for_load_balancer = true

  metadata {
    name = "blog-backend-ingress"
    annotations = {
      "kubernetes.io/ingress.class" = "nginx"
    }
  }

  spec {
    rule {
      host = var.api_domain
      http {
        path {
          backend {
            service_name = "blog-backend-service"
            service_port = 8080
          }
          path = "/"
        }
      }
    }
  }
}
