output "load_balancer_ip" {
  description = "Global external IP for the HTTPS load balancer — point Cloudflare DNS (A/AAAA or CNAME strategy) here"
  value       = google_compute_global_address.lb.address
}

output "cloud_run_service" {
  description = "Deployed Cloud Run service identifier"
  value       = google_cloud_run_v2_service.web.name
}

output "dns_authorization_records" {
  description = "Add these records in Cloudflare so Certificate Manager can validate the domain"
  value       = google_certificate_manager_dns_authorization.primary.dns_resource_record
}

output "certificate_map_uri" {
  description = "Certificate map attached to the target HTTPS proxy"
  value       = local.certificate_map_uri
}
