locals {
  service_project_id  = var.service_project_id
  host_project_id     = var.shared_vpc_host_project_id != "" ? var.shared_vpc_host_project_id : var.service_project_id
  registry_project_id = var.registry_project_id != "" ? var.registry_project_id : var.service_project_id
}

data "google_project" "host_project" {
  project_id = local.host_project_id
}

data "google_project" "service_project" {
  project_id = local.service_project_id
}

data "google_project" "registry_project" {
  project_id = local.registry_project_id
}

resource "google_project_service" "service_project_api" {
  count                      = length(var.service_project_apis_to_enable)
  project                    = data.google_project.service_project.project_id
  service                    = element(var.service_project_apis_to_enable, count.index)
  disable_on_destroy         = false
  disable_dependent_services = false
}