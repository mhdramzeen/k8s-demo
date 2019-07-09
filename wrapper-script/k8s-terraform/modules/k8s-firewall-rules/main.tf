# ---------------------------------------------------------------------------------------------------------------------
# CREATE FIREWALL RULES
# ---------------------------------------------------------------------------------------------------------------------
resource "google_compute_firewall" "ssh_port" {
  name    = "${var.network}-firewall-ssh"
  network = "${var.network}"

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  target_tags = ["k8s_tag"]
  source_ranges = ["0.0.0.0/0"]
}

resource "google_compute_firewall" "http_port" {
  name    = "${var.network}-firewall-http"
  network = "${var.network}"

  allow {
    protocol = "tcp"
    ports    = ["80"]
  }

  target_tags   = ["k8s_tag"]
  source_ranges = ["0.0.0.0/0"]
}

resource "google_compute_firewall" "https_port" {
  name    = "${var.network}-firewall-https"
  network = "${var.network}"

  allow {
    protocol = "tcp"
    ports    = ["443"]
  }

  target_tags   = ["k8s_tag"]
  source_ranges = ["0.0.0.0/0"]
}

resource "google_compute_firewall" "icmp_port" {
  name    = "${var.network}-firewall-icmp"
  network = "${var.network}"

  allow {
    protocol = "icmp"
  }

  target_tags   = ["k8s_tag"]
  source_ranges = ["0.0.0.0/0"]
}

resource "google_compute_firewall" "apiserver_port" {
  name    = "${var.network}-firewall-apiserver"
  network = "${var.network}"

  allow {
    protocol = "tcp"
    ports    = ["6443"]
  }

  target_tags   = ["k8s_tag"]
  source_ranges = ["0.0.0.0/0"]
}
