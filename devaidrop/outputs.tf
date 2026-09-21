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
  description = "SSH command to open a local tunnel to the Ollama API. Not required for access (see ollama_api_url) since the API is also publicly reachable directly - kept as an alternative."
  value       = "ssh -N -L 11434:localhost:11434 root@${digitalocean_droplet.this.ipv4_address}"
}

output "ollama_api_url" {
  description = "Public, unauthenticated URL of the Ollama API. Temporary exception to this repo's private-only posture - reachable by anyone, no auth in front of it."
  value       = "http://${digitalocean_droplet.this.ipv4_address}:11434"
}
