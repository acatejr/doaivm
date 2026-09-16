# Project Root Module — "doaivm" DigitalOcean Project

Creates the DigitalOcean Project named `doaivm` that all four VM modules
(`gpu-qwen3-30b/`, `cpu-qwen3-30b/`, `gpu-rtx4000/`, `gpu-rtx4000-llama3/`) assign
their droplets into. This is the **only** module that creates the project itself —
the others look it up by name and assign their own resources into it via
`digitalocean_project_resources`.

## Why a separate module

The four VM modules each keep fully independent Terraform state, and DigitalOcean
Project names must be unique per account. If more than one of those states tried to
`create` a project named `doaivm`, only the first apply would succeed and the rest
would fail with a name-conflict error. Centralizing project creation here avoids
that, while keeping the VM modules' droplets/state independent of each other.

## Usage

**Apply this module before the first apply of any of the four VM modules** — they
each do a `data "digitalocean_project" { name = "doaivm" }` lookup that fails if the
project doesn't exist yet.

```sh
cp terraform.tfvars.example terraform.tfvars
# edit terraform.tfvars: set do_token if not using an env var

export TF_VAR_do_token="$DIGITALOCEAN_TOKEN"   # or set do_token in terraform.tfvars

terraform init
terraform validate
terraform plan
terraform apply
```

After this succeeds, apply any of the VM modules as usual — their droplets (and
volumes/VPCs, where applicable) will show up grouped under the `doaivm` project in
the DigitalOcean control panel.

## Teardown

Destroy this only after all four VM modules have been destroyed first (a
non-default DigitalOcean Project can't be deleted while it still has resources
assigned to it):

```sh
terraform destroy
```
