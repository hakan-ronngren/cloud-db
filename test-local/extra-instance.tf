resource "google_compute_instance" "test_vm" {
  count = var.extra_instance

  name         = "db-test-vm"
  machine_type = "e2-micro"
  zone         = var.zone

  allow_stopping_for_update = true

  boot_disk {
    initialize_params {
      image = "custom-psql"
      labels = {
        usage = "db-test-vm-boot-disk"
      }
    }
  }

  network_interface {
    subnetwork = module.db_vm.subnetwork.id
  }
}
