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
    ports    = ["22"]
  }

  source_ranges = ["0.0.0.0/0"]
}

resource "google_compute_firewall" "db_network_egress" {
  name      = "db-network-egress"
  network   = google_compute_network.db_network.name
  direction = "EGRESS"

  allow {
    protocol = "tcp"
    ports    = ["443"]
  }
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

  metadata_startup_script = <<EOT

# Set up the PostgreSQL data partition on the separate data disk
cd /
fsck /dev/sdb
if [ "$?" -eq 8 ] ; then
    systemctl stop postgresql
    tar cf /tmp/postgresql.tar /var/lib/postgresql
    mkfs -t ext4 /dev/sdb
    echo '/dev/sdb /var/lib/postgresql ext4 defaults 0 2' >> /etc/fstab
    mount /var/lib/postgresql
    tar xf /tmp/postgresql.tar
    rm -f /tmp/postgresql.tar
    chown -R postgres:postgres /var/lib/postgresql
    systemctl start postgresql
fi

# Ensure the presence of the pgadmin user (for the phppgadmin web UI) and save
# the password in a file in the /root directory.
cd /
matches=$(sudo -u postgres psql -tAc "select count(rolname) from pg_roles where rolname='pgadmin'")
if [ "$${matches}" -eq 0 ] ; then
    sudo -u postgres psql -c "CREATE USER pgadmin WITH SUPERUSER PASSWORD 'changeme'"
    echo 'host    all             pgadmin         127.0.0.1/32            password' >> /etc/postgresql/13/main/pg_hba.conf
    systemctl restart postgresql
fi
EOT
}
