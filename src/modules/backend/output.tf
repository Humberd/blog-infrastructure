output "public_ip" {
  value = kubernetes_ingress.blog-backend-ingress.load_balancer_ingress[0].ip
}
