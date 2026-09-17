resource "digitalocean_ssh_key" "this" {
  name       = "${var.droplet_name}-key"
  public_key = file(pathexpand(var.ssh_public_key_path))
}

resource "digitalocean_droplet" "this" {
  name     = var.droplet_name
  region   = var.region
  size     = var.droplet_size
  image    = var.image
  vpc_uuid = digitalocean_vpc.this.id
  ssh_keys = [digitalocean_ssh_key.this.fingerprint]

  tags = ["ollama", "cpu", "gemma4", var.droplet_name]

  # No digitalocean_volume - model weights are stored at Ollama's default
  # location, which the official install script already creates owned by
  # the "ollama" user it sets up. Introducing a custom OLLAMA_MODELS path
  # here would require an explicit chown step (see the other modules'
  # cloud-init for why) - staying with the default sidesteps that entirely,
  # matching ../cpu-qwen3-30b/'s CPU-only simplification.
  user_data = templatefile("${path.module}/cloud-init.yaml.tftpl", {
    ollama_model = var.ollama_model
  })
}
