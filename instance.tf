# Helicopter view:
# https://cloud.google.com/docs/terraform/get-started-with-terraform

# https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_disk
resource "google_compute_disk" "data_disk" {
  name = "db-data"
  type = "pd-standard"
  zone = var.zone
  size = "10"
  labels = {
    usage = "db-data-disk"
  }
}

# https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_network
# resource "google_compute_network" "db_network" {
#   name                    = "db-network"
#   auto_create_subnetworks = false
# }

# https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_subnetwork
# resource "google_compute_subnetwork" "db_subnetwork" {
#   name          = "db-subnetwork"
#   network       = google_compute_network.db_network.id
#   ip_cidr_range = "10.0.1.0/24"
#   region        = var.region
# }

locals {
  install_script = <<EOT
# Set up the PostgreSQL data partition on a separate disk
fsck /dev/sdb
if [ "$?" -eq 8 ] ; then
    mkdir -p /var/lib/postgresql
    sudo mkfs -t ext4 /dev/sdb
    echo '/dev/sdb /var/lib/postgresql ext4 defaults 0 2' >> /etc/fstab
    mount /var/lib/postgresql
fi

# Install and set up PostgreSQL if not already done
if ! which psql ; then
    apt update
    apt install -y postgresql postgresql-contrib
    systemctl enable postgresql
    systemctl start postgresql
fi
EOT
}


# https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_instance
resource "google_compute_instance" "db_vm" {
  name         = "db-vm"
  machine_type = "e2-micro"
  zone         = var.zone

  allow_stopping_for_update = true

  boot_disk {
    initialize_params {
      # image = "debian-cloud/debian-11"
      image = local.image
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
    # subnetwork = google_compute_subnetwork.db_subnetwork.id
    network = "default"

    access_config {
      # TODO: get rid of this, we should be able to fetch db packages without having an external IP address
    }
  }

  metadata_startup_script = var.install_from_base_image ? local.install_script : ""
}

output "produced_image" {
  value = var.install_from_base_image ? local.produced_image : ""
}
