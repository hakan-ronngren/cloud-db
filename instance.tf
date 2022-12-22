# Helicopter view on using Terraform with the GCP:
# https://cloud.google.com/docs/terraform/get-started-with-terraform

# https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_network
resource "google_compute_network" "db_network" {
  name                    = "db-network"
  auto_create_subnetworks = false
}

# https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_subnetwork
resource "google_compute_subnetwork" "db_subnetwork" {
  name                     = "db-subnetwork"
  network                  = google_compute_network.db_network.id
  ip_cidr_range            = "192.168.1.0/24"
  region                   = var.region
  private_ip_google_access = true
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
      databases   = var.databases
      private_key = google_service_account_key.cloud_db_sa_key.private_key
      bucket_name = google_storage_bucket.backup_bucket.name
    }
  )
}
