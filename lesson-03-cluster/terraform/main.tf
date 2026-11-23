locals {
  ssh_public_key = trimspace(file(pathexpand(var.ssh_public_key_path)))

  control_plane_hosts = {
    (var.control_plane_name) = {
      ansible_host = var.nodes[var.control_plane_name].ipv4
    }
  }

  worker_hosts = {
    for name, node in var.nodes : name => {
      ansible_host = node.ipv4
    }
    if name != var.control_plane_name
  }
}

resource "proxmox_virtual_environment_vm" "k8s_node" {
  for_each    = var.nodes
  name        = each.key
  description = "L1B Kubernetes training node managed by Terraform"
  node_name   = var.pve_node_name
  vm_id       = each.value.vm_id
  tags        = ["l1b", "kubernetes", "terraform"]

  clone {
    vm_id = var.cloud_init_template_id
    full  = true
  }

  cpu {
    cores = each.value.vcpu
  }

  memory {
    dedicated = each.value.memory_mb
  }

  agent {
    enabled = true
  }

  initialization {
    dns {
      servers = var.dns_servers
    }

    ip_config {
      ipv4 {
        address = "${each.value.ipv4}/${var.ipv4_prefix}"
        gateway = var.gateway
      }
    }

    user_account {
      username = var.vm_username
      keys     = [local.ssh_public_key]
    }
  }

  network_device {
    bridge = var.bridge
  }

  stop_on_destroy = true
}
