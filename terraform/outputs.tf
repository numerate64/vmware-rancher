output "k3s_nodes" {
  description = "Addresses learned from VMware Tools after DHCP assignment. Use scripts/render-inventory.sh after apply."
  value = [for name in local.node_names : {
    name = name
    ip   = vsphere_virtual_machine.k3s_server[name].default_ip_address
  }]
}

output "ssh_user" { value = var.ssh_username }
