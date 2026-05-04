output "talos_mac_addresses" {
  value = {
    for name, vm in proxmox_virtual_environment_vm.talos :
    name => vm.network_device[0].mac_address
  }
}
