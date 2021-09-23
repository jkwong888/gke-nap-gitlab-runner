locals {
  gke_sa_roles = [
    "roles/monitoring.metricWriter",
    "roles/logging.logWriter",
    "roles/monitoring.viewer",
  ]
}

resource "google_project_iam_member" "container_host_service_agent" {
  depends_on = [
    google_project_service.service_project_api,
  ]

  project     = data.google_project.host_project.id
  role        = "roles/container.hostServiceAgentUser"
  member      = format("serviceAccount:service-%d@container-engine-robot.iam.gserviceaccount.com", data.google_project.service_project.number)
}

resource "google_service_account" "gke_sa" {
  project       = data.google_project.service_project.project_id
  account_id    = format("%s-sa", var.gke_cluster_name)
  display_name  = format("%s cluster service account", var.gke_cluster_name)
}

resource "google_project_iam_member" "gke_sa_role" {
  count   = length(local.gke_sa_roles) 
  project = data.google_project.service_project.project_id
  role    = element(local.gke_sa_roles, count.index) 
  member  = format("serviceAccount:%s", google_service_account.gke_sa.email)
}

resource "google_container_cluster" "primary" {
  provider = google-beta

  lifecycle {
    ignore_changes = [
      # Ignore changes to tags, e.g. because a management agent
      # updates these based on some ruleset managed elsewhere.
      //node_pool["node_count"],
      node_pool["node_count"],
    ]
  }

  depends_on = [
    google_project_service.service_project_api,
    google_compute_subnetwork_iam_member.subnet_user,
    google_compute_subnetwork_iam_member.container_network_user_additional,
    google_compute_subnetwork_iam_member.cloudservices_network_user_additional,
    google_project_iam_member.gke_sa_role,
  ]

  name     = var.gke_cluster_name
  location = var.gke_cluster_location
  project  = data.google_project.service_project.project_id

  release_channel  {
      channel = "REGULAR"
  }

  # We can't create a cluster with no node pool defined, but we want to only use
  # separately managed node pools. So we create the smallest possible default
  # node pool and immediately delete it.
  remove_default_node_pool = true

  master_auth {
    username = ""
    password = ""

    client_certificate_config {
      issue_client_certificate = false
    }
  }

  private_cluster_config {
    enable_private_nodes = var.gke_private_cluster     # nodes have private IPs only
    enable_private_endpoint = false  # master nodes private IP only
    master_ipv4_cidr_block = var.gke_cluster_master_range
  }

  master_authorized_networks_config {
    cidr_blocks {
      cidr_block = "0.0.0.0/0"
      display_name = "eerbody"
    }
  }

  network = local.shared_vpc_network_self_link
  subnetwork = google_compute_subnetwork.subnet[0].self_link

  networking_mode = "VPC_NATIVE"
  ip_allocation_policy {
    cluster_secondary_range_name = var.gke_subnet_pods_range_name
    services_secondary_range_name = var.gke_subnet_services_range_name
  }

  workload_identity_config {
    identity_namespace = "${data.google_project.service_project.project_id}.svc.id.goog"
  }

  cluster_autoscaling {
    enabled = true

    autoscaling_profile = "OPTIMIZE_UTILIZATION"

    auto_provisioning_defaults {
      service_account = google_service_account.gke_sa.email
      oauth_scopes = [
        "https://www.googleapis.com/auth/cloud-platform"
      ]
    }

    resource_limits {
      resource_type = "cpu"
      maximum = var.gke_cluster_autoscaling_cpu_maximum
    }
    resource_limits {
      resource_type = "memory"
      maximum = var.gke_cluster_autoscaling_mem_maximum
    }

  }

  node_pool {
    name = "default-pool"
    node_count = var.gke_default_nodepool_initial_size

    autoscaling {
        min_node_count = var.gke_default_nodepool_min_size
        max_node_count = var.gke_default_nodepool_max_size
    }

    node_config {
      preemptible  = var.gke_use_preemptible_nodes
      machine_type = var.gke_default_nodepool_machine_type

      metadata = {
        disable-legacy-endpoints = "true"
      }

      workload_metadata_config {
        node_metadata = "GKE_METADATA_SERVER"
      }

      service_account = google_service_account.gke_sa.email
      oauth_scopes = [
        "https://www.googleapis.com/auth/cloud-platform"
      ]
      tags = []
      labels = {}
    }
  }
}


resource "google_container_node_pool" "default" {
  for_each = zipmap(var.gke_nodepools.*.name, var.gke_nodepools)
  lifecycle {
    ignore_changes = [
      node_count,
    ]
  }

  depends_on = [
    google_container_cluster.primary,
  ]

  name       = each.key
  location   = var.gke_cluster_location
  cluster    = google_container_cluster.primary.name
  node_count = each.value.initial_size
  project    = data.google_project.service_project.project_id

  autoscaling {
    min_node_count = each.value.min_size 
    max_node_count = each.value.max_size 
  }

  node_config {
    preemptible  = each.value.use_preemptible_nodes 
    machine_type = each.value.machine_type 

    metadata = {
      disable-legacy-endpoints = "true"
    }

    workload_metadata_config {
      node_metadata = "GKE_METADATA_SERVER"
    }

    service_account = google_service_account.gke_sa.email
    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform"
    ]

    labels = each.value.labels

    dynamic "taint" {
      for_each = each.value.taints
      content {
        effect = taint.value.effect
        key = taint.value.key
        value = taint.value.value
      }
    }
  }
}

