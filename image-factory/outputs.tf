resource "local_file" "make_include_file" {
  filename        = "terraform-generated.mk"
  file_permission = "0644"
  content         = <<EOT
PROJECT = ${var.project}
REGION = ${var.region}
ZONE = ${var.zone}
IMAGE_FAMILY = ${module.db_vm.produced_image}
EOT
}
