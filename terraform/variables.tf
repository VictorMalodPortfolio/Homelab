variable "ovh_application_key" {
  description = "OVH API application key"
  type        = string
  sensitive   = true
}

variable "ovh_application_secret" {
  description = "OVH API application secret"
  type        = string
  sensitive   = true
}

variable "ovh_consumer_key" {
  description = "OVH API consumer key"
  type        = string
  sensitive   = true
}

variable "vps_name" {
  description = "Name of the VPS as it appears in OVH manager"
  type        = string
}

variable "ssh_private_key_path" {
  description = "Private key OpenTofu uses to provision the VPS over SSH (the one registered on the VPS when ordering it)"
  type        = string
  default     = "~/.ssh/vps-admin"
}

variable "domain" {
  description = "Root domain managed by OVH DNS"
  type        = string
  default     = "victor-malod.ovh"
}
