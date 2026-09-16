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
