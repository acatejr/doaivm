output "droplet_public_ip" {
  description = "Public IP address of the droplet."
  value       = digitalocean_droplet.this.ipv4_address
}

output "droplet_private_ip" {
  description = "Private (VPC) IP address of the droplet."
  value       = digitalocean_droplet.this.ipv4_address_private
}

output "ssh_command" {
  description = "SSH command to connect to the droplet directly."
  value       = "ssh root@${digitalocean_droplet.this.ipv4_address}"
}

output "ssh_tunnel_command" {
  description = "SSH command to open a local tunnel to the private Ollama API."
  value       = "ssh -N -L 11434:localhost:11434 root@${digitalocean_droplet.this.ipv4_address}"
}

output "litellm_tunnel_command" {
  description = "SSH command to open a local tunnel to the private LiteLLM OpenAI-compatible proxy (fronts the same Ollama model). Once open, point any OpenAI-client-shaped tool at http://localhost:4000/v1."
  value       = "ssh -N -L 4000:localhost:4000 root@${digitalocean_droplet.this.ipv4_address}"
}

output "litellm_master_key" {
  description = "LiteLLM API master key. Required as \"Authorization: Bearer <this value>\" on every /v1/... API call. Does NOT work for /ui admin login - that requires a database this module doesn't provision (see README)."
  value       = var.litellm_master_key
  sensitive   = true
}
