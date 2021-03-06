resource "k8s_core_v1_config_map" "config-network" {
  data = {
    "_example" = <<-EOF
      ################################
      #                              #
      #    EXAMPLE CONFIGURATION     #
      #                              #
      ################################
      
      # This block is not actually functional configuration,
      # but serves to illustrate the available configuration
      # options and document them in a way that is accessible
      # to users that `kubectl edit` this config map.
      #
      # These sample configuration options may be copied out of
      # this block and unindented to actually change the configuration.
      
      # istio.sidecar.includeOutboundIPRanges specifies the IP ranges that Istio sidecar
      # will intercept.
      #
      # Replace this with the IP ranges of your cluster (see below for some examples).
      # Separate multiple entries with a comma.
      # Example: "10.4.0.0/14,10.7.240.0/20"
      #
      # If set to "*" Istio will intercept all traffic within
      # the cluster as well as traffic that is going outside the cluster.
      # Traffic going outside the cluster will be blocked unless
      # necessary egress rules are created.
      #
      # If omitted or set to "", value of global.proxy.includeIPRanges
      # provided at Istio deployment time is used. In default Knative serving
      # deployment, global.proxy.includeIPRanges value is set to "*".
      #
      # If an invalid value is passed, "" is used instead.
      #
      # If valid set of IP address ranges are put into this value,
      # Istio will no longer intercept traffic going to IP addresses
      # outside the provided ranges and there is no need to specify
      # egress rules.
      #
      # To determine the IP ranges of your cluster:
      #   IBM Cloud Private: cat cluster/config.yaml | grep service_cluster_ip_range
      #   IBM Cloud Kubernetes Service: "172.30.0.0/16,172.20.0.0/16,10.10.10.0/24"
      #   Google Container Engine (GKE): gcloud container clusters describe XXXXXXX --zone=XXXXXX | grep -e clusterIpv4Cidr -e servicesIpv4Cidr
      #   Azure Kubernetes Service (AKS): "10.0.0.0/16"
      #   Azure Container Service (ACS; deprecated): "10.244.0.0/16,10.240.0.0/16"
      #   Azure Container Service Engine (ACS-Engine; OSS): Configurable, but defaults to "10.0.0.0/16"
      #   Minikube: "10.0.0.1/24"
      #
      # For more information, visit
      # https://istio.io/docs/tasks/traffic-management/egress/
      #
      istio.sidecar.includeOutboundIPRanges: "*"
      
      # clusteringress.class specifies the default cluster ingress class
      # to use when not dictated by Route annotation.
      #
      # If not specified, will use the Istio ingress.
      #
      # Note that changing the ClusterIngress class of an existing Route
      # will result in undefined behavior.  Therefore it is best to only
      # update this value during the setup of Knative, to avoid getting
      # undefined behavior.
      clusteringress.class: "istio.ingress.networking.knative.dev"
      
      EOF
  }
  metadata {
    labels = {
      "serving.knative.dev/release" = "devel"
    }
    name      = "config-network"
    namespace = "${var.namespace}"
  }
}