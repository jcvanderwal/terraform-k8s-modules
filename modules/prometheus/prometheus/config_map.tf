resource "k8s_core_v1_config_map" "this" {
  data = {
    "prometheus.yml" = data.template_file.config.rendered
  }

  metadata {
    name      = var.name
    namespace = var.namespace
  }
}