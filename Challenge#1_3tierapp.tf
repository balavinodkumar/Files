provider "google" {
  version = "3.27.0"
  project = "k8s-training1-375309"
  region  = "us-central1"
}

resource "google_compute_network" "network" {
  name = "my-network"
}

resource "google_compute_subnetwork" "frontend" {
  name          = "frontend"
  network       = google_compute_network.network.self_link
  ip_cidr_range = "10.0.1.0/24"
  region        = "us-central1"
}

resource "google_compute_subnetwork" "app" {
  name          = "app"
  network       = google_compute_network.network.self_link
  ip_cidr_range = "10.0.2.0/24"
  region        = "us-central1"
}

resource "google_compute_subnetwork" "db" {
  name          = "db"
  network       = google_compute_network.network.self_link
  ip_cidr_range = "10.0.3.0/24"
  region        = "us-central1"
}

resource "google_compute_firewall" "firewall" {
  name    = "my-firewall"
  network = google_compute_network.network.self_link

  allow {
    protocol = "tcp"
    ports    = ["22", "80", "443"]
  }
}

resource "google_compute_instance_template" "instance_template" {
  name = "my-instance-template"
  machine_type = "e2-medium"
  disk {
    boot = true
    auto_delete = true
    source_image = "ubuntu-os-cloud/ubuntu-1804-lts"
  }  
  metadata = {
    startup-script = "#!/bin/bash\napt-get update && apt-get install -y nginx"
  }

  tags = ["http-server"]

  service_account {
    email = "default"
    scopes = [
      "compute-rw",
      "storage-ro"
    ]
  }
}

resource "google_compute_instance_group_manager" "instance_group" {
  name               = "my-instance-group"
  instance_template  = google_compute_instance_template.instance_template.self_link
  base_instance_name = "my-instance"
  zone               = "us-central1-a"
  target_size        = 2
  version {
    name = "first-version"
    instance_template = google_compute_instance_template.instance_template.self_link
  }
}

resource "google_compute_http_health_check" "health_check" {
  name               = "my-health-check"
  request_path       = "/"
  check_interval_sec = 1
  timeout_sec        = 1
}

resource "google_compute_backend_service" "backend_service" {
  name        = "my-backend-service"
  health_checks = [google_compute_http_health_check.health_check.self_link]
  backend {
    group = google_compute_instance_group_manager.instance_group.self_link
  }
}

resource "google_compute_global_forwarding_rule" "forward" {
  name       = "my-forwarding-rule"
  target     = google_compute_backend_service.backend_service.self_link
  port_range = "80"
  ip_protocol = "TCP"
}