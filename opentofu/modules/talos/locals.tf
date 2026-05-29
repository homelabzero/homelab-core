locals {
  schematic_id    = jsondecode(data.http.image_factory_schematic.response_body).id
  installer_image = "factory.talos.dev/installer/${local.schematic_id}:v${var.talos_version}"

  node_patches = { for name, n in var.nodes : name => join("---\n", [
    templatefile("${path.module}/configs/controlplane.yaml", {
      install_disk      = coalesce(n.install_disk, var.install_disk)
      installer_image   = local.installer_image
      network_interface = n.network_interface
      cluster_endpoint  = var.cluster_endpoint
    }),
    templatefile("${path.module}/configs/netbird-extension.yaml", {
      setup_key      = var.netbird_setup_key
      management_url = var.netbird_management_url
      hostname       = name
    }),
  ]) }

  # Bootstrap target: alphabetically first node, reached on its public IP.
  bootstrap_node_name = sort(keys(var.nodes))[0]
  bootstrap_node_ip   = var.nodes[local.bootstrap_node_name].public_ip
}
