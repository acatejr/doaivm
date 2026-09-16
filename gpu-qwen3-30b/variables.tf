variable "do_token" {
  description = "DigitalOcean API token. Source from DIGITALOCEAN_TOKEN or TF_VAR_do_token - never commit a value here."
  type        = string
  sensitive   = true
}

variable "region" {
  description = "DigitalOcean region. RTX 6000 Ada / L40S GPU droplets are only available in select regions (TOR1 as of planning - verify current availability)."
  type        = string
  default     = "tor1"
}

variable "droplet_size" {
  description = "GPU droplet size slug. L40S (gpu-l40sx1-48gb) and RTX 6000 Ada (gpu-6000adax1-48gb) are the two interchangeable 48GB-VRAM options for this plan; confirmed via the live DigitalOcean sizes API (2026-09-16) that L40S currently has zero available regions while RTX 6000 Ada is available in tor1, so that's the default here - re-verify via `doctl compute size list` before apply, since GPU availability shifts over time."
  type        = string
  default     = "gpu-6000adax1-48gb"
}

variable "image" {
  description = "Droplet image slug. Leave null to fall back to the newest available Ubuntu image in the region; set explicitly once the AI/ML Ready GPU image slug is confirmed via `doctl compute image list --public`."
  type        = string
  default     = null
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
