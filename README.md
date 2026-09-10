# vmware-rancher

Local-first infrastructure-as-code for a three-node, embedded-etcd K3s cluster running Rancher HA on vSphere.

## Architecture

| Component | Choice |
|---|---|
| vCenter | `hci-vcenter.aqtech.dev` |
| Datacenter / cluster | `TierPoint` / `DELL` |
| Image | Content Library `aqtech-images` → OVF `aqtech-ubuntu24` |
| Nodes | 3 Ubuntu 24 VMs, default 4 vCPU / 16 GiB / 100 GiB |
| Network | DHCP for nodes on `VM Network` |
| Control-plane HA | kube-vip ARP virtual IP |
| Rancher | `aq-rancher.aqtech.dev`, internal CA certificate |

`vmware_asa_ds1` is the default datastore. Set `datastore_name` to `vmware_asa_ds2` or `vmware_asa_ds3` in your ignored `terraform.tfvars` if you want a different placement. Node VM addresses are DHCP leases; **the two kube-vip addresses must be excluded/reserved addresses**, not ordinary DHCP leases.

## Required decisions before applying

1. Reserve two unused addresses on `VM Network` and add internal DNS:
   - API VIP → `10.227.95.101` (K3s `:6443`)
   - ingress VIP → `10.227.96.101`, with `aq-rancher.aqtech.dev` pointing to it (HTTPS)
   - Both VIPs must be reachable at Layer 2 from the VM NIC used by kube-vip. These IPs appear to be in separate subnets, so confirm `VM Network` spans both ranges at Layer 2—or choose VIPs in the nodes' DHCP subnet. ARP-mode kube-vip cannot advertise across routed VLANs.
2. Confirm `aqtech-ubuntu24` has VMware Tools, cloud-init, and the VMware guestinfo datasource enabled. Also confirm its NIC interface name (the example assumes `ens192`).
3. Provide the existing AQTech private-CA root cert and key on the Ansible control host. They are temporarily copied to the bootstrap node to create the cert-manager issuer, then removed. Do not use an end-entity Rancher cert as the CA key.
4. Confirm the image’s SSH username. This repository is configured for `ansible`.

## Local test workflow

```bash
cd vmware-rancher
cp terraform/terraform.tfvars.example terraform/terraform.tfvars
# Set vSphere user/password as environment variables; do not write them to the tfvars file.
export TF_VAR_vsphere_user='your-vcenter-user'
export TF_VAR_vsphere_password='your-vcenter-password'

./scripts/preflight.sh
terraform -chdir=terraform init
terraform -chdir=terraform plan
terraform -chdir=terraform apply
./scripts/render-inventory.sh

cp ansible/inventory/group_vars/all.yml.example ansible/inventory/group_vars/all.yml
# Edit VIPs, NIC interface, and local CA file paths.
ansible-galaxy collection install -r ansible/requirements.yml
ansible-playbook -i ansible/inventory/hosts.yml ansible/playbooks/site.yml
```

Validate the endpoint with `curl --cacert <your-root-ca.crt> https://aq-rancher.aqtech.dev/ping` and sign in at `https://aq-rancher.aqtech.dev` using the Rancher bootstrap password shown by `kubectl -n cattle-system get secret bootstrap-secret -o go-template='{{.data.bootstrapPassword|base64decode}}'`.

## Terraform Cloud, after local acceptance

Keep the code as-is and add a `cloud` block only when you create the organization/workspace. Put `vsphere_user` and `vsphere_password` into Terraform Cloud as sensitive workspace variables. The image supplies SSH access, so the configuration is suitable for remote execution without a key-file dependency.

## Important operational notes

- Use snapshots/backups and test `terraform destroy` only against a disposable local test deployment.
- Review and deliberately pin/update K3s, kube-vip, cert-manager, ingress-nginx, and Rancher versions before a production apply.
- This is an embedded-etcd HA design; do not lose quorum by simultaneously rebooting or deleting two nodes.
