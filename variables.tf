variable "project" {
  type = string
}

variable "region" {
  type = string
}

variable "zone" {
  type = string
}

variable "image" {
  type        = string
  default     = "custom-psql"
  description = "Default is custom-psql, can be overridden with a specific version"
}

variable "data_disk_gigabytes" {
  type        = number
  default     = 10
  description = "Size of database storage disk in GB. Default and smallest allowed value is 10."
}
