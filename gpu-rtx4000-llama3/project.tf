# Looks up the "doaivm" DigitalOcean Project (created once by the separate
# ../project root module - see its README) and assigns this module's droplet
# and model volume into it.
#
# VPCs are NOT assignable to a Project - the digitalocean_vpc resource exposes
# a `urn` attribute, but DO's project-resources API rejects it (confirmed via
# a live 400 response listing the allowed types, which doesn't include VPC).
# Only pass resource types DO actually accepts here.
data "digitalocean_project" "doaivm" {
  name = var.do_project_name
}

resource "digitalocean_project_resources" "this" {
  project = data.digitalocean_project.doaivm.id
  resources = [
    digitalocean_droplet.this.urn,
    digitalocean_volume.models.urn,
  ]
}
