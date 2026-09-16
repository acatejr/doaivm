output "droplet_ip" {
  description = "Public IPv4 address of the droplet."
  value       = digitalocean_droplet.ollama.ipv4_address
}

output "ssh_command" {
  description = "SSH into the droplet directly."
  value       = "ssh root@${digitalocean_droplet.ollama.ipv4_address}"
}

output "ollama_tunnel_command" {
  description = "Recommended way to reach the Ollama API without exposing it publicly: tunnel it over SSH, then talk to http://localhost:11434 on your own machine."
  value       = "ssh -N -L 11434:localhost:11434 root@${digitalocean_droplet.ollama.ipv4_address}"
}

output "ollama_direct_endpoint" {
  description = "Only reachable if you set ollama_allowed_ips. Empty string otherwise."
  value       = length(var.ollama_allowed_ips) > 0 ? "http://${digitalocean_droplet.ollama.ipv4_address}:11434" : "(not exposed -- ollama_allowed_ips is empty; use ollama_tunnel_command instead)"
}

output "bootstrap_log_check" {
  description = "First boot takes a few minutes (installing Ollama + pulling the model). Tail this to watch progress."
  value       = "ssh root@${digitalocean_droplet.ollama.ipv4_address} 'tail -f /var/log/ollama-bootstrap.log'"
}

output "estimated_running_cost" {
  description = "Rough cost while the droplet is up."
  value       = "Droplet: ~$0.071/hr (${var.droplet_size}, ~$48/mo if left on 24/7). Volume: ~$0.10/GB-mo (${var.volume_size_gb}GB -> roughly ${var.volume_size_gb * 0.10}/mo), billed whether or not the droplet exists."
}
