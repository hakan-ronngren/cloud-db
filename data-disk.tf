# https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_disk
# resource "google_compute_disk" "data_disk" {
#   name = "db-data"
#   type = "pd-standard"
#   zone = var.zone
#   size = var.data_disk_gigabytes
#   labels = {
#     usage = "db-data-disk"
#   }
# }
