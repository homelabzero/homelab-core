output "kubeconfig" {
  value     = talos_cluster_kubeconfig.this.kubeconfig_raw
  sensitive = true
}

output "talosconfig" {
  sensitive = true
  value = yamlencode({
    context = var.cluster_name
    contexts = {
      (var.cluster_name) = {
        endpoints = [var.controlplane_ip]
        ca        = talos_machine_secrets.this.client_configuration.ca_certificate
        crt       = talos_machine_secrets.this.client_configuration.client_certificate
        key       = talos_machine_secrets.this.client_configuration.client_key
      }
    }
  })
}
