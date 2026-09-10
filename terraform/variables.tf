variable "vsphere_server" {
  type        = string
  description = "vCenter FQDN or IP address."
}
variable "vsphere_user" {
  type      = string
  sensitive = true
}
variable "vsphere_password" {
  type      = string
  sensitive = true
}
variable "vsphere_allow_unverified_ssl" {
  type    = bool
  default = false
}

variable "datacenter_name" {
  type        = string
  description = "Name of the vSphere datacenter containing the target resources."
}
variable "compute_cluster_name" {
  type        = string
  description = "Name of the vSphere compute cluster."
}
variable "datastore_name" {
  type        = string
  description = "Name of the datastore for the Rancher VM disks."
}
variable "network_name" {
  type        = string
  description = "Name of the vSphere port group connected to all K3s nodes and VIPs."
}
variable "vm_folder" {
  type        = string
  description = "Existing vSphere VM folder path for the Rancher nodes."
}
variable "content_library_name" {
  type        = string
  description = "Name of the vSphere Content Library containing the base image."
}
variable "content_library_item_name" {
  type        = string
  description = "Name of the Content Library item used as the VM source."
}
variable "content_library_item_type" {
  type        = string
  default     = "ovf"
  description = "Content Library item type: ovf or vm-template."
  validation {
    condition     = contains(["ovf", "vm-template"], var.content_library_item_type)
    error_message = "content_library_item_type must be ovf or vm-template."
  }
}
variable "customization_spec_name" {
  type        = string
  default     = ""
  description = "Name of the existing vSphere guest customization specification applied after each VM clone."
}
variable "customization_spec_timeout_minutes" {
  type        = number
  default     = 10
  description = "Minutes Terraform waits for vSphere guest customization to complete after cloning."
}

variable "cluster_name" {
  type        = string
  default     = "rancher-prod"
  description = "Prefix for the three VM names, for example rancher-prod-01 through rancher-prod-03."
}
variable "node_count" {
  type        = number
  default     = 3
  description = "K3s embedded-etcd quorum requires an odd number of server nodes; use 3 for this design."
  validation {
    condition     = var.node_count == 3
    error_message = "This production design currently supports exactly three K3s server nodes."
  }
}
variable "num_cpus" {
  type    = number
  default = 4
}
variable "memory_mb" {
  type    = number
  default = 16384
}
variable "disk_gb" {
  type    = number
  default = 100
}
variable "guest_id" {
  type    = string
  default = "ubuntu64Guest"
}
variable "scsi_type" {
  type    = string
  default = "pvscsi"
}

variable "ssh_username" {
  type        = string
  default     = "ansible"
  description = "Existing SSH user baked into the source image, used by Ansible after provisioning."
}
variable "cloud_init_enabled" {
  type    = bool
  default = true
}
variable "additional_cloud_init" {
  type    = string
  default = ""
}
