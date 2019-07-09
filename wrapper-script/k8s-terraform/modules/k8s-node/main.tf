resource "google_compute_instance" "k8s-node1" {
  name         = "${var.instance_name1}"
  machine_type = "${var.vm_type1}"
  zone = "${var.region1}"
  tags = ["k8s_tag"]

  boot_disk {
    initialize_params {
      image = "${var.os}" 
    }
  }


  network_interface {
    network = "default"

    access_config {
      // Ephemeral IP
    }
  }
}

resource "google_compute_instance" "k8s-node2" {
  name         = "${var.instance_name2}"
  machine_type = "${var.vm_type1}"
  zone = "${var.region2}"
  tags = ["k8s_tag"]

  boot_disk {
    initialize_params {
      image = "${var.os}"
    }
  }


  network_interface {
    network = "default"

    access_config {
      // Ephemeral IP
    }
  }
}

