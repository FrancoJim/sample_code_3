resource "google_compute_security_policy" "geo" {
  name    = "${var.name_prefix}-geo-armor"
  project = var.project_id

  rule {
    action   = "allow"
    priority = 1000
    match {
      expr {
        expression = local.geo_allow_expression
      }
    }
  }

  rule {
    action   = "deny(403)"
    priority = 2000
    match {
      versioned_expr = "SRC_IPS_V1"
      config {
        src_ip_ranges = ["*"]
      }
    }
  }

  depends_on = [google_project_service.apis]
}
