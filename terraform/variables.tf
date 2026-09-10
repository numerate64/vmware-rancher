variable "vsphere_server" {
  type    = string
  default = "hci-vcenter.aqtech.dev"
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
  type    = string
  default = "TierPoint"
}
variable "compute_cluster_name" {
  type    = string
  default = "DELL"
}
variable "datastore_name" {
  type    = string
  default = "vmware_asa_ds1"
}
variable "network_name" {
  type    = string
  default = "VM Network"
}
variable "vm_folder" {
  type    = string
  default = "Rancher"
}
variable "content_library_name" {
  type    = string
  default = "aqtech-images"
}
variable "content_library_item_name" {
  type    = string
  default = "aqtech-ubuntu24"
}

variable "cluster_name" {
  type    = string
  default = "rancher-prod"
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
  type    = string
  default = "ansible"
}
variable "ssh_public_key_path" {
  type        = string
  description = "Path to the public key installed by cloud-init. Never point this at a private key."
}
variable "cloud_init_enabled" {
  type    = bool
  default = true
}
variable "additional_cloud_init" {
  type    = string
  default = ""
}
