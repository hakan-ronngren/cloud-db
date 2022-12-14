locals {
  base_image     = "debian-cloud/debian-11"
  produced_image = "custom-psql"
  image          = var.install_from_base_image ? local.base_image : local.produced_image
}
