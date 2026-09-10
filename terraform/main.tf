data "vsphere_datacenter" "dc" { name = var.datacenter_name }
data "vsphere_compute_cluster" "cluster" {
  name          = var.compute_cluster_name
  datacenter_id = data.vsphere_datacenter.dc.id
}
data "vsphere_datastore" "datastore" {
  name          = var.datastore_name
  datacenter_id = data.vsphere_datacenter.dc.id
}
data "vsphere_network" "network" {
  name          = var.network_name
  datacenter_id = data.vsphere_datacenter.dc.id
}
data "vsphere_folder" "folder" { path = var.vm_folder }
data "vsphere_content_library" "library" { name = var.content_library_name }
data "vsphere_content_library_item" "ubuntu" {
  name       = var.content_library_item_name
  library_id = data.vsphere_content_library.library.id
  type       = "ovf"
}

locals {
  node_names = [for number in range(1, var.node_count + 1) : format("%s-%02d", var.cluster_name, number)]
}

resource "vsphere_virtual_machine" "k3s_server" {
  for_each = toset(local.node_names)

  name             = each.value
  folder           = data.vsphere_folder.folder.path
  resource_pool_id = data.vsphere_compute_cluster.cluster.resource_pool_id
  datastore_id     = data.vsphere_datastore.datastore.id
  num_cpus         = var.num_cpus
  memory           = var.memory_mb
  guest_id         = var.guest_id
  scsi_type        = var.scsi_type

  network_interface { network_id = data.vsphere_network.network.id }
  disk {
    label = "disk0"
    size  = var.disk_gb
  }

  clone { template_uuid = data.vsphere_content_library_item.ubuntu.id }

  extra_config = var.cloud_init_enabled ? {
    "guestinfo.metadata"          = base64encode("instance-id: ${each.value}\nlocal-hostname: ${each.value}\n")
    "guestinfo.metadata.encoding" = "base64"
    "guestinfo.userdata" = base64encode(templatefile("${path.module}/templates/cloud-init.yaml.tftpl", {
      hostname              = each.value
      ssh_username          = var.ssh_username
      additional_cloud_init = var.additional_cloud_init
    }))
    "guestinfo.userdata.encoding" = "base64"
  } : {}

  wait_for_guest_net_timeout = 10
  wait_for_guest_ip_timeout  = 10
}
