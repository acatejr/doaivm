resource "digitalocean_vpc" "this" {
  name   = "${var.droplet_name}-vpc"
  region = var.region
}

resource "digitalocean_firewall" "this" {
  name = "${var.droplet_name}-fw"

  droplet_ids = [digitalocean_droplet.this.id]

  inbound_rule {
    protocol         = "tcp"
    port_range       = "22"
    source_addresses = var.ssh_allowed_ips
  }

  # Temporary, explicit exception to this repo's private-only Ollama posture
  # (see CLAUDE.md) - the API is bound to 0.0.0.0 on the droplet and this rule
  # exposes it to the whole internet, unauthenticated. Requested directly by
  # the user for devaidrop specifically, "for now" - not a pattern to carry
  # into any other module without being asked again.
  inbound_rule {
    protocol         = "tcp"
    port_range       = "11434"
    source_addresses = ["0.0.0.0/0"]
  }

  outbound_rule {
    protocol              = "tcp"
    port_range            = "1-65535"
    destination_addresses = ["0.0.0.0/0", "::/0"]
  }

  outbound_rule {
    protocol              = "udp"
    port_range            = "1-65535"
    destination_addresses = ["0.0.0.0/0", "::/0"]
  }

  outbound_rule {
    protocol              = "icmp"
    destination_addresses = ["0.0.0.0/0", "::/0"]
  }
}
