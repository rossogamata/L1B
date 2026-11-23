variable "proxmox_endpoint" {
  description = "Base URL of the Proxmox VE API, including https:// and port 8006."
  type        = string

  validation {
    condition     = startswith(var.proxmox_endpoint, "https://")
    error_message = "Use an HTTPS Proxmox endpoint."
  }
}

variable "pve_node_name" {
  description = "Proxmox node that contains the cloud-init template and will host the VMs."
  type        = string
}

variable "cloud_init_template_id" {
  description = "ID of the prepared Ubuntu 24.04 cloud-init VM template."
  type        = number
}

variable "bridge" {
  description = "Proxmox Linux bridge connected to the lab network."
  type        = string
}

variable "gateway" {
  description = "IPv4 gateway for the VM network."
  type        = string
}

variable "dns_servers" {
  description = "DNS resolver addresses reachable from the VM network."
  type        = list(string)
}

variable "ipv4_prefix" {
  description = "Prefix length for VM addresses, for example 24."
  type        = number

  validation {
    condition     = var.ipv4_prefix >= 1 && var.ipv4_prefix <= 32
    error_message = "ipv4_prefix must be between 1 and 32."
  }
}

variable "vm_username" {
  description = "Cloud-init account created on every VM."
  type        = string
  default     = "ubuntu"
}

variable "ssh_public_key_path" {
  description = "Path to the public SSH key on the Terraform operator's machine."
  type        = string
  default     = "~/.ssh/id_ed25519.pub"
}

variable "ssh_private_key_path" {
  description = "Absolute or home-relative path to the matching private key, written into the generated Ansible inventory."
  type        = string
  default     = "~/.ssh/id_ed25519"
}

variable "control_plane_name" {
  description = "Key in nodes map that identifies the Kubernetes control-plane VM."
  type        = string

  validation {
    condition     = contains(keys(var.nodes), var.control_plane_name)
    error_message = "control_plane_name must match a key in nodes."
  }
}

variable "nodes" {
  description = "VM definitions. Use unique VM IDs and reserved static IPs from the lab network."
  type = map(object({
    vm_id     = number
    ipv4      = string
    vcpu      = number
    memory_mb = number
  }))

  validation {
    condition     = length(var.nodes) >= 2
    error_message = "Define at least one control-plane VM and one worker VM."
  }
}
