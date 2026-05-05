locals {
  north_america_allow = ["US", "CA"]
  # Europe-focused ISO 3166-1 alpha-2 list (plus nearby states often grouped with European traffic policies)
  europe_allow = [
    "AL", "AD", "AT", "BE", "BG", "HR", "CY", "CZ", "DK", "EE", "FI", "FR",
    "DE", "GR", "HU", "IS", "IE", "IT", "LV", "LI", "LT", "LU", "MT", "MD",
    "MC", "ME", "NL", "MK", "NO", "PL", "PT", "RO", "SM", "RS", "SK", "SI",
    "ES", "SE", "CH", "UA", "GB", "VA", "XK", "GI", "FO", "GG", "JE", "IM"
  ]
  allowed_region_codes = distinct(concat(local.north_america_allow, local.europe_allow))
  geo_allow_expression = "origin.region_code in [${join(", ", [for c in local.allowed_region_codes : "'${c}'"])}]"
  certificate_map_uri  = "//certificatemanager.googleapis.com/${google_certificate_manager_certificate_map.lb.id}"
}
