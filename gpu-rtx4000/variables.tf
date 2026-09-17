variable "do_token" {
  description = "DigitalOcean API token. Source from DIGITALOCEAN_TOKEN or TF_VAR_do_token - never commit a value here."
  type        = string
  sensitive   = true
}

variable "region" {
  description = "DigitalOcean region. GPU droplets are only available in select regions - tor1 currently carries the gpu-h100x1-80gb fallback this module uses (see droplet_size); verify current availability before apply, since GPU capacity here has been observed to shift within minutes."
  type        = string
  default     = "tor1"
}

variable "droplet_size" {
  description = "GPU droplet size slug. RTX 4000 Ada (gpu-4000adax1-20gb, this module's original design target) and the entire 48GB tier (gpu-l40sx1-48gb / gpu-6000adax1-48gb, the first fallback used here) are all confirmed via the live DigitalOcean sizes/regions APIs (2026-09-17) to have zero available regions at all right now. The only GPUs orderable anywhere at that check were gpu-h100x1-80gb (NVIDIA H100, $4.41/hr) and gpu-mi325x1-256gb (AMD MI325X, $3.80/hr, needs the gpu-amd-base ROCm image instead - untested in this repo). Falls back to gpu-h100x1-80gb since it reuses the already-configured gpu-h100x1-base NVIDIA/CUDA image with no other changes needed; qwen2.5-coder:14b runs fine on it with far more headroom than intended, at roughly 3x the previous ~$18-38/day estimate - see ../cost_estimates.md. GPU capacity shifts fast here (confirmed: different availability across checks minutes apart) - re-verify before every apply and switch to a cheaper tier the moment one is orderable again."
  type        = string
  default     = "gpu-h100x1-80gb"
}

variable "image" {
  description = "Droplet image slug. \"gpu-h100x1-base\" is DigitalOcean's documented AI/ML Ready image slug for ALL single-GPU droplets regardless of GPU model (their own docs: \"For all single GPU Droplets, use gpu-h100x1-base, even for single GPU plans using GPUs other than H100s\") - it ships with NVIDIA drivers/CUDA preinstalled, which this module's cloud-init relies on rather than installing drivers itself. This was previously auto-detected via a digitalocean_images data source sorted by creation date, which twice resolved to the wrong image live (a private, already-deleted third-party marketplace image, then the 8-GPU variant) - hardcoded here instead since DO's own docs give a stable, correct answer. Re-verify via `doctl compute image list --public` if DO changes this guidance."
  type        = string
  default     = "gpu-h100x1-base"
}

variable "droplet_name" {
  description = "Name/tag prefix used for all resources created by this root module. Used directly as a DO tag value on the droplet, which only allows lowercase letters, numbers, colons, dashes, and underscores - no periods (hence \"qwen2-5\" not \"qwen2.5\")."
  type        = string
  default     = "ollama-qwen2-5-coder-rtx4000"
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
  description = "Ollama model tag pulled on first boot. qwen2.5-coder:14b fits comfortably in 20GB VRAM at Q4_K_M (~10-11GB used including KV cache), unlike the 30B MoE model used by the larger GPU tier."
  type        = string
  default     = "qwen2.5-coder:14b"
}

variable "model_volume_size_gb" {
  description = "Size (GB) of the persistent DigitalOcean Volume used for Ollama model storage, mounted at /mnt/ollama-models."
  type        = number
  default     = 50
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
