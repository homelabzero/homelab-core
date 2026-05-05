output "kubeconfig" {
  value     = module.talos.kubeconfig
  sensitive = true
}

output "talosconfig" {
  value     = module.talos.talosconfig
  sensitive = true
}

output "talos_node_ips" {
  description = "Talos node IPs (DHCP from Proxmox IPAM, sticky per MAC)"
  value       = module.proxmox.talos_node_ips
}

output "talos_schematic_id" {
  description = "Talos factory schematic ID"
  value       = module.proxmox.talos_schematic_id
}
