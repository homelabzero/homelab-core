locals {
  # Static node info — keyed by name. Used to generate machine configs and WG
  # keys; does not depend on hetzner outputs so the dep graph stays acyclic.
  static_nodes = merge(
    { for k, v in var.controlplane_nodes : k => merge(v, { role = "controlplane" }) },
    { for k, v in var.worker_nodes : k => {
      role           = "worker"
      private_ip     = v.private_ip
      wireguard_addr = v.wireguard_addr
      install_disk   = v.install_disk
    } },
  )

  # Strip CIDR mask for talosctl endpoints
  wireguard_addr_only = {
    for k, n in local.static_nodes : k => split("/", n.wireguard_addr)[0]
  }

  vswitch_prefix  = split("/", var.vswitch_subnet_cidr)[1]
  vswitch_gateway = cidrhost(var.vswitch_subnet_cidr, 1)

  # WireGuard interface stanza shared by both roles, parameterised per node.
  # Only peer is the laptop — node-to-node traffic uses the Hetzner private
  # network (encrypted by Cilium WireGuard), not host-level WireGuard.
  wg0_interface = { for name, n in local.static_nodes : name => {
    interface = "wg0"
    addresses = [n.wireguard_addr]
    mtu       = 1420
    wireguard = {
      privateKey = var.wireguard_node_private_keys[name]
      listenPort = 51820
      peers = [{
        publicKey  = var.wireguard_clients.public_key
        allowedIPs = [var.wireguard_clients.address]
      }]
    }
  } }

  # Network patch for control planes: eth1 = private (DHCP, MTU 1400), wg0
  cp_network = { for name, n in var.controlplane_nodes : name => {
    nameservers = var.nameservers
    interfaces = [
      {
        interface = "eth1"
        dhcp      = true
        mtu       = var.private_mtu
        routes = [{
          network = var.vswitch_subnet_cidr
          gateway = cidrhost(var.cloud_subnet_cidr, 1)
        }]
      },
      local.wg0_interface[name],
    ]
  } }

  # Network patch for workers: <nic> = public DHCP, <nic>.<vlan> = static IP +
  # route to the cloud subnet via the vSwitch gateway, MTU 1400. Plus wg0.
  # network_interface must match the actual NIC name on the bare-metal host
  # (e.g. enp41s0 on Hetzner dedicated servers, eth0 on cloud/VMs).
  worker_network = { for name, n in var.worker_nodes : name => {
    nameservers = var.nameservers
    interfaces = [
      {
        interface = n.network_interface
        dhcp      = true
        vlans = [{
          vlanId    = n.vlan_id
          mtu       = var.private_mtu
          addresses = ["${n.private_ip}/${local.vswitch_prefix}"]
          routes = [{
            network = var.network_cidr
            gateway = local.vswitch_gateway
          }]
        }]
      },
      local.wg0_interface[name],
    ]
  } }

  # Per-node install disk: each node may override the module default
  # (cloud CPs install to /dev/sda, the bare-metal worker to /dev/nvme0n1).
  node_install_disk = {
    for name, n in local.static_nodes :
    name => coalesce(try(n.install_disk, null), var.install_disk)
  }

  # Common machine-section block, parameterised by node so each node gets the
  # right install disk.
  base_machine = { for name, _ in local.static_nodes : name => {
    install = {
      disk  = local.node_install_disk[name]
      image = "ghcr.io/siderolabs/installer:v${var.talos_version}"
    }
    time = {
      servers = ["ntp1.hetzner.de", "ntp2.hetzner.com", "ntp3.hetzner.net"]
    }
    # Explicitly enable KubePrism on every node — kubelet uses localhost:7445
    # to reach the API server, KubePrism load-balances across CP API servers.
    features = {
      kubePrism = {
        enabled = true
        port    = 7445
      }
    }
  } }

  # CP-only cluster-section overrides (Cilium replaces kube-proxy + CNI; etcd
  # peer traffic pinned to the cloud subnet).
  cp_cluster = {
    network = { cni = { name = "none" } }
    proxy   = { disabled = true }
    apiServer = {
      extraArgs = {
        "anonymous-auth" = "false"
      }
      admissionControl = [{
        name = "PodSecurity"
        configuration = {
          apiVersion = "pod-security.admission.config.k8s.io/v1beta1"
          kind       = "PodSecurityConfiguration"
          exemptions = {
            namespaces = ["openebs"]
          }
        }
      }]
    }
    etcd = {
      advertisedSubnets = [var.cloud_subnet_cidr]
    }
  }

  cp_patches = { for name in keys(var.controlplane_nodes) : name =>
    yamlencode({
      machine = merge(local.base_machine[name], { network = local.cp_network[name] })
      cluster = local.cp_cluster
    })
  }

  openebs_worker_machine = {
    sysctls = {
      "vm.nr_hugepages" = "1024"
    }
    nodeLabels = {
      "openebs.io/engine" = "mayastor"
    }
    kubelet = {
      extraMounts = [{
        destination = "/var/local"
        type        = "bind"
        source      = "/var/local"
        options     = ["bind", "rshared", "rw"]
      }]
    }
  }

  worker_patches = { for name in keys(var.worker_nodes) : name =>
    yamlencode({
      machine = merge(local.base_machine[name], { network = local.worker_network[name] }, local.openebs_worker_machine)
    })
  }

  # Bootstrap target: alphabetically first CP, via its public IP (computed
  # output from the hetzner module). KubePrism handles internal routing post-
  # bootstrap.
  bootstrap_node_name = sort(keys(var.controlplane_nodes))[0]
  bootstrap_node_ip   = var.controlplane_public_ips[local.bootstrap_node_name]

  # Laptop wg0.conf peers. Each peer's AllowedIPs includes its WG /32 + its
  # public IP /32 (kubectl traffic going to the API hostname tunnels via WG).
  # The bootstrap CP additionally carries the cluster CIDRs so in-cluster IPs
  # route into the tunnel.
  all_public_ips = merge(
    var.controlplane_public_ips,
    { for k, v in var.worker_nodes : k => v.public_ip },
  )

  laptop_peers = [
    for name, n in local.static_nodes : {
      name       = name
      role       = n.role
      public_key = var.wireguard_node_public_keys[name]
      endpoint   = "${local.all_public_ips[name]}:51820"
      allowed_ips = concat(
        ["${local.wireguard_addr_only[name]}/32"],
        ["${local.all_public_ips[name]}/32"],
        ["${local.static_nodes[name].private_ip}/32"],
        name == local.bootstrap_node_name ? [
          var.network_cidr,
          var.pod_cidr,
          var.service_cidr,
          var.lb_cidr,
        ] : []
      )
    }
  ]
}
