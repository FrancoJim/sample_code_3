resource "google_compute_url_map" "https" {
  name            = "${var.name_prefix}-https-urlmap"
  project         = var.project_id
  default_service = google_compute_backend_service.web.id
}

resource "google_compute_url_map" "redirect_http" {
  name    = "${var.name_prefix}-https-redirect"
  project = var.project_id

  default_url_redirect {
    https_redirect         = true
    redirect_response_code = "MOVED_PERMANENTLY_DEFAULT"
    strip_query            = false
  }
}

resource "google_compute_target_https_proxy" "https" {
  name            = "${var.name_prefix}-https-proxy"
  project         = var.project_id
  url_map         = google_compute_url_map.https.id
  certificate_map = local.certificate_map_uri

  depends_on = [
    google_certificate_manager_certificate_map_entry.primary,
    google_compute_url_map.https,
  ]
}

resource "google_compute_target_http_proxy" "redirect" {
  name    = "${var.name_prefix}-http-proxy"
  project = var.project_id
  url_map = google_compute_url_map.redirect_http.id
}

resource "google_compute_global_forwarding_rule" "https" {
  name                  = "${var.name_prefix}-https-fr"
  project               = var.project_id
  load_balancing_scheme = "EXTERNAL_MANAGED"
  target                = google_compute_target_https_proxy.https.id
  port_range            = "443"
  ip_address            = google_compute_global_address.lb.address
}

resource "google_compute_global_forwarding_rule" "http" {
  name                  = "${var.name_prefix}-http-fr"
  project               = var.project_id
  load_balancing_scheme = "EXTERNAL_MANAGED"
  target                = google_compute_target_http_proxy.redirect.id
  port_range            = "80"
  ip_address            = google_compute_global_address.lb.address
}
