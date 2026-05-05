resource "google_compute_global_address" "lb" {
  name    = "${var.name_prefix}-lb-ip"
  project = var.project_id

  depends_on = [google_project_service.apis]
}

resource "google_compute_region_network_endpoint_group" "run" {
  name                  = "${var.name_prefix}-run-neg"
  project               = var.project_id
  region                = var.region
  network_endpoint_type = "SERVERLESS"

  cloud_run {
    service = google_cloud_run_v2_service.web.name
  }

  depends_on = [google_cloud_run_v2_service.web]
}

resource "google_compute_backend_service" "web" {
  name                  = "${var.name_prefix}-run-backend"
  project               = var.project_id
  protocol              = "HTTP"
  port_name             = "http"
  load_balancing_scheme = "EXTERNAL_MANAGED"

  backend {
    group = google_compute_region_network_endpoint_group.run.id
  }

  security_policy = google_compute_security_policy.geo.id

  depends_on = [
    google_compute_region_network_endpoint_group.run,
    google_compute_security_policy.geo,
  ]
}
