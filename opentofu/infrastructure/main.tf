module "talos" {
  source = "../modules/talos"

  cluster_name       = var.cluster_name
  cluster_endpoint   = var.api_hostname
  talos_version      = var.talos_version
  kubernetes_version = var.kubernetes_version
  install_disk       = var.install_disk

  nodes = var.nodes

  netbird_setup_key      = var.netbird_setup_key
  netbird_management_url = var.netbird_management_url
}

# Drop kubeconfig + talosconfig straight to disk so kubectl / talosctl can use
# them without copy-paste. Parent dirs are created as needed.
resource "local_sensitive_file" "kubeconfig" {
  content         = module.talos.kubeconfig
  filename        = pathexpand("~/.kube/homelab.kubeconfig")
  file_permission = "0600"
}

resource "local_sensitive_file" "talosconfig" {
  content         = module.talos.talosconfig
  filename        = pathexpand("~/.talos/config")
  file_permission = "0600"
}
