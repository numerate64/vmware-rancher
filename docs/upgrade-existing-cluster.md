# Upgrade an existing K3s and Rancher cluster

This runbook upgrades the cluster deployed by this repository from K3s
`v1.31.6+k3s1` and Rancher `2.10.2` to K3s `v1.36.4+k3s1` and Rancher
`2.15.1`.

It is intentionally a **staged, manual procedure**. Rancher supports a minor
upgrade only from the latest patch of one minor to the latest patch of the next
minor. K3s server nodes must be upgraded one at a time. Do not change the
version pins in `all.yml` and rerun `site.yml` to perform this upgrade.

The version numbers below were validated against the Rancher and K3s release
lists on 2026-09-10. Before starting, refresh the Helm repository and compare
the available patch releases; use a later patch in the same minor only after
reviewing its release notes.

## 1. Prepare and back up

Run these commands on the Ansible control host from the repository root. They
use the first server as the Kubernetes administration host.

```bash
export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
ansible -i ansible/inventory/hosts.yml vm-rancher-01 -b -m ansible.builtin.shell -a '
  set -e
  /usr/local/bin/k3s etcd-snapshot save --name pre-upgrade
  /usr/local/bin/k3s etcd-snapshot ls
  /usr/local/bin/k3s kubectl get nodes -o wide
  /usr/local/bin/k3s kubectl get pods -A
  helm version --short
  helm get values rancher -n cattle-system -o yaml > /root/rancher-values-pre-upgrade.yaml
  helm repo update
'
```

Copy `/root/rancher-values-pre-upgrade.yaml` and the etcd snapshot off the
cluster according to the backup policy. Rancher 2.12 and later requires Helm
3.18 or later; if `helm version --short` reports an older client, update Helm
on node 1 before the Rancher 2.12 step. Schedule a maintenance window and
verify that all three nodes are `Ready` before every stage.

## 2. Upgrade Rancher one minor at a time

On node 1, run the following command for **each** row, in order. Wait for the
Rancher rollout to finish successfully before moving to the next row.

| Stage | Rancher chart version |
|---|---|
| Patch current minor | `2.10.12` |
| Next minor | `2.11.17` |
| Next minor | `2.12.13` |
| Next minor | `2.13.9` |
| Next minor | `2.14.5` |
| Target minor | `2.15.1` |

For example, replace `RANCHER_VERSION` with the row's value and run:

```bash
ansible -i ansible/inventory/hosts.yml vm-rancher-01 -b -m ansible.builtin.shell -a '
  set -e
  export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
  helm upgrade rancher rancher-stable/rancher \
    --namespace cattle-system \
    --version RANCHER_VERSION \
    --reuse-values --wait --timeout 15m
  /usr/local/bin/k3s kubectl -n cattle-system rollout status deployment/rancher --timeout=15m
  helm list -n cattle-system
'
```

Do **not** use `rancher_allow_version_change=true` to skip these stages. That
variable exists only to make a consciously reviewed, single-minor Ansible
change possible; it does not make multi-minor jumps supported.

## 3. Upgrade K3s one Kubernetes minor at a time

After Rancher reaches `2.11.17`, upgrade K3s to `v1.32.13+k3s1`. After each
subsequent Rancher minor, upgrade K3s as follows:

| Rancher completed | Then upgrade K3s to |
|---|---|
| `2.11.17` | `v1.32.13+k3s1` |
| `2.12.13` | `v1.33.13+k3s2` |
| `2.13.9` | `v1.34.11+k3s1` |
| `2.14.5` | `v1.35.8+k3s1` |
| `2.15.1` | `v1.36.4+k3s1` |

For each K3s version, upgrade **one server at a time** in this order:
`vm-rancher-02`, `vm-rancher-03`, then `vm-rancher-01`. Wait until the node is
`Ready` before moving to the next server. This preserves embedded-etcd quorum
and leaves the initial kube-vip leader until last.

Replace `K3S_VERSION` below with the value from the table, and run the command
once per server in the stated order:

```bash
ansible -i ansible/inventory/hosts.yml SERVER_NAME -b -m ansible.builtin.shell -a '
  set -euo pipefail
  curl -sfL https://get.k3s.io | INSTALL_K3S_VERSION=K3S_VERSION sh -
'

ansible -i ansible/inventory/hosts.yml vm-rancher-01 -b -m ansible.builtin.shell -a '
  /usr/local/bin/k3s kubectl wait --for=condition=Ready node/SERVER_NAME --timeout=10m
  /usr/local/bin/k3s kubectl get nodes -o wide
'
```

The K3s installer retains `/etc/rancher/k3s/config.yaml`; do not pass new
server arguments during these upgrades. K3s notes that cordon/drain is optional
for a normal server restart. Do not drain more than one embedded-etcd server at
a time.

## 4. Finalize

After all stages, verify the intended versions and Rancher endpoint:

```bash
ansible -i ansible/inventory/hosts.yml vm-rancher-01 -b -m ansible.builtin.shell -a '
  set -e
  /usr/local/bin/k3s --version
  /usr/local/bin/k3s kubectl get nodes -o wide
  helm list -n cattle-system
  /usr/local/bin/k3s kubectl -n cattle-system rollout status deployment/rancher --timeout=15m
'

curl --noproxy '*' --cacert /path/to/root-ca.crt \
  --resolve rancher.example.internal:443:INGRESS_VIP \
  https://rancher.example.internal/ping
```

The final `curl` must return `pong`. Update `ansible/inventory/group_vars/all.yml`
to `k3s_version: "v1.36.4+k3s1"` only after the cluster has reached that
version, so its declared configuration matches the running environment.

## References

- [Rancher supported upgrade path](https://ranchermanager.docs.rancher.com/getting-started/installation-and-upgrade/install-upgrade-on-a-kubernetes-cluster/upgrades)
- [K3s manual upgrades](https://docs.k3s.io/upgrades/manual)
