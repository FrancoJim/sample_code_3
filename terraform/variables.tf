variable "project_id" {
  description = "GCP project ID"
  type        = string
  default     = "samplecode3"
}

variable "region" {
  description = "Region for Cloud Run and the serverless NEG"
  type        = string
  default     = "us-east1"
}

variable "credentials_file" {
  description = "Path to a GCP service account JSON key; leave empty to use Application Default Credentials"
  type        = string
  default     = ""
}

variable "domain" {
  description = "Public hostname served by the load balancer (Certificate Manager + DNS)"
  type        = string
  default     = "sample3.francojim.com"
}

variable "docker_image" {
  description = "Container image for Cloud Run (must be pullable by the runtime service account)"
  type        = string
  default     = "ghcr.io/francojim/sample_code_3:latest"
}

variable "cloud_run_service_name" {
  description = "Cloud Run service name"
  type        = string
  default     = "sample-code-3-web"
}

variable "name_prefix" {
  description = "Prefix for globally unique resource names"
  type        = string
  default     = "sample3"
}

variable "manage_cloudflare_dns" {
  description = "When true, create/update DNS in the Cloudflare zone (requires cloudflare_api_token or CLOUDFLARE_API_TOKEN)"
  type        = bool
  default     = false
}

variable "cloudflare_api_token" {
  description = "Cloudflare API token (Zone:DNS:Edit, Zone:Zone:Read). If empty, the provider uses the CLOUDFLARE_API_TOKEN environment variable when manage_cloudflare_dns is true"
  type        = string
  sensitive   = true
  default     = ""
}

variable "cloudflare_zone_name" {
  description = "Cloudflare zone name that contains var.domain (e.g. francojim.com)"
  type        = string
  default     = "francojim.com"
}

variable "cloudflare_proxied" {
  description = "When true, the A record is orange-cloud proxied through Cloudflare"
  type        = bool
  default     = false
}

variable "cloudflare_allow_overwrite" {
  description = "Allow Terraform to overwrite an existing DNS record with the same name and type"
  type        = bool
  default     = false
}
