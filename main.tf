locals {
  project_id = "drebes-lab-gke-iap-cip-816d"
  region     = "europe-west6"
}

resource "google_project_iam_binding" "gkedev_project_roles" {
  project  = local.project_id
  for_each = toset(["roles/compute.viewer", "roles/container.clusterViewer"])
  role     = each.key
  members = [
    "group:gke-devs@drebes.dev",
  ]
}

resource "google_project_iam_binding" "gkeops_project_roles" {
  project  = local.project_id
  for_each = toset(["roles/container.admin"])
  role     = each.key
  members = [
    "group:gke-ops@drebes.dev",
  ]
}

module "vpc" {
  source     = "github.com/terraform-google-modules/cloud-foundation-fabric//modules/net-vpc?ref=v14.0.0"
  project_id = local.project_id
  name       = "gke-lab-net"
  subnets = [
    {
      ip_cidr_range = "10.1.1.0/24"
      name          = "green"
      region        = local.region
      secondary_ip_range = {
        pods     = "172.16.16.0/20"
        services = "192.168.1.0/24"
      }
    },
    {
      ip_cidr_range = "10.1.0.0/24"
      name          = "blue"
      region        = local.region
      secondary_ip_range = {
        pods     = "172.16.0.0/20"
        services = "192.168.0.0/24"
      }
    },
    {
      ip_cidr_range      = "10.0.0.0/24"
      name               = "bastion"
      region             = local.region
      secondary_ip_range = {}
    }
  ]
}

module "firewall" {
  source              = "github.com/terraform-google-modules/cloud-foundation-fabric//modules/net-vpc-firewall?ref=v14.0.0"
  project_id          = local.project_id
  network             = module.vpc.self_link
  admin_ranges        = []
  http_source_ranges  = []
  https_source_ranges = []
  ssh_source_ranges   = []
  custom_rules = {
    allow-ssh = {
      description          = "Allow SSH from internet."
      direction            = "INGRESS"
      action               = "allow"
      sources              = []
      ranges               = ["0.0.0.0/0"]
      targets              = []
      use_service_accounts = false
      rules                = [{ protocol = "tcp", ports = [22] }]
      extra_attributes     = {}
    }
    allow-hcs = {
      description          = "Allow health checks to all nodes."
      direction            = "INGRESS"
      action               = "allow"
      sources              = []
      ranges               = ["130.211.0.0/22", "35.191.0.0/16"]
      targets              = []
      use_service_accounts = false
      rules                = [{ protocol = "tcp", ports = ["0-65535"] }]
      extra_attributes     = {}
    }
  }
}

module "addresses" {
  source     = "github.com/terraform-google-modules/cloud-foundation-fabric//modules/net-address?ref=v14.0.0"
  project_id = local.project_id
  external_addresses = {
    bastion = local.region
  }
}


module "bastion-sa" {
  source     = "github.com/terraform-google-modules/cloud-foundation-fabric//modules/iam-service-account?ref=v14.0.0"
  project_id = local.project_id
  name       = "bastion-vm"
  iam = {
    "roles/iam.serviceAccountUser" = ["group:gke-devs@drebes.dev"]
  }
}

module "gke-sa" {
  source     = "github.com/terraform-google-modules/cloud-foundation-fabric//modules/iam-service-account?ref=v14.0.0"
  project_id = local.project_id
  name       = "gke-vm"
  iam_project_roles = {
    (local.project_id) = [
      "roles/logging.logWriter",
      "roles/monitoring.metricWriter",
    ]
  }
}

module "bastion-vm" {
  source     = "github.com/terraform-google-modules/cloud-foundation-fabric//modules/compute-vm?ref=v14.0.0"
  project_id = local.project_id
  zone       = "europe-west6-b"
  name       = "bastion"
  network_interfaces = [{
    network    = module.vpc.self_link
    subnetwork = module.vpc.subnet_self_links["europe-west6/bastion"]
    nat        = true
    addresses = {
      internal = null
      external = module.addresses.external_addresses["bastion"].address
    }
  }]
  iam = {
    "roles/compute.osLogin" = ["group:gke-devs@drebes.dev"]
  }
  service_account        = module.bastion-sa.email
  service_account_scopes = ["cloud-platform"]
}


module "cluster-green" {
  source                       = "github.com/terraform-google-modules/cloud-foundation-fabric//modules/gke-cluster?ref=v14.0.0"
  authenticator_security_group = "gke-security-groups@drebes.dev"
  default_max_pods_per_node    = 32
  labels = {
    environment = "green"
  }
  location = local.region
  name     = "cluster-green"
  network  = module.vpc.self_link
  private_cluster_config = {
    enable_private_nodes    = true
    enable_private_endpoint = false
    master_ipv4_cidr_block  = "192.168.255.240/28"
    master_global_access    = false
  }
  project_id               = local.project_id
  secondary_range_pods     = "pods"
  secondary_range_services = "services"
  subnetwork               = module.vpc.subnet_self_links["europe-west6/green"]
}

module "cluster-green-nodepool" {
  source               = "github.com/terraform-google-modules/cloud-foundation-fabric//modules/gke-nodepool?ref=v14.0.0"
  project_id           = local.project_id
  cluster_name         = module.cluster-green.name
  location             = module.cluster-green.location
  name                 = "nodepool"
  node_locations       = ["europe-west6-a"]
  initial_node_count   = 3
  node_service_account = module.gke-sa.email
}

module "cluster-blue" {
  source                       = "github.com/terraform-google-modules/cloud-foundation-fabric//modules/gke-cluster?ref=v14.0.0"
  authenticator_security_group = "gke-security-groups@drebes.dev"
  default_max_pods_per_node    = 32
  labels = {
    environment = "blue"
  }
  location = local.region
  name     = "cluster-blue"
  network  = module.vpc.self_link
  private_cluster_config = {
    enable_private_nodes    = true
    enable_private_endpoint = false
    master_ipv4_cidr_block  = "192.168.255.224/28"
    master_global_access    = false
  }
  project_id               = local.project_id
  secondary_range_pods     = "pods"
  secondary_range_services = "services"
  subnetwork               = module.vpc.subnet_self_links["europe-west6/blue"]
}

module "cluster-green-blue" {
  source               = "github.com/terraform-google-modules/cloud-foundation-fabric//modules/gke-nodepool?ref=v14.0.0"
  project_id           = local.project_id
  cluster_name         = module.cluster-blue.name
  location             = module.cluster-blue.location
  name                 = "nodepool"
  node_locations       = ["europe-west6-b"]
  initial_node_count   = 3
  node_service_account = module.gke-sa.email
}

module "ingress_addresses" {
  source           = "github.com/terraform-google-modules/cloud-foundation-fabric//modules/net-address?ref=v14.0.0"
  project_id       = local.project_id
  global_addresses = ["ingress-blue", "ingress-green"]
}


resource "google_compute_security_policy" "edge_policy" {
  name    = "edge-policy"
  project = local.project_id
  type    = "CLOUD_ARMOR_EDGE"
  rule {
    action   = "allow"
    priority = "1000"
    match {
      versioned_expr = "SRC_IPS_V1"
      config {
        src_ip_ranges = ["81.6.32.0/20"]
      }
    }
    description = "Allow access from specific range"
  }

  rule {
    action   = "deny(403)"
    priority = "2147483647"

    match {
      versioned_expr = "SRC_IPS_V1"
      config {
        src_ip_ranges = ["*"]
      }
    }
    description = "Deny access to everyone else"
  }
}
