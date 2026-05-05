provider "google" {
  project     = var.project_id
  region      = var.region
  credentials = var.credentials_file != "" ? file(var.credentials_file) : null
}

provider "cloudflare" {
  api_token = var.cloudflare_api_token != "" ? var.cloudflare_api_token : null
}
