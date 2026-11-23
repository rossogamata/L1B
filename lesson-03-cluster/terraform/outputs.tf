output "node_addresses" {
  description = "Static IPv4 addresses assigned to the cluster VMs."
  value = {
    for name, node in var.nodes : name => node.ipv4
  }
}

output "ansible_inventory" {
  description = "YAML inventory for the sibling Ansible project."
  value = yamlencode({
    all = {
      children = {
        k8s_cluster = {
          children = {
            k8s_control_plane = {
              hosts = local.control_plane_hosts
            }
            k8s_workers = {
              hosts = local.worker_hosts
            }
          }
          vars = {
            ansible_user                 = var.vm_username
            ansible_ssh_private_key_file = pathexpand(var.ssh_private_key_path)
            ansible_become               = true
          }
        }
      }
    }
  })
}
