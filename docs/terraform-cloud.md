# Terraform Cloud handoff

After the local deployment is accepted, create a Terraform Cloud workspace with the working directory set to `terraform`. Add the organization-specific `cloud` block only then:

```hcl
terraform {
  cloud {
    organization = "YOUR_ORGANIZATION"
    workspaces { name = "vmware-rancher-production" }
  }
}
```

Set `vsphere_user` and `vsphere_password` as sensitive variables in Terraform Cloud. Do not store a private SSH key there. Because the current design reads a public-key file during Terraform execution, convert `ssh_public_key_path` to a plain non-sensitive `ssh_public_key` variable for the remote workspace, or use a workspace-safe public-key artifact.
