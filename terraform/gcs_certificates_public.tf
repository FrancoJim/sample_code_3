resource "google_certificate_manager_dns_authorization" "primary" {
  name     = "${var.name_prefix}-dns-auth"
  location = "global"
  project  = var.project_id
  domain   = var.domain

  depends_on = [google_project_service.apis]
}

resource "google_certificate_manager_certificate" "managed" {
  name        = "${var.name_prefix}-managed-cert"
  location    = "global"
  project     = var.project_id
  description = "Managed cert for ${var.domain} via Certificate Manager"

  managed {
    domains            = [var.domain]
    dns_authorizations = [google_certificate_manager_dns_authorization.primary.id]
  }

  depends_on = [google_project_service.apis]
}

resource "google_certificate_manager_certificate_map" "lb" {
  name        = "${var.name_prefix}-cert-map"
  description = "Certificate map for HTTPS load balancer"
  project     = var.project_id

  depends_on = [google_project_service.apis]
}

resource "google_certificate_manager_certificate_map_entry" "primary" {
  name         = "${var.name_prefix}-cert-entry"
  project      = var.project_id
  map          = google_certificate_manager_certificate_map.lb.name
  certificates = [google_certificate_manager_certificate.managed.id]
  hostname     = var.domain

  depends_on = [google_certificate_manager_certificate_map.lb]
}
