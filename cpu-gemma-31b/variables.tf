variable "do_token" {
  description = "DigitalOcean API token. Source from DIGITALOCEAN_TOKEN or TF_VAR_do_token - never commit a value here."
  type        = string
  sensitive   = true
}

variable "region" {
  description = "DigitalOcean region."
  type        = string
  default     = "nyc3"
}

variable "droplet_size" {
  description = "Droplet size slug. The original \"s-8vcpu-64gb\" does not exist in DigitalOcean's size catalog at all (confirmed via the live sizes API) - m-8vcpu-64gb (Memory-Optimized, 8vCPU/64GB RAM) is the real equivalent and is available in nyc3."
  type        = string
  default     = "m-8vcpu-64gb"
}

variable "image" {
  description = "Droplet image slug."
  type        = string
  default     = "ubuntu-24-04-x64"
}

variable "droplet_name" {
  description = "Name/tag prefix used for all resources created by this root module. Used directly as a DO tag value on the droplet, which only allows lowercase letters, numbers, colons, dashes, and underscores - no periods."
  type        = string
  default     = "ollama-gemma4-31b-cpu"
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
  description = "Ollama model tag pulled on first boot. gemma4:31b is a dense ~30.7B parameter model - the 64GB RAM on the default droplet_size gives it comfortable headroom for CPU inference."
  type        = string
  default     = "gemma4:31b"
}

variable "do_project_name" {
  description = "Name of the DigitalOcean Project this droplet is assigned into. The project itself is created by the separate ../project root module (applied once) - this module only looks it up by name, so that module must be applied first."
  type        = string
  default     = "doaivm"
}
