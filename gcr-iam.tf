/*
resource "google_storage_bucket_iam_member" "compute_engine_default_registry_bucket" {
    depends_on = [
        google_project_service.service_project_api,
    ]

    bucket = format("artifacts.%s.appspot.com", data.google_project.registry_project.project_id)
    role = "roles/storage.objectViewer"
    member = format("serviceAccount:%s-compute@developer.gserviceaccount.com", data.google_project.service_project.number)
}
*/