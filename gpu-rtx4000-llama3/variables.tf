variable "do_token" {
  description = "DigitalOcean API token. Source from DIGITALOCEAN_TOKEN or TF_VAR_do_token - never commit a value here."
  type        = string
  sensitive   = true
}

variable "region" {
  description = "DigitalOcean region. GPU droplets are only available in select regions - tor1 currently carries the gpu-6000adax1-48gb fallback this module uses (see droplet_size); verify current availability before apply."
  type        = string
  default     = "nyc1"
}

variable "droplet_size" {
  description = "GPU droplet size slug. RTX 4000 Ada (gpu-4000adax1-20gb, this module's original design target) is confirmed via the live DigitalOcean sizes/regions APIs (2026-09-16) to have zero available regions at all right now - not just a region mismatch, the tier isn't orderable anywhere currently. Falls back to gpu-6000adax1-48gb (48GB VRAM, available in tor1) so this module stays usable; llama3.1:8b still fits fine on 48GB, just with far more headroom than the 20GB design intended, and at roughly double the cost - see ../cost_estimates.md. Re-check RTX 4000 Ada availability periodically and switch back if/when it returns."
  type        = string
  default     = "gpu-6000adax1-48gb"
}

variable "image" {
  description = "Droplet image slug. \"gpu-h100x1-base\" is DigitalOcean's documented AI/ML Ready image slug for ALL single-GPU droplets regardless of GPU model (their own docs: \"For all single GPU Droplets, use gpu-h100x1-base, even for single GPU plans using GPUs other than H100s\") - it ships with NVIDIA drivers/CUDA preinstalled, which this module's cloud-init relies on rather than installing drivers itself. This was previously auto-detected via a digitalocean_images data source sorted by creation date, which twice resolved to the wrong image live (a private, already-deleted third-party marketplace image, then the 8-GPU variant) - hardcoded here instead since DO's own docs give a stable, correct answer. Re-verify via `doctl compute image list --public` if DO changes this guidance."
  type        = string
  default     = "gpu-h100x1-base"
}

variable "droplet_name" {
  description = "Name/tag prefix used for all resources created by this root module."
  type        = string
  default     = "ollama-llama3-rtx4000"
}

variable "ssh_public_key_path" {
  description = "Path to the local SSH public key to register with DigitalOcean and install on the droplet."
  type        = string
  default     = "~/.ssh/id_ed25519.pub"
}

variable "ssh_allowed_ips" {
  description = "CIDR blocks allowed to SSH into the droplet (port 22 only). No default - must be set explicitly per operator."
  type        = list(string)
}

variable "ollama_model" {
  description = "Ollama model tag pulled on first boot. llama3.1:8b is a dense 8B model - ~4.7GB at the default Q4_0 quantization, comfortably fits in 20GB VRAM with plenty of headroom for KV cache/context, and pulls fast (smallest download of any model used across these plans), prioritizing quick + cheap over max capability."
  type        = string
  default     = "llama3.1:8b"
}

variable "model_volume_size_gb" {
  description = "Size (GB) of the persistent DigitalOcean Volume used for Ollama model storage, mounted at /mnt/ollama-models. Smaller than the other GPU plans since llama3.1:8b is a much smaller download."
  type        = number
  default     = 30
}

variable "enable_reserved_ip" {
  description = "Attach a stable DigitalOcean reserved IP to the droplet."
  type        = bool
  default     = false
}

variable "do_project_name" {
  description = "Name of the DigitalOcean Project this droplet is assigned into. The project itself is created by the separate ../project root module (applied once) - this module only looks it up by name, so that module must be applied first."
  type        = string
  default     = "doaivm"
}
