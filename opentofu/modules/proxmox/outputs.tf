output "talos_node_ips" {
  description = "DHCP-assigned IPs of Talos VMs (reported by QEMU guest agent)"
  value = {
    for name, vm in proxmox_virtual_environment_vm.talos :
    name => [
      for ip in flatten(vm.ipv4_addresses) :
      ip if ip != "127.0.0.1" && !startswith(ip, "169.254.")
    ][0]
  }
}

output "vnet_id" {
  description = "SDN VNet ID (used as bridge name)"
  value       = proxmox_sdn_vnet.internal.id
}

output "talos_schematic_id" {
  description = "Talos factory schematic ID (used to build the installer image URL)"
  value       = local.talos_schematic_id
}
