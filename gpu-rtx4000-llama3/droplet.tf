resource "digitalocean_ssh_key" "this" {
  name       = "${var.droplet_name}-key"
  public_key = file(pathexpand(var.ssh_public_key_path))
}

resource "digitalocean_volume" "models" {
  region                   = var.region
  name                     = "${var.droplet_name}-models"
  size                     = var.model_volume_size_gb
  initial_filesystem_type  = "ext4"
  initial_filesystem_label = "ollama_models"
  description              = "Persistent storage for Ollama model weights - survives droplet re-provisioning."
}

resource "digitalocean_droplet" "this" {
  name     = var.droplet_name
  region   = var.region
  size     = var.droplet_size
  image    = var.image
  vpc_uuid = digitalocean_vpc.this.id
  ssh_keys = [digitalocean_ssh_key.this.fingerprint]

  tags = ["ollama", "gpu", "rtx4000ada", "llama3", var.droplet_name]

  user_data = templatefile("${path.module}/cloud-init.yaml.tftpl", {
    ollama_model = var.ollama_model
  })
}

resource "digitalocean_volume_attachment" "models" {
  droplet_id = digitalocean_droplet.this.id
  volume_id  = digitalocean_volume.models.id
}

resource "digitalocean_reserved_ip" "this" {
  count  = var.enable_reserved_ip ? 1 : 0
  region = var.region
}

resource "digitalocean_reserved_ip_assignment" "this" {
  count      = var.enable_reserved_ip ? 1 : 0
  ip_address = digitalocean_reserved_ip.this[0].ip_address
  droplet_id = digitalocean_droplet.this.id
}
