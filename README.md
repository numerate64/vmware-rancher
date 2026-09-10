# vmware-rancher

Local-first infrastructure-as-code for a three-node, embedded-etcd K3s cluster running Rancher HA on vSphere.

## Architecture

| Component | Choice |
|---|---|
| vCenter | Customer-supplied vCenter |
| Datacenter / cluster | Customer-supplied placement targets |
| Image | Customer Content Library OVF or VM template |
| Guest customization | Optional existing vSphere customization specification |
| Nodes | 3 Ubuntu 24 VMs, default 4 vCPU / 16 GiB / 100 GiB |
| Network | DHCP for nodes on a customer port group |
| Control-plane HA | kube-vip ARP virtual IP |
| Rancher | Customer FQDN, internal CA certificate |

Node VM addresses are DHCP leases; **the two kube-vip addresses must be reserved/excluded addresses**, not ordinary DHCP leases.

For VM storage, set exactly one of `datastore_name` (a specific datastore) or `datastore_cluster_name` (a vSphere datastore cluster using Storage DRS) in the ignored `terraform/terraform.tfvars` file.

When configured, Terraform applies the named vSphere guest customization specification immediately after each clone. Customization specifications run during cloning; they do not retroactively customize existing VMs.

## Required decisions before applying

1. Reserve two unused addresses on the node port group: an API VIP for K3s `:6443` and an ingress VIP for Rancher `:80/443`. Both must be reachable at Layer 2 from the node NIC; ARP-mode kube-vip cannot advertise across routed VLANs.
2. Create internal DNS from the Rancher FQDN to the ingress VIP.
3. Confirm the image has VMware Tools, Python 3, passwordless sudo for the configured SSH user, and—if enabled—cloud-init with VMware guestinfo.
4. Provide a CA root certificate and key on the Ansible control host. The playbook issues the Rancher certificate and does not retain the CA private key in Kubernetes.

See [the customer configuration guide](docs/customer-configuration.md) for every customer-owned variable and image prerequisite.

## Ansible control-host prerequisites

Use a supported Linux control host with at least 2 vCPU, 4 GiB RAM, and 20 GiB free disk. Ubuntu 24.04 LTS is the tested baseline; another current Linux distribution is suitable if it provides the tools below.

### Required software

- Terraform `>= 1.6.0`
- Ansible with `ansible-playbook` and `ansible-galaxy`
- `jq`, OpenSSH client, Git, `curl`, `ca-certificates`, and `openssl`
- Python 3 (required by Ansible and common collection dependencies)

For Ubuntu 24.04, run the included installer from the repository root:

```bash
./scripts/install-ubuntu-prerequisites.sh
```

It installs Terraform from [HashiCorp's official Linux APT repository](https://developer.hashicorp.com/terraform/install), plus Ansible and the required Ubuntu packages. It requires `sudo`, supports Ubuntu only, and makes no vSphere or Rancher changes.

### Access, credentials, and network

- The local Linux user needs `sudo` only to install the prerequisite packages and trust a private vCenter CA. It does **not** need root to run Terraform or Ansible.
- It must reach vCenter on TCP `443` and each created VM on TCP `22`.
- It needs outbound HTTPS access to Terraform Registry/provider downloads, Ansible Galaxy, and GitHub when installing dependencies. The K3s nodes also need outbound HTTPS access to K3s, Helm-chart, and container-image sources. This repository does not currently provide an air-gapped mirror workflow.
- Provide vCenter credentials as `TF_VAR_vsphere_user` and `TF_VAR_vsphere_password`, or later as sensitive Terraform Cloud variables. Never put them in Git or `terraform.tfvars`.
- Store the private CA certificate and key only on the control host, at the paths configured in `ansible/inventory/group_vars/all.yml`. Restrict the key with `chmod 600 <path-to-ca-key>`.
- The image's matching SSH private key remains on the control host, outside this repository. It must authenticate as `ssh_username`; that account needs passwordless `sudo` on each Rancher node.

The supplied SSH configuration uses `StrictHostKeyChecking=accept-new`: new VM host keys are recorded automatically, while changed known keys still fail safely. Install the required Ansible collection before the first deployment:

```bash
ansible-galaxy collection install -r ansible/requirements.yml
```

### Local lab CA

For a disposable local test, create a dedicated CA on the Ansible control host. This is not a replacement for the organization's production PKI. Keep the key outside the repository and distribute the resulting certificate to clients that need to trust Rancher.

```bash
install -d -m 700 ~/.config/rancher
openssl genrsa -out ~/.config/rancher/rancher-root-ca.key 4096
openssl req -x509 -new -sha256 -days 3650 \
  -key ~/.config/rancher/rancher-root-ca.key \
  -out ~/.config/rancher/rancher-root-ca.crt \
  -subj "/CN=Rancher Lab CA"
chmod 600 ~/.config/rancher/rancher-root-ca.key
```

The playbook creates `cattle-system` before creating its TLS secrets, then reads these files, temporarily copies them to the bootstrap node to issue the Rancher ingress certificate, creates only the required Kubernetes TLS/CA secrets, assigns the Rancher Ingress to the `nginx` IngressClass, and removes the temporary node copies. The CA private key is not retained in Kubernetes.

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
# Edit VIPs, network prefix, FQDN, NIC interface, and local CA file paths.
ansible-galaxy collection install -r ansible/requirements.yml
ansible-playbook -i ansible/inventory/hosts.yml ansible/playbooks/site.yml
```

The included `ansible.cfg` uses SSH `StrictHostKeyChecking=accept-new`: each freshly cloned VM's first host key is automatically recorded in `~/.ssh/known_hosts`, while a subsequently changed key still stops the run for review. This avoids interactive prompts during first deployment without globally disabling SSH host-key verification.

The K3s version is pinned to `v1.31.6+k3s1`, which is compatible with the Rancher `2.10.2` chart used here. Do not let an existing cluster silently remain on a newer K3s release: reinstall the disposable test cluster at the pinned version before installing Rancher.

### vCenter TLS

The Terraform provider verifies the vCenter certificate by default. Add the customer's vCenter CA certificate to the operating system trust store on the Terraform control host before running `plan`. For a short-lived lab test only, set `vsphere_allow_unverified_ssl = true` in the ignored `terraform/terraform.tfvars`; do not use that setting for a production deployment.

Validate the endpoint with `curl --noproxy '*' --cacert <your-root-ca.crt> --resolve <rancher-fqdn>:443:<ingress-vip> https://<rancher-fqdn>/ping`; it should return `pong`. The `--resolve` option permits validation before DNS has been published. Sign in at `https://<rancher-fqdn>` using the Rancher bootstrap password shown by `kubectl -n cattle-system get secret bootstrap-secret -o go-template='{{.data.bootstrapPassword|base64decode}}'`.

## Terraform Cloud, after local acceptance

Keep the code as-is and add a `cloud` block only when you create the organization/workspace. Put `vsphere_user` and `vsphere_password` into Terraform Cloud as sensitive workspace variables. The image supplies SSH access, so the configuration is suitable for remote execution without a key-file dependency.

## Important operational notes

- Use snapshots/backups and test `terraform destroy` only against a disposable local test deployment.
- Review and deliberately pin/update K3s, kube-vip, cert-manager, ingress-nginx, and Rancher versions before a production apply.
- This is an embedded-etcd HA design; do not lose quorum by simultaneously rebooting or deleting two nodes.
