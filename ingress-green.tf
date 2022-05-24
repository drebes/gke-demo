data "google_compute_network_endpoint_group" "echo_neg" {
  name    = "green-echo-neg"
  zone    = "europe-west6-a"
  project = local.project_id
}

data "google_compute_network_endpoint_group" "hello_neg" {
  name    = "green-hello-neg"
  zone    = "europe-west6-a"
  project = local.project_id
}

resource "google_compute_health_check" "echo_health_check" {
  name    = "echo-health-check"
  project = local.project_id

  timeout_sec        = 15
  check_interval_sec = 15

  http_health_check {
    port_specification = "USE_SERVING_PORT"
    request_path       = "/"
    proxy_header       = "NONE"
  }
}

resource "google_compute_health_check" "hello_health_check" {
  name    = "hello-health-check"
  project = local.project_id

  timeout_sec        = 15
  check_interval_sec = 15

  http_health_check {
    port_specification = "USE_SERVING_PORT"
    request_path       = "/"
    proxy_header       = "NONE"
  }
}

resource "google_compute_backend_service" "echo_service" {
  connection_draining_timeout_sec = 300
  description                     = "Terraform managed."
  enable_cdn                      = true
  health_checks = [
    google_compute_health_check.echo_health_check.id,
  ]
  load_balancing_scheme = "EXTERNAL"
  name                  = "green-echo-backend"
  project               = local.project_id

  backend {
    balancing_mode        = "RATE"
    capacity_scaler       = 1
    max_rate_per_endpoint = 1
    group                 = data.google_compute_network_endpoint_group.echo_neg.id
  }
}

resource "google_compute_backend_service" "hello_service" {
  connection_draining_timeout_sec = 300
  description                     = "Terraform managed."
  enable_cdn                      = true
  health_checks = [
    google_compute_health_check.hello_health_check.id,
  ]
  load_balancing_scheme = "EXTERNAL"
  name                  = "green-hello-backend"
  project               = local.project_id

  backend {
    balancing_mode        = "RATE"
    capacity_scaler       = 1
    max_rate_per_endpoint = 1
    group                 = data.google_compute_network_endpoint_group.hello_neg.id
  }
}

resource "google_compute_url_map" "url_map" {
  name        = "green-url-map"
  description = "URL map for grene cluster"
  project     = local.project_id

  default_service = google_compute_backend_service.echo_service.id

  host_rule {
    hosts        = ["*"]
    path_matcher = "matcher"
  }

  path_matcher {
    name            = "matcher"
    default_service = google_compute_backend_service.echo_service.id

    path_rule {
      paths   = ["/hello"]
      service = google_compute_backend_service.hello_service.id
    }

    path_rule {
      paths   = ["/echo"]
      service = google_compute_backend_service.echo_service.id
    }
  }
}

resource "google_compute_managed_ssl_certificate" "green_cert" {
  name    = "green-cert"
  project = local.project_id

  managed {
    domains = ["${module.ingress_addresses.global_addresses["ingress-green"].address}.nip.io."]
  }
}

resource "google_compute_target_https_proxy" "green_proxy" {
  name             = "green-proxy"
  project          = local.project_id
  url_map          = google_compute_url_map.url_map.id
  ssl_certificates = [google_compute_managed_ssl_certificate.green_cert.id]
}

resource "google_compute_target_http_proxy" "green_proxy" {
  name    = "green-proxy"
  project = local.project_id
  url_map = google_compute_url_map.url_map.id
}

resource "google_compute_global_forwarding_rule" "green_https" {
  name                  = "green-https-forwarding-rule"
  project               = local.project_id
  ip_protocol           = "TCP"
  load_balancing_scheme = "EXTERNAL"
  port_range            = "443"
  target                = google_compute_target_https_proxy.green_proxy.id
  ip_address            = module.ingress_addresses.global_addresses["ingress-green"].self_link
}

resource "google_compute_global_forwarding_rule" "green_http" {
  name                  = "green-http-forwarding-rule"
  project               = local.project_id
  ip_protocol           = "TCP"
  load_balancing_scheme = "EXTERNAL"
  port_range            = "80"
  target                = google_compute_target_http_proxy.green_proxy.id
  ip_address            = module.ingress_addresses.global_addresses["ingress-green"].self_link
}
