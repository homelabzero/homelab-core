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
        # Initial endpoints are public IPs — talosctl reaches the API on port 50000.
        # Once netbird is up and a peer DNS / fixed IP is known, point talosconfig
        # at the netbird IP instead.
        endpoints = [for _, n in var.nodes : n.public_ip]
        ca        = talos_machine_secrets.this.client_configuration.ca_certificate
        crt       = talos_machine_secrets.this.client_configuration.client_certificate
        key       = talos_machine_secrets.this.client_configuration.client_key
      }
    }
  })
}

output "node_names" {
  value       = keys(var.nodes)
  description = "Node names in lexical order — useful to verify state matches tfvars."
}
