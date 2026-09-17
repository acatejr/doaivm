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

  tags = ["ollama", "cpu", "litellm", var.droplet_name]

  # No digitalocean_volume/attachment - model weights are stored directly on
  # the boot disk (/opt/ollama-models). No ephemeral-disk workaround is
  # needed on non-GPU droplets.
  user_data = templatefile("${path.module}/cloud-init.yaml.tftpl", {
    ollama_model       = var.ollama_model
    ollama_num_ctx     = var.ollama_num_ctx
    ollama_num_thread  = var.ollama_num_thread
    litellm_master_key = var.litellm_master_key
  })
}
