output "kubeconfig" {
  value     = module.talos.kubeconfig
  sensitive = true
}

output "talos_mac_addresses" {
  value = module.proxmox.talos_mac_addresses
}

output "talosconfig" {
  value     = module.talos.talosconfig
  sensitive = true
}
