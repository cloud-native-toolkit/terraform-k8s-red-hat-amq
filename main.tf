
provider "helm" {
  version = ">= 1.1.1"

  kubernetes {
    config_path = var.cluster_config_file
  }
}

locals {
  tmp_dir       = "${path.cwd}/.tmp"
  host          = "${var.name}-amq-bootstrap-${var.app_namespace}.${var.ingress_subdomain}"
  url_endpoint  = "https://${local.host}"
}

resource "null_resource" "amq-subscription" {
  triggers = {
    TMP_DIR            = local.tmp_dir
    KUBECONFIG         = var.cluster_config_file
    OPERATOR_NAMESPACE = var.operator_namespace
  }

  provisioner "local-exec" {
    command = "${path.module}/scripts/deploy-subscription.sh ${var.cluster_type} ${self.triggers.OPERATOR_NAMESPACE} ${var.olm_namespace}"

    environment = {
      TMP_DIR    = self.triggers.TMP_DIR
      KUBECONFIG = self.triggers.KUBECONFIG
    }
  }

  provisioner "local-exec" {
    when    = destroy

    command = "${path.module}/scripts/destroy-subscription.sh ${self.triggers.OPERATOR_NAMESPACE}"

    environment = {
      TMP_DIR    = self.triggers.TMP_DIR
      KUBECONFIG = self.triggers.KUBECONFIG
    }
  }
}

resource "null_resource" "amq-instance" {
  depends_on = [null_resource.amq-subscription]

  triggers = {
    TMP_DIR       = local.tmp_dir
    KUBECONFIG    = var.cluster_config_file
    APP_NAMESPACE = var.app_namespace
    NAME          = var.name
  }

  provisioner "local-exec" {
    command = "${path.module}/scripts/deploy-instance.sh ${var.cluster_type} ${self.triggers.APP_NAMESPACE} ${var.ingress_subdomain} ${self.triggers.NAME}"

    environment = {
      TMP_DIR    = self.triggers.TMP_DIR
      KUBECONFIG = self.triggers.KUBECONFIG
    }
  }

  provisioner "local-exec" {
    command = "${path.module}/scripts/destroy-instance.sh ${self.triggers.APP_NAMESPACE} ${self.triggers.NAME}"

    environment = {
      TMP_DIR    = self.triggers.TMP_DIR
      KUBECONFIG = self.triggers.KUBECONFIG
    }
  }
}

resource "helm_release" "amq-config" {
  depends_on = [null_resource.amq-instance]

  name         = "amq"
  repository   = "https://ibm-garage-cloud.github.io/toolkit-charts/"
  chart        = "tool-config"
  namespace    = var.app_namespace
  force_update = true

  set {
    name  = "url"
    value = local.url_endpoint
  }
}


  


