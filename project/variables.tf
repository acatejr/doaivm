variable "do_token" {
  description = "DigitalOcean API token. Source from DIGITALOCEAN_TOKEN or TF_VAR_do_token - never commit a value here."
  type        = string
  sensitive   = true
}

variable "project_name" {
  description = "Name of the DigitalOcean Project all four VM modules assign their resources into. Must match the do_project_name default (\"doaivm\") in each VM module's variables.tf if changed."
  type        = string
  default     = "doaivm"
}

variable "description" {
  description = "DigitalOcean Project description."
  type        = string
  default     = "Ollama-hosted coding assistant VMs (gpu-qwen3-30b, cpu-qwen3-30b, gpu-rtx4000, gpu-rtx4000-llama3)."
}

variable "purpose" {
  description = "DigitalOcean Project purpose (matches one of DO's console dropdown values)."
  type        = string
  default     = "Machine learning / AI / Data processing"
}

variable "environment" {
  description = "DigitalOcean Project environment (Development, Staging, or Production)."
  type        = string
  default     = "Development"
}
