output "master_node_ip" {
  value = "${helm_release.elasticsearch.name}-master:9200"
}
