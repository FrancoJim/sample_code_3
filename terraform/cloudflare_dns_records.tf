locals {
  # Cloudflare record "name": subdomain label or "@" for the zone apex
  cloudflare_record_name = (
    var.domain == var.cloudflare_zone_name ? "@" :
    replace(var.domain, ".${var.cloudflare_zone_name}", "")
  )
}

data "cloudflare_zone" "francojim" {
  count = var.manage_cloudflare_dns ? 1 : 0
  filter = {
    name = var.cloudflare_zone_name
  }
}

# GCP global external HTTP(S) load balancers use a static IPv4; point the hostname at that address.
# (A CNAME at the same owner name cannot coexist with other data; use A here.)
resource "cloudflare_dns_record" "gcp_lb_ipv4" {
  count = var.manage_cloudflare_dns ? 1 : 0

  zone_id = data.cloudflare_zone.francojim[0].id
  name    = local.cloudflare_record_name
  type    = "A"
  content = google_compute_global_address.lb.address
  ttl     = 1
  proxied = var.cloudflare_proxied
  comment = "Terraform: GCP external HTTPS load balancer (global address)"

  depends_on = [
    google_compute_global_address.lb,
    google_compute_global_forwarding_rule.https,
  ]
}

# Cloudflare provider v5 renamed cloudflare_record; keep existing state instead of recreating the record.
moved {
  from = cloudflare_record.gcp_lb_ipv4
  to   = cloudflare_dns_record.gcp_lb_ipv4
}
