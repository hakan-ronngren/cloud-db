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

# TODO: MAKE THIS ONE WORK. MISSING A GATEWAY?
#
# hakron@db-vm:~$ ip address
# 1: lo: <LOOPBACK,UP,LOWER_UP> mtu 65536 qdisc noqueue state UNKNOWN group default qlen 1000
#     link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00
#     inet 127.0.0.1/8 scope host lo
#        valid_lft forever preferred_lft forever
#     inet6 ::1/128 scope host
#        valid_lft forever preferred_lft forever
# 2: ens4: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1460 qdisc mq state UP group default qlen 1000
#     link/ether 42:01:0a:00:01:02 brd ff:ff:ff:ff:ff:ff
#     altname enp0s4
#     inet 10.0.1.2/32 brd 10.0.1.2 scope global dynamic ens4
#        valid_lft 3172sec preferred_lft 3172sec
#     inet6 fe80::4001:aff:fe00:102/64 scope link
#        valid_lft forever preferred_lft forever

# hakron@db-vm:~$ ip route
# default via 10.0.1.1 dev ens4
# 10.0.1.1 dev ens4 scope link

# hakron@db-vm:~$ ping 10.0.1.1
# PING 10.0.1.1 (10.0.1.1) 56(84) bytes of data.
# ^C
# --- 10.0.1.1 ping statistics ---
# 7 packets transmitted, 0 received, 100% packet loss, time 6121ms
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

  # attached_disk {
  #   source      = google_compute_disk.data_disk.name
  #   device_name = "db-data"
  # }

  network_interface {
    subnetwork = google_compute_subnetwork.db_subnetwork.id
    # network = "default"

    # access_config {
    #   network_tier = "STANDARD"
    # }
  }

  #   metadata_startup_script = <<EOT
  # # Set up the PostgreSQL data partition on a separate disk
  # fsck /dev/sdb
  # if [ "$?" -eq 8 ] ; then
  #     mkdir -p /var/lib/postgresql
  #     mkfs -t ext4 /dev/sdb
  #     echo '/dev/sdb /var/lib/postgresql ext4 defaults 0 2' >> /etc/fstab
  #     mount /var/lib/postgresql
  # fi
  # EOT

  metadata_startup_script = <<EOT
apt update
apt install -y postgresql postgresql-contrib
systemctl enable postgresql
systemctl start postgresql
EOT
}
