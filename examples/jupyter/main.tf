resource "k8s_core_v1_namespace" "this" {
  metadata {
    name = var.namespace
  }
}

module "nfs-server" {
  source    = "../../modules/nfs-server-empty-dir"
  name      = "nfs-server"
  namespace = k8s_core_v1_namespace.this.metadata[0].name
}

resource "k8s_core_v1_persistent_volume" "jupyter-users" {
  metadata {
    name = var.name
  }
  spec {
    storage_class_name               = var.name
    persistent_volume_reclaim_policy = "Retain"
    access_modes                     = ["ReadWriteOnce"]
    capacity = {
      storage = var.user_storage
    }
    nfs {
      path   = "/"
      server = module.nfs-server.service.spec[0].cluster_ip
    }
    mount_options = module.nfs-server.mount_options
  }
}

resource "k8s_core_v1_persistent_volume_claim" "jupyter-users" {
  metadata {
    name      = var.user_pvc_name
    namespace = k8s_core_v1_namespace.this.metadata[0].name
  }
  spec {
    storage_class_name = k8s_core_v1_persistent_volume.jupyter-users.spec[0].storage_class_name
    volume_name        = k8s_core_v1_persistent_volume.jupyter-users.metadata[0].name
    access_modes       = ["ReadWriteOnce"]
    resources {
      requests = {
        storage = var.user_storage
      }
    }
  }
}

locals {
  profile_list = [
    {
      display_name = "minimal-notebook",
      description  = "command line tools useful when working in Jupyter applications",
      default      = "true",
      kubespawner_override = {
        image          = "jupyter/minimal-notebook:latest",
        args           = ["--allow-root"],
        singleuser_uid = 0,
      }
    },
    {
      display_name = "scipy-notebook",
      description  = "includes popular packages from the scientific Python ecosystem",
      kubespawner_override = {
        image          = "jupyter/scipy-notebook:latest",
        args           = ["--allow-root"],
        singleuser_uid = 0,
      }
    },
    {
      display_name = "r-notebook",
      description  = "includes popular packages from the R ecosystem",
      kubespawner_override = {
        image          = "jupyter/r-notebook:latest",
        args           = ["--allow-root"],
        singleuser_uid = 0,
      }
    },
    {
      display_name = "tensorflow-notebook",
      description  = "includes popular Python deep learning libraries",
      kubespawner_override = {
        image          = "jupyter/tensorflow-notebook:latest",
        args           = ["--allow-root"],
        singleuser_uid = 0,
      }
    },
    {
      display_name = "datascience-notebook",
      description  = "includes libraries for data analysis from the Julia, Python, and R communities",
      kubespawner_override = {
        image          = "jupyter/datascience-notebook:latest",
        args           = ["--allow-root"],
        singleuser_uid = 0,
      }
    },
    {
      display_name = "pyspark-notebook",
      description  = "includes Python support for Apache Spark",
      kubespawner_override = {
        image          = "jupyter/pyspark-notebook:latest",
        args           = ["--allow-root"],
        singleuser_uid = 0,
      }
    },
    {
      display_name = "all-spark-notebook",
      description  = "includes Python, R, and Scala support for Apache Spark",
      kubespawner_override = {
        image          = "jupyter/all-spark-notebook:latest",
        args           = ["--allow-root"],
        singleuser_uid = 0,
      }
    },
    {
      display_name = "elyra/nb2kg",
      description  = "Use Enterprise Gateway",
      kubespawner_override = {
        image          = "elyra/nb2kg:dev",
        args           = ["--allow-root"],
        singleuser_uid = 0,
      }
    },
  ]

  preload_images = concat(
    local.profile_list[*].kubespawner_override.image,
    [
      "elyra/kernel-py:dev",
      "elyra/kernel-spark-py:dev",
      "elyra/kernel-tf-py:dev",
      "elyra/kernel-scala:dev",
      "elyra/kernel-r:dev",
      "elyra/kernel-spark-r:dev",
    ]
  )
}

/*
Depends on ../alluxio
Remove if not needed
*/
resource "k8s_core_v1_persistent_volume_claim" "alluxio" {
  metadata {
    name      = "alluxio"
    namespace = var.namespace
  }

  spec {
    access_modes = ["ReadWriteOnce"]

    resources {
      requests = { "storage" = "1Gi" }
    }

    storage_class_name = "alluxio"
  }
}

module "config" {
  source    = "../../modules/jupyter/jupyterhub/config"
  name      = var.name
  namespace = k8s_core_v1_namespace.this.metadata[0].name

  hub_extraConfig = {
    "enterprise-gateway" = "config = '/etc/jupyter/jupyter_notebook_config.py'"
  }
  singleuser_extraEnv = {
    "KG_URL"             = "http://enterprise-gateway:8888",
    "KG_REQUEST_TIMEOUT" = "60",
    "KG_HTTP_USER"       = "jovyan",
    "KERNEL_USERNAME"    = "jovyan",
    "KERNEL_UID"         = "0",
  }
  singleuser_image_name             = "jupyter/minimal-notebook:latest"
  singleuser_image_tag              = "latest"
  singleuser_profile_list           = local.profile_list
  singleuser_storage_static_pvcName = var.user_pvc_name

  /*
  Optional custom auth using keycloak
  Depends on ../keycloak
  */
  auth_type = "custom"
  auth_custom = {
    className = "oauthenticator.generic.GenericOAuthenticator"
    config = {
      login_service   = "keycloak"
      client_id       = "jupyterhub"
      client_secret   = "9ed52cc6-c1de-4186-b2c3-4a5ecbdb2048"
      token_url       = "https://keycloak.rebelsoft.com/auth/realms/master/protocol/openid-connect/token"
      userdata_url    = "https://keycloak.rebelsoft.com/auth/realms/master/protocol/openid-connect/userinfo"
      userdata_method = "GET"
      userdata_params = {
        state = "state"
      }
      username_key = "preferred_username"
    }
  }

  /*
  Optional additional data volume
  Depends on ../alluxio
  */
  singleuser_storage_extra_volume_mounts = [
    {
      name      = "alluxio-fuse-mount"
      mountPath = "/alluxio"
    }
  ]
  singleuser_storage_extra_volumes = [
    {
      name = "alluxio-fuse-mount"
      persistentVolumeClaim = {
        claimName = k8s_core_v1_persistent_volume_claim.alluxio.metadata[0].name
      }
    }
  ]
}

module "proxy" {
  source    = "../../modules/jupyter/jupyterhub/proxy"
  name      = "${var.name}-proxy"
  namespace = k8s_core_v1_namespace.this.metadata[0].name

  annotations = {
    "config-checksum" = module.config.config_checksum
    "secret-checksum" = module.config.secret_checksum
  }
  secret_name      = module.config.secret.metadata[0].name
  hub_service_host = "${var.name}-hub"
  hub_service_port = 8081
}

module "hub" {
  source    = "../../modules/jupyter/jupyterhub/hub"
  name      = "${var.name}-hub"
  namespace = k8s_core_v1_namespace.this.metadata[0].name

  annotations = {
    "config-checksum" = module.config.config_checksum
    "secret-checksum" = module.config.secret_checksum
  }
  config_map                = module.config.config_map.metadata[0].name
  secret_name               = module.config.secret.metadata[0].name
  proxy_api_service_host    = "${var.name}-proxy"
  proxy_api_service_port    = 8001
  proxy_public_service_host = k8s_extensions_v1beta1_ingress.this.spec[0].rules[0].host
  proxy_public_service_port = 80

  /*
  Depends on ../keycloak
  Remove if not needed
  */
  OAUTH2_AUTHORIZE_URL = "https://keycloak.rebelsoft.com/auth/realms/master/protocol/openid-connect/auth"
  OAUTH2_TOKEN_URL     = "https://keycloak.rebelsoft.com/auth/realms/master/protocol/openid-connect/token"
  OAUTH_CALLBACK_URL   = "https://jupyter.rebelsoft.com/hub/oauth_callback"
}

resource "k8s_extensions_v1beta1_ingress" "this" {
  metadata {
    annotations = {
      "kubernetes.io/ingress.class"              = "nginx"
      "nginx.ingress.kubernetes.io/server-alias" = "${var.name}.*"
      "certmanager.k8s.io/cluster-issuer"        = "letsencrypt-prod"
    }
    name      = var.name
    namespace = k8s_core_v1_namespace.this.metadata[0].name
  }
  spec {
    rules {
      host = "${var.name}.rebelsoft.com"
      http {
        paths {
          backend {
            service_name = module.proxy.service.metadata[0].name
            service_port = module.proxy.service.spec[0].ports[0].port
          }
          path = "/"
        }
      }
    }

    tls {
      hosts = [
        "${var.name}.rebelsoft.com"
      ]
      secret_name = "${var.name}-tls"
    }
  }
}

module "preloader" {
  source = "../../archetypes/daemonset"
  parameters = {
    name                             = "${var.name}-preloader"
    namespace                        = k8s_core_v1_namespace.this.metadata[0].name
    termination_grace_period_seconds = 1
    containers = [for entry in local.preload_images :
      {
        command           = ["sleep", "86400"]
        image             = entry
        image_pull_policy = "Always"
        name              = replace(replace(entry, "/", "-"), ":", "-")
      }
    ]
  }
}

module "enterprise-gateway" {
  source    = "../../modules/jupyter/enterprise-gateway"
  namespace = k8s_core_v1_namespace.this.metadata[0].name
}