resource "helm_release" "elasticsearch" {
  repository = "https://helm.elastic.co"
  chart = "elasticsearch"
  name = "elasticsearch"

  values = [
    templatefile("${path.module}/templates/elasticsearch-values.yaml", {
      es_ingress_enabled = false
      es_host = "elasticsearch.foobar"
    })
  ]
}
