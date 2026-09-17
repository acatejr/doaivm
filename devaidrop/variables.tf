variable "do_token" {
  description = "DigitalOcean API token. Source from DIGITALOCEAN_TOKEN or TF_VAR_do_token - never commit a value here."
  type        = string
  sensitive   = true
}

variable "region" {
  description = "DigitalOcean region. No GPU-availability constraint applies here, but the CPU-Optimized droplet_size tier isn't offered in every region - confirmed available in sfo3."
  type        = string
  default     = "sfo3"
}

variable "droplet_size" {
  description = "Droplet size slug. Default is CPU-Optimized 32GB/16vCPU; override to \"m-4vcpu-32gb\" (Memory-Optimized) for the cheaper/slower fallback. Verify the current slug via `doctl compute size list` before apply."
  type        = string
  default     = "c-16"
}

variable "image" {
  description = "Droplet image slug. No AI/ML-ready image needed - there is no GPU driver/CUDA stack to preinstall."
  type        = string
  default     = "ubuntu-24-04-x64"
}

variable "droplet_name" {
  description = "Name/tag prefix used for all resources created by this root module."
  type        = string
  default     = "devaidrop"
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

variable "ollama_num_ctx" {
  description = "Context length passed to Ollama. Capped below the model's 256K max to keep CPU memory headroom and latency reasonable."
  type        = number
  default     = 32768
}

variable "ollama_num_thread" {
  description = "Number of CPU threads Ollama uses for inference. Should match the vCPU count of var.droplet_size (16 for the default c-16 tier; set to 4 if overriding droplet_size to the m-4vcpu-32gb fallback)."
  type        = number
  default     = 16
}

variable "do_project_name" {
  description = "Name of the DigitalOcean Project this droplet is assigned into. The project itself is created by the separate ../project root module (applied once) - this module only looks it up by name, so that module must be applied first."
  type        = string
  default     = "doaivm"
}

variable "litellm_master_key" {
  description = "Master key for LiteLLM's proxy - required as a Bearer token on every /v1/... API call once set. Does NOT enable working /ui admin login: LiteLLM's UI login flow requires a connected Postgres database (via Prisma) regardless of master key correctness, and this module doesn't provision one (raises \"Not connected to DB!\" / 400 on POST /v2/login) - see README's \"Admin UI does not work here\" section. No default - generate one yourself (e.g. `openssl rand -hex 24`) and set it in terraform.tfvars; never commit a real value here."
  type        = string
  sensitive   = true
}
