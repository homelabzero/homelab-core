data "talos_machine_configuration" "controlplane" {
  cluster_name       = var.cluster_name
  cluster_endpoint   = "https://${var.cluster_endpoint}:6443"
  machine_type       = "controlplane"
  machine_secrets    = talos_machine_secrets.this.machine_secrets
  talos_version      = "v${var.talos_version}"
  kubernetes_version = var.kubernetes_version
}

data "http" "image_factory_schematic" {
  url    = "https://factory.talos.dev/schematics"
  method = "POST"
  request_headers = {
    "Content-Type" = "application/yaml"
  }
  request_body = <<-EOT
    customization:
      systemExtensions:
        officialExtensions:
          - siderolabs/netbird
  EOT
}
