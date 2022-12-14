variable "project" {
  type = string
}

variable "region" {
  type = string
}

variable "zone" {
  type = string
}

variable "install_from_base_image" {
  type        = bool
  default     = false
  description = "Set this to true only if you want to use the VM to create a new base image"
}
