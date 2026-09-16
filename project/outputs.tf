output "project_id" {
  description = "ID of the doaivm DigitalOcean Project."
  value       = digitalocean_project.doaivm.id
}

output "project_name" {
  description = "Name of the doaivm DigitalOcean Project."
  value       = digitalocean_project.doaivm.name
}
