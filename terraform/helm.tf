# ---------------------------------------------------------------
# ingress-nginx: entry point + canary traffic splitting
# NOTE: community ingress-nginx was retired in March 2026 (no more
# security patches). Used here for its canary-weight annotation;
# the migration path is Gateway API (HTTPRoute weighted backends).
# ---------------------------------------------------------------
resource "helm_release" "ingress_nginx" {
    name             = "ingress-nginx"
    repository       = "https://kubernetes.github.io/ingress-nginx"
    chart            = "ingress-nginx"
    version          = "4.15.1"
    namespace        = "ingress-nginx"
    create_namespace = true

    set {
        name  = "controller.metrics.enabled"
        value = "true"
    }
    set {
        name  = "controller.podAnnotations.prometheus\\.io/scrape"
        value = "true"
        type  = "string"
    }
    set {
        name  = "controller.podAnnotations.prometheus\\.io/port"
        value = "10254"
        type  = "string"
    }
    # Required on AKS so the Azure load balancer health probe passes
    set {
        name  = "controller.service.annotations.service\\.beta\\.kubernetes\\.io/azure-load-balancer-health-probe-request-path"
        value = "/healthz"
    }

    depends_on = [azurerm_kubernetes_cluster.aks]
}

# ---------------------------------------------------------------
# Lightweight Prometheus (server only) - the canary metrics gate
# queries this for the 5xx rate per version
# ---------------------------------------------------------------
resource "helm_release" "prometheus" {
    name             = "prometheus"
    repository       = "https://prometheus-community.github.io/helm-charts"
    chart            = "prometheus"
    version          = "29.35.0"
    namespace        = "monitoring"
    create_namespace = true

    set {
        name  = "alertmanager.enabled"
        value = "false"
    }
    set {
        name  = "prometheus-pushgateway.enabled"
        value = "false"
    }
    set {
        name  = "prometheus-node-exporter.enabled"
        value = "false"
    }
    set {
        name  = "kube-state-metrics.enabled"
        value = "false"
    }
    set {
        name  = "server.persistentVolume.enabled"
        value = "false"
    }
    set {
        name  = "server.global.scrape_interval"
        value = "15s"
    }

    depends_on = [azurerm_kubernetes_cluster.aks]
}
