variable "service_project_id" {
  description = "The ID of the service project which hosts the project resources e.g. dev-55427"
}

variable "shared_vpc_host_project_id" {
  description = "The ID of the host project which hosts the shared VPC -- blank for the same as service project"
  default = ""
}

variable "registry_project_id" {
  description = "The ID of the project which hosts the registry -- blank for the same project as service project"
  default = ""
}

variable "create_vpc" {
  description = "set to true to create a new VPC"
  default = true
}

variable "service_project_apis_to_enable" {
  type = list(string)
  default = [
    "container.googleapis.com",
    "compute.googleapis.com",
  ]
}

variable "shared_vpc_network" {
  description = "The ID of the shared VPC e.g. shared-network"
}

variable "subnets" {
  type = list(object({
    name=string,
    region=string,
    primary_range=string,
    secondary_range=map(any)
  }))
  default = []
}

variable "subnet_users" {
  type = list(string)
  default = []
}

variable "gke_cluster_name" {
  description = "gke cluster name"
}

variable "gke_cluster_location" {
  description = "cluster location, either a region or a zone"
}

variable "gke_cluster_master_range" {
  description = "gke master cluster cidr"
}

variable "gke_subnet_pods_range_name" {
    default = "pods"
}

variable "gke_subnet_services_range_name" {
    default = "services"
}

variable "gke_default_nodepool_initial_size" {
    default = 1
}

variable "gke_default_nodepool_min_size" {
    default = 0
}

variable "gke_default_nodepool_max_size" {
    default = 1
}

variable "gke_default_nodepool_machine_type" {
    default = "e2-medium"
}

variable "gke_use_preemptible_nodes" {
    default = false
}

variable "gke_nodepools" {
  type = list(object({
    name=string
    initial_size=number,
    min_size=number,
    max_size=number,
    machine_type=string,
    use_preemptible_nodes=bool,
    taints=list(object({
      key=string,
      value=string,
      effect=string,
    })),
    labels=map(any),
  }))
  default = [
    {
      name="build-default" ,
      initial_size = 2,
      min_size = 0,
      max_size = 3,
      machine_type = "e2-medium",
      use_preemptible_nodes = false,
      taints = [],
      labels = {}
    }
  ]
}

variable "gke_private_cluster" {
    default = true
}

variable "gke_cluster_autoscaling_cpu_maximum" {
  default = 64
}

variable "gke_cluster_autoscaling_mem_maximum" {
  default = 256
}

variable "workload_identity_map" {
  type = map(any)
  default = {}
}