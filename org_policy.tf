resource "google_project_organization_policy" "shielded_vm_disable" {
  project    = data.google_project.service_project.project_id
  constraint = "constraints/compute.requireShieldedVm"

  boolean_policy {
    enforced = false 
  }
}

resource "google_project_organization_policy" "oslogin_disable" {
  project    = data.google_project.service_project.project_id
  constraint = "constraints/compute.requireOsLogin"

  boolean_policy {
    enforced = false 
  }
}

// for GKE control plane, allow projects in google.com to peer with us
resource "google_project_organization_policy" "vpcPeeringAllow" {
  project    = data.google_project.service_project.project_id
  constraint = "constraints/compute.restrictVpcPeering"

  list_policy {
    allow {
      values =  [
        "under:organizations/433637338589" // google.com
      ]
    }
  }
}