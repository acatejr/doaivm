# This is the only module that owns/creates the "doaivm" DigitalOcean Project.
# The four VM modules (gpu-qwen3-30b/, cpu-qwen3-30b/, gpu-rtx4000/,
# gpu-rtx4000-llama3/) look it up by name via a data source and assign their own
# droplet/volume/VPC into it - they never create or manage the project itself.
# Apply this module before any of the four VM modules' first apply.
resource "digitalocean_project" "doaivm" {
  name        = var.project_name
  description = var.description
  purpose     = var.purpose
  environment = var.environment
  is_default  = false
}
