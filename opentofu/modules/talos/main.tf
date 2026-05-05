resource "talos_machine_secrets" "this" {}

resource "talos_machine_configuration_apply" "controlplane" {
  client_configuration        = talos_machine_secrets.this.client_configuration
  machine_configuration_input = data.talos_machine_configuration.controlplane.machine_configuration
  node                        = var.node_initial_ips[var.controlplane_name]

  config_patches = [
    yamlencode({
      machine = {
        network = {
          nameservers = var.nameservers
        }
        install = {
          disk  = var.install_disk
          image = "factory.talos.dev/installer/${var.schematic_id}:v${var.talos_version}"
        }
      }
    }),
    yamlencode({
      cluster = {
        network = {
          cni = {
            name = "none"
          }
        }
        proxy = {
          disabled = true
        }
      }
    })
  ]
}

resource "talos_machine_configuration_apply" "worker" {
  for_each = var.worker_nodes

  client_configuration        = talos_machine_secrets.this.client_configuration
  machine_configuration_input = data.talos_machine_configuration.worker.machine_configuration
  node                        = var.node_initial_ips[each.key]

  config_patches = [
    yamlencode({
      machine = {
        network = {
          nameservers = var.nameservers
        }
        install = {
          disk  = var.install_disk
          image = "factory.talos.dev/installer/${var.schematic_id}:v${var.talos_version}"
        }
      }
    })
  ]
}

resource "talos_machine_bootstrap" "this" {
  depends_on           = [talos_machine_configuration_apply.controlplane]
  client_configuration = talos_machine_secrets.this.client_configuration
  node                 = var.node_initial_ips[var.controlplane_name]
}

resource "talos_cluster_kubeconfig" "this" {
  depends_on           = [talos_machine_bootstrap.this]
  client_configuration = talos_machine_secrets.this.client_configuration
  node                 = var.node_initial_ips[var.controlplane_name]
}
