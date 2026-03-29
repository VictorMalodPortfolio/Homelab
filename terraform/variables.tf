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

variable "domain" {
  description = "Root domain managed by OVH DNS"
  type        = string
  default     = "victor-malod.ovh"
}
