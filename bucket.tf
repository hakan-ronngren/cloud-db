resource "random_integer" "bucket_uniqueness" {
  min = 100000
  max = 999999
}

resource "google_storage_bucket" "backup_bucket" {
  name          = "cloud-db-${random_integer.bucket_uniqueness.result}"
  location      = var.region
  storage_class = var.dev_mode ? "STANDARD" : "ARCHIVE"
  force_destroy = var.dev_mode
}

resource "google_storage_bucket_iam_member" "member" {
  bucket = google_storage_bucket.backup_bucket.name
  role   = each.value
  member = "serviceAccount:${google_service_account.cloud_db_sa.email}"
  for_each = toset([
    "roles/storage.objectCreator",
    "roles/storage.objectViewer"
  ])
}
