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

variable "enable_pgadmin" {
  type        = bool
  default     = false
  description = "Whether to enable the pgadmin web UI"
}

# Databases listed here will get backup copies in a bucket. The database/user settings in this map
# will be reapplied every time you run terraform apply. However, if you delete a database from the
# map, it will still remain in PostgreSQL. I just won't get provisioned anymore, and it won't be
# covered by the backup script.
variable "databases" {
  type        = list(map(string))
  description = "List of databases to create. Every map has the keys name, user and md5_password."
  sensitive   = true
}

variable "uptime_schedule" {
  type        = map(string)
  description = "Key/value pairs to define the uptime schedule: start and stop are cron expressions, time_zone is an IANA time zone name"
  default = {
    start     = "0 6 * * *"
    stop      = "0 0 * * *"
    time_zone = "Etc/UTC"
  }
}

variable "dev_mode" {
  type        = bool
  description = "If true, resources are created without protection against destruction and with pricing optimisations for frequent apply/destroy."
  default     = false
}
