# gke-nap-gitlab-runner

Gitlab runner provisioning dynamic pods on GKE Standard and [node auto provisioning](https://cloud.google.com/kubernetes-engine/docs/how-to/node-auto-provisioning).

# Pre-requisites

- a GCP project with billing attached
- terraform
- gitlab

# Terraform

Here's a sample terraform.tfvars file that creates a VPC in the project and a GKE cluster with Node Auto Provisioning on it.  The cluster will scale up to a maximum of 64 CPU and 256GB memory total.

```
shared_vpc_network = "gitlab-runner-vpc"
service_project_id = "jkwng-build-cluster"

subnets = [
{
    name = "build-central1"
    primary_range = "10.6.0.0/24"
    region = "us-central1"
    secondary_range = {
      "pods" = "10.106.0.0/16",
      "services" = "10.6.1.0/24",
    }
  },
]

service_project_apis_to_enable = [
    "compute.googleapis.com",
    "container.googleapis.com",
    "containerregistry.googleapis.com",
]

gke_cluster_name = "build-cluster"
gke_cluster_master_range = "10.3.2.0/28"
gke_cluster_location = "us-central1"

gke_cluster_autoscaling_cpu_maximum = 64
gke_cluster_autoscaling_mem_maximum = 256

gke_nodepools = [
  {
    name="build-default" ,
    initial_size = 2,
    min_size = 0,
    max_size = 3,
    machine_type = "e2-medium",
    use_preemptible_nodes = true,
    taints = [],
    labels = {}
  }
]

workload_identity_map = {
}
```

Run `terraform init` and then `terraform apply` to create the infrastructure.


# Install gitlab runner

Run this to get the kube context to connect to the cluster:

```bash
$ gcloud container clusters get-credentials <cluster-name> --region <region> --project <project> 
```

Fill in the [helm values file](./gitlab-runner-helm-values-c2.yaml) with your gitlab URL and runner token.  Note the machine types (In my config C2 machines will be created when pods show up) then helm install it to the cluster.

```bash
$ kubectl create namespace gitlab-runner
$ helm install --namespace gitlab-runner gitlab-runner gitlab/gitlab-runner --values ./gitlab-runner-helm-values-c2.yaml 
```

The runner itself runs on a default nodepool with `e2-medium` nodes.

# run a gitlab job

Here is a sample gradle job that runs on the runner. we specify the number of cores and memory in the requests/limits sections of the pods that we want the pod to be created with using the environment variables prefixed with `KUBERNETES_*`

```
integration_test_grpc_c2:
  stage: integration_test
  image: gradle:latest
  services:
  - mysql:5.7
  - name: elasticsearch:7.14.1
    command: ["bin/elasticsearch", "-Ediscovery.type=single-node", "-Expack.security.enabled=false"]
  variables:
    MYSQL_USER: "dbuser"
    MYSQL_PASSWORD: "dbpassword"
    MYSQL_ALLOW_EMPTY_PASSWORD: "true"
    MYSQL_DATABASE: "fruitshop"
    FRUITSHOP_PRODUCTSERVICE_ELASTICSEARCH_HOSTNAME: "elasticsearch"
    FRUITSHOP_PRODUCTSERVICE_ELASTICSEARCH_PORT: "9200"
    ES_JAVA_OPTS: "-Xms2G -Xmx2G"
    SPRING_DATASOURCE_URL: "jdbc:mysql://mysql:3306/fruitshop?createDatabaseIfNotExist=true&enabledTLSProtocols=TLSv1.2"
    KUBERNETES_CPU_REQUEST: 1 
    KUBERNETES_CPU_LIMIT: 1
    KUBERNETES_MEMORY_REQUEST: "2Gi"
    KUBERNETES_MEMORY_LIMIT: "2Gi"
    KUBERNETES_EPHEMERAL_STORAGE_REQUEST: "512Mi"
    KUBERNETES_EPHEMERAL_STORAGE_LIMIT: "512Mi"
    KUBERNETES_HELPER_CPU_REQUEST: "500m"
    KUBERNETES_HELPER_CPU_LIMIT: "500m" 
    KUBERNETES_HELPER_MEMORY_REQUEST: "128Mi"
    KUBERNETES_HELPER_MEMORY_LIMIT: "128Mi"
    KUBERNETES_HELPER_EPHEMERAL_STORAGE_REQUEST: "1Gi"
    KUBERNETES_HELPER_EPHEMERAL_STORAGE_LIMIT: "1Gi"
    KUBERNETES_SERVICE_CPU_REQUEST: 1
    KUBERNETES_SERVICE_CPU_LIMIT: 1
    KUBERNETES_SERVICE_MEMORY_REQUEST: "4Gi"
    KUBERNETES_SERVICE_MEMORY_LIMIT: "4Gi"
    KUBERNETES_SERVICE_EPHEMERAL_STORAGE_REQUEST: "10Gi"
    KUBERNETES_SERVICE_EPHEMERAL_STORAGE_LIMIT: "10Gi"
  script:
  - gradle -x test integrationTest --info --tests com.jkwong.fruitshop.product.test.TestProductServiceClientGrpcIT
```

When the job begins, the runner creates a pod.  Cluster autoscaler will notice the pending pod and provision a nodepool with a machine type that can execute the pod according to the requests/limits of the pod.  When the pod exits, the cluster autoscaler with `OPTIMIZE_UTILIZATION` will scale down the node hosting the pod.  When the nodepool contains no nodes, the nodepool is also removed.

Note the nodeSelector the gitlab-runner adds to the pod, `cloud.google.com/machine-family` will control the machine type created.  For integration test jobs that are heavy CPU and memory utilization, we may choose C2 class machines, while other workloads may use N2 or E2 machines.  We can choose the machine class by installing several instances of the gitlab runner which run differently tagged jobs.