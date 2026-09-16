resource "digitalocean_ssh_key" "default" {
  name       = "${var.droplet_name}-key"
  public_key = file(pathexpand(var.ssh_public_key_path))
}

# Persistent block storage for pulled Ollama models. Kept separate from the
# droplet's lifecycle on purpose: destroying the droplet (see scripts/down.sh)
# does NOT destroy this volume, so the model is still there -- no re-download --
# next time scripts/up.sh recreates the droplet. Costs ~$0.10/GB-month whether
# or not a droplet is attached to it (see README for the full cost math).
resource "digitalocean_volume" "ollama_models" {
  region                  = var.region
  name                    = "${var.droplet_name}-models"
  size                    = var.volume_size_gb
  initial_filesystem_type = "ext4"
  description             = "Persists pulled Ollama models across droplet destroy/recreate cycles"
}

resource "digitalocean_droplet" "ollama" {
  name     = var.droplet_name
  region   = var.region
  size     = var.droplet_size
  image    = var.image
  ssh_keys = [digitalocean_ssh_key.default.fingerprint]
  tags     = ["ollama", "qwen2-5-coder"]

  # Billed by the second while it exists (droplet-hours), regardless of CPU
  # load -- this is what scripts/down.sh removes to stop the meter.
  user_data = templatefile("${path.module}/templates/bootstrap.sh.tftpl", {
    model_name = var.model_name
  })

  volume_ids = [digitalocean_volume.ollama_models.id]
}

resource "digitalocean_firewall" "ollama" {
  name        = "${var.droplet_name}-fw"
  droplet_ids = [digitalocean_droplet.ollama.id]

  inbound_rule {
    protocol         = "tcp"
    port_range       = "22"
    source_addresses = var.ssh_allowed_ips
  }

  # Only opens 11434 to the internet if you explicitly set ollama_allowed_ips.
  # Default posture: reach the API only via the SSH tunnel in the outputs.
  dynamic "inbound_rule" {
    for_each = length(var.ollama_allowed_ips) > 0 ? [1] : []
    content {
      protocol         = "tcp"
      port_range       = "11434"
      source_addresses = var.ollama_allowed_ips
    }
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
