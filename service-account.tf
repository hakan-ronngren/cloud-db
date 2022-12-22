resource "google_service_account" "cloud_db_sa" {
  account_id   = "cloud-db"
  display_name = "Cloud DB"
}

resource "google_service_account_key" "cloud_db_sa_key" {
  service_account_id = google_service_account.cloud_db_sa.name
}
