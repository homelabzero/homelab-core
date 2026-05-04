locals {
  talos_nodes = {
    "talos-cp-1" = {
      vm_id  = 110
      cores  = 2
      memory = 8192
    }
    "talos-worker-1" = {
      vm_id  = 111
      cores  = 4
      memory = 24576
    }
    "talos-worker-2" = {
      vm_id  = 112
      cores  = 4
      memory = 24576
    }
  }
}
