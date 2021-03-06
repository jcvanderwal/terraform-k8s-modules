resource "k8s_core_v1_service" "cert_manager_webhook" {
  metadata {
    labels = {
      "app"                          = "webhook"
      "app.kubernetes.io/instance"   = "cert-manager"
      "app.kubernetes.io/managed-by" = "Tiller"
      "app.kubernetes.io/name"       = "webhook"
      "helm.sh/chart"                = "cert-manager-v0.12.0"
    }
    name      = "cert-manager-webhook"
    namespace = var.namespace
  }
  spec {

    ports {
      name        = "https"
      port        = 443
      target_port = "10250"
    }
    selector = {
      "app"                          = "webhook"
      "app.kubernetes.io/instance"   = "cert-manager"
      "app.kubernetes.io/managed-by" = "Tiller"
      "app.kubernetes.io/name"       = "webhook"
    }
    type = "ClusterIP"
  }
}