module "dev_tools_namespace" {
  source = "github.com/ibm-garage-cloud/terraform-k8s-namespace.git"

  
  cluster_config_file_path = module.dev_cluster.config_file_path  
  name                     = var.tools_namespace
}
