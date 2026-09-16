variable "do_token" {
  description = "DigitalOcean API token. Create one at https://cloud.digitalocean.com/account/api/tokens"
  type        = string
  sensitive   = true
}

variable "region" {
  description = "DigitalOcean region slug for the droplet and volume (must support the chosen droplet size)."
  type        = string
  default     = "nyc3"
}

variable "droplet_size" {
  description = "Basic (shared CPU) droplet size slug. s-4vcpu-8gb = 8GB RAM / 4 vCPU, ~$0.071/hr (~$48/mo) as of Sept 2026."
  type        = string
  default     = "s-4vcpu-8gb"
}

variable "image" {
  description = "Base OS image slug."
  type        = string
  default     = "ubuntu-22-04-x64"
}

variable "droplet_name" {
  description = "Base name used for the droplet, volume, firewall and SSH key resources."
  type        = string
  default     = "ollama-qwen-coder"
}

variable "ssh_public_key_path" {
  description = "Path to a local SSH public key that will be installed on the droplet and registered with DigitalOcean."
  type        = string
  default     = "~/.ssh/id_ed25519.pub"
}

variable "ssh_allowed_ips" {
  description = "CIDR blocks allowed to reach SSH (port 22). Set this to your own public IP, e.g. [\"203.0.113.42/32\"]. Left empty, no one (including you) can SSH in, which is intentional -- there is no safe default here. In practice you shouldn't need to set this by hand: scripts/up.sh, down.sh, and allow-my-ip.sh auto-detect your current public IP and pass it as TF_VAR_ssh_allowed_ips on every run, which matters if you work from a laptop that roams between networks. Only set a value here (or in terraform.tfvars) if you want a fixed allowlist instead -- it will override the auto-detected one."
  type        = list(string)
  default     = []

  validation {
    condition     = length(var.ssh_allowed_ips) > 0
    error_message = "Set ssh_allowed_ips to at least your own IP in CIDR form, e.g. [\"203.0.113.42/32\"]. Find it with `curl ifconfig.me`, or just use scripts/up.sh, which does this for you automatically."
  }
}

variable "ollama_allowed_ips" {
  description = "CIDR blocks allowed to reach the Ollama API directly on port 11434. Left empty (default), the API is NOT exposed to the internet -- use the SSH tunnel shown in the outputs instead. Only set this if you specifically want direct network access."
  type        = list(string)
  default     = []
}

variable "model_name" {
  description = "Ollama model tag to pull automatically on first boot."
  type        = string
  default     = "qwen2.5-coder:7b"
}

variable "volume_size_gb" {
  description = "Size in GB of the persistent block volume that stores pulled Ollama models. 10GB comfortably fits the 7B model (~4.7GB) with room to try another size. This volume is what lets you destroy/recreate the droplet without re-downloading the model each time."
  type        = number
  default     = 10
}
