/*provider "helm" {
  version = ">= 1.1.1"

  kubernetes {
    config_path = var.cluster_config_file
  }
}*/

locals {
  tmp_dir       = "${path.cwd}/.tmp"
  host          = "${var.name}-kafka-bootstrap-${var.app_namespace}.${var.ingress_subdomain}"
  url_endpoint  = "https://${local.host}"
}  

resource "null_resource" "amq-instance" {
  //depends_on = [null_resource.kafka-subscription]

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

}

  


