variable "do_token" {
  description = "DigitalOcean API token. Source from DIGITALOCEAN_TOKEN or TF_VAR_do_token - never commit a value here."
  type        = string
  sensitive   = true
}

variable "region" {
  description = "DigitalOcean region. RTX 6000 Ada / L40S GPU droplets are only available in select regions - sfo1 is not an orderable region at all (confirmed live, 2026-09-17: DO's regions API marks it unavailable), so this must stay tor1, where the current droplet_size (L40S) is actually available. Verify current availability before apply, since it shifts."
  type        = string
  default     = "tor1"
}

variable "droplet_size" {
  description = "GPU droplet size slug. L40S (gpu-l40sx1-48gb) and RTX 6000 Ada (gpu-6000adax1-48gb) are the two interchangeable 48GB-VRAM options for this plan, and availability flips between them over time - confirmed live (2026-09-17) that L40S is back to available in tor1 while RTX 6000 Ada now has zero available regions (the reverse of an earlier check), so this reverts to the module's original L40S target. Re-verify via `doctl compute size list` before every apply, since GPU availability shifts - if this slug stops working, check whether gpu-6000adax1-48gb has come back instead."
  type        = string
  default     = "gpu-l40sx1-48gb"
}

variable "image" {
  description = "Droplet image slug. \"gpu-h100x1-base\" is DigitalOcean's documented AI/ML Ready image slug for ALL single-GPU droplets regardless of GPU model (their own docs: \"For all single GPU Droplets, use gpu-h100x1-base, even for single GPU plans using GPUs other than H100s\") - it ships with NVIDIA drivers/CUDA preinstalled, which this module's cloud-init relies on rather than installing drivers itself. This was previously auto-detected via a digitalocean_images data source sorted by creation date, which twice resolved to the wrong image live (a private, already-deleted third-party marketplace image, then the 8-GPU variant) - hardcoded here instead since DO's own docs give a stable, correct answer. Re-verify via `doctl compute image list --public` if DO changes this guidance."
  type        = string
  default     = "gpu-h100x1-base"
}

variable "droplet_name" {
  description = "Name/tag prefix used for all resources created by this root module."
  type        = string
  default     = "ollama-qwen3-coder"
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
  description = "Ollama model tag pulled on first boot."
  type        = string
  default     = "qwen3-coder:30b"
}

variable "model_volume_size_gb" {
  description = "Size (GB) of the persistent DigitalOcean Volume used for Ollama model storage, mounted at /mnt/ollama-models."
  type        = number
  default     = 100
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
