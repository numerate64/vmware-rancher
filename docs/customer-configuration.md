# Customer configuration guide

This repository has two customer-owned, ignored configuration files. Start each deployment by copying their tracked examples:

```bash
cp terraform/terraform.tfvars.example terraform/terraform.tfvars
cp ansible/inventory/group_vars/all.yml.example ansible/inventory/group_vars/all.yml
```

Do not commit either resulting file. The generated `ansible/inventory/hosts.yml` is also ignored and is created after Terraform applies successfully.

## 1. Terraform: vSphere and VM settings

Edit `terraform/terraform.tfvars`.

| Setting | Customer supplies | Notes |
|---|---|---|
| `vsphere_server` | vCenter FQDN/IP | The provider validates TLS by default. |
| `datacenter_name`, `compute_cluster_name` | Placement targets | Names must exactly match vSphere. |
| `datastore_name` **or** `datastore_cluster_name` | Storage placement | Set exactly one. Use `datastore_cluster_name` when Storage DRS should select a member datastore. |
| `network_name` | Node port group | Every node and both kube-vip addresses must be on this Layer-2 network. |
| `vm_folder` | Existing VM folder | Terraform does not create it. |
| `content_library_name`, `content_library_item_name`, `content_library_item_type` | Content Library source | Use `ovf` or `vm-template`. |
| `customization_spec_name` | Optional vSphere customization specification | Leave blank to skip it. A customization specification runs only while cloning. |
| `cluster_name`, `num_cpus`, `memory_mb`, `disk_gb` | VM naming and sizing | Exactly three K3s servers are deployed. |
| `ssh_username` | Image's existing SSH user | It must have passwordless `sudo` for Ansible. |
| `cloud_init_enabled` | Image capability | Enable only when VMware guestinfo/cloud-init is configured in the image. |

Set credentials outside the file:

```bash
export TF_VAR_vsphere_user='your-vcenter-user'
export TF_VAR_vsphere_password='your-vcenter-password'
```

For a short-lived lab with an untrusted vCenter certificate, set `vsphere_allow_unverified_ssl = true` in the ignored tfvars file. Install the vCenter CA into the control host trust store instead for normal and production use.

## 2. Ansible: K3s, VIP, DNS, and CA settings

Edit `ansible/inventory/group_vars/all.yml`.

| Setting | Customer supplies | Notes |
|---|---|---|
| `kube_vip_api_address` | Reserved K3s API virtual IP | Port `6443`; exclude it from DHCP. |
| `rancher_ingress_address` | Reserved Rancher ingress virtual IP | Ports `80/443`; exclude it from DHCP. |
| `kube_vip_subnet` / `kube_vip_cidr` | Prefix of the node network | They represent the same prefix: `/24` and `24`, for example. |
| `rancher_hostname` | Rancher FQDN | Create DNS pointing this name to `rancher_ingress_address`. |
| `kube_vip_interface` | Node NIC name | Examples: `ens192`, `eth0`. Verify with `ip -br address` on the image. |
| `k3s_version` | Supported K3s release | Keep it compatible with the pinned Rancher chart. |
| `internal_ca_cert_path` / `internal_ca_key_path` | Local CA root certificate and key paths | The key stays on the Ansible control host and is never committed. |

The repository uses SSH `StrictHostKeyChecking=accept-new`. First-contact host keys are added automatically; a changed known key remains a hard failure.

## 3. Image prerequisites

The source image must provide:

- VMware Tools or open-vm-tools so Terraform can obtain DHCP addresses.
- Ubuntu-compatible Linux with Python 3, `sudo`, and the configured SSH user.
- Passwordless sudo for that SSH user.
- If `cloud_init_enabled = true`, cloud-init with the VMware guestinfo datasource.
- An existing SSH public key for the configured user. Do not add private keys to Terraform, Ansible, or Git.

## 4. Deploy and validate

```bash
./scripts/preflight.sh
terraform -chdir=terraform init
terraform -chdir=terraform plan
terraform -chdir=terraform apply
./scripts/render-inventory.sh
ansible-galaxy collection install -r ansible/requirements.yml
ansible-playbook -i ansible/inventory/hosts.yml ansible/playbooks/site.yml
```

After apply, `render-inventory.sh` reads both DHCP addresses and `ssh_username` from Terraform state. Do not hand-edit the generated inventory.

Validate Rancher before DNS is live:

```bash
curl --noproxy '*' --cacert /path/to/root-ca.crt \
  --resolve rancher.example.internal:443:192.0.2.102 \
  https://rancher.example.internal/ping
```

It should return `pong`. Replace the hostname, VIP, and CA path with customer values.
