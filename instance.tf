# Helicopter view:
# https://cloud.google.com/docs/terraform/get-started-with-terraform

# https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_network
resource "google_compute_network" "db_network" {
  name                    = "db-network"
  auto_create_subnetworks = false
}

# https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_subnetwork
resource "google_compute_subnetwork" "db_subnetwork" {
  name          = "db-subnetwork"
  network       = google_compute_network.db_network.id
  ip_cidr_range = "192.168.1.0/24"
  region        = var.region
}

# https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_firewall
resource "google_compute_firewall" "db_network_ingress" {
  name    = "db-network-ingress"
  network = google_compute_network.db_network.name

  allow {
    protocol = "tcp"
    ports    = ["22", "5432"]
  }

  source_ranges = ["0.0.0.0/0"]
}

# TODO: delete this one if everything still works. We have no gateway anyway
# resource "google_compute_firewall" "db_network_egress" {
#   name      = "db-network-egress"
#   network   = google_compute_network.db_network.name
#   direction = "EGRESS"

#   allow {
#     protocol = "tcp"
#     ports    = ["443"]
#   }
# }

# https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_instance
resource "google_compute_instance" "db_vm" {
  name         = "db-vm"
  machine_type = "e2-micro"
  zone         = var.zone

  allow_stopping_for_update = true

  boot_disk {
    initialize_params {
      image = var.image
      labels = {
        usage = "db-boot-disk"
      }
    }
  }

  attached_disk {
    source      = google_compute_disk.data_disk.name
    device_name = "db-data"
  }

  network_interface {
    subnetwork = google_compute_subnetwork.db_subnetwork.id
  }

  metadata_startup_script = templatefile(
    "${path.module}/startup_script_template.sh",
    {
      schemas = var.schemas
    }
  )
}
