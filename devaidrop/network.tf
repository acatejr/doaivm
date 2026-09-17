resource "digitalocean_vpc" "this" {
  name   = "${var.droplet_name}-vpc"
  region = var.region
}

resource "digitalocean_firewall" "this" {
  name = "${var.droplet_name}-fw"

  droplet_ids = [digitalocean_droplet.this.id]

  # No inbound rule for 11434 (Ollama) - it is bound to 127.0.0.1 on the
  # droplet and is only ever reached via SSH tunnel. Do not add a public
  # inbound rule for it here.
  inbound_rule {
    protocol         = "tcp"
    port_range       = "22"
    source_addresses = var.ssh_allowed_ips
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
