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

Set `vsphere_user` and `vsphere_password` as sensitive variables in Terraform Cloud. The image supplies SSH access for the `ansible` user, so no SSH key material is required as a Terraform Cloud variable.
