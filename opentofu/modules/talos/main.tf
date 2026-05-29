resource "talos_machine_secrets" "this" {}

resource "talos_machine_configuration_apply" "this" {
  for_each = var.nodes

  client_configuration        = talos_machine_secrets.this.client_configuration
  machine_configuration_input = data.talos_machine_configuration.controlplane.machine_configuration
  node                        = each.value.public_ip
  endpoint                    = each.value.public_ip
  config_patches              = [local.node_patches[each.key]]
}

resource "talos_machine_bootstrap" "this" {
  depends_on           = [talos_machine_configuration_apply.this]
  client_configuration = talos_machine_secrets.this.client_configuration
  node                 = local.bootstrap_node_ip
  endpoint             = local.bootstrap_node_ip
}

resource "talos_cluster_kubeconfig" "this" {
  depends_on           = [talos_machine_bootstrap.this]
  client_configuration = talos_machine_secrets.this.client_configuration
  node                 = local.bootstrap_node_ip
  endpoint             = local.bootstrap_node_ip

  # Re-fetch the kubeconfig whenever the machine config is (re-)applied
  # (e.g. cluster_endpoint moves), so the server URL in the kubeconfig
  # stays in sync with the cluster. Must reference a managed resource —
  # data sources are not valid replace_triggered_by targets.
  lifecycle {
    replace_triggered_by = [talos_machine_configuration_apply.this]
  }
}
