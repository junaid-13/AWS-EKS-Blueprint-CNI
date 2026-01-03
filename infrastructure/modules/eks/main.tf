locals {
  name   = basename(path.cwd)
  region = "us-east-1"

  vpc_cidr = "10.0.0.0/16"
  azs      = slice(data.aws_availability_zones.available.names, 0, 3)

  tags = {
    Blueprint  = local.name
    GithubRepo = "github.com/junaid-13/AWS-EKS-Blueprint-CNI"
  }
}

##########################################
# EKS Cluster
##########################################

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = ">=21.0"

  name                   = local.name
  kubernetes_version     = "1.33"
  endpoint_public_access = true

  enable_cluster_creator_admin_permissions = true
  vpc_id                                   = module.vpc.vpc_id
  subnet_ids                               = module.vpc.private_subnets

  eks_managed_node_groups = {
    initial = {
      instance_types = ["t3.medium"]
      min_size       = 1
      max_size       = 10
      desired_size   = 2
    }
  }
  tags = local.tags
}

##########################################
# EKS Addons (demo application)
##########################################

module "Addons" {
  source  = "aws-ia/eks-blueprints-addons/aws"
  version = "~>1.23"

  cluster_name      = module.eks.cluster_name
  cluster_endpoint  = module.eks.cluster_endpoint
  cluster_version   = module.eks.cluster_version
  oidc_provider_arn = module.eks.oidc_provider_arn

  eks_addons = {
    coredns    = {}
    kube-proxy = {}
    vpc-cni = {
      most_recent = true

      timeouts = {
        create = "25m"
        delete = "15m"
      }

      configuration_values = jsonencode({
        enableNetworkPolicy = true
      })
    }
  }
  helm_releases = {
    demo-application = {
      description = "A demo application to test the CNI network policies"
      namespace   = "default"
      chart       = "./charts/demo-application"

    }
  }
  tags = local.tags
}

##########################################
# Restrict traffic flow using network policies
##########################################

# Block all ingress and egress traffic within stars namespace
resource "kubernetes_network_policy_v1" "default_deny_stars" {
  metadata {
    name      = "default-deny"
    namespace = "stars"
  }
  spec {
    policy_types = ["Ingress"]
    pod_selector {
      match_labels = {}
    }
  }
  depends_on = [module.Addons]
}

# Block all ingress and egress traffic within the client namespace
resource "kubernetes_network_policy_v1" "default_deny_client" {
  metadata {
    name      = "default-deny"
    namespace = "client"
  }
  spec {
    policy_types = ["Ingress"]
    pod_selector {
      match_labels = {

      }
    }
  }
  depends_on = [module.Addons]
}

# Allow the management-ui to access the star application pods
resource "kubernetes_network_policy_v1" "allow_ui_to_stars" {
  metadata {
    name      = "allow-ui"
    namespace = "stars"
  }
  spec {
    policy_types = ["Ingress"]
    pod_selector {
      match_labels = {}
    }
    ingress {
      from {
        namespace_selector {
          match_labels = {
            role = "management-ui"
          }
        }
      }
    }
  }
  depends_on = [module.Addons]
}

# Allow the management-ui to access the client application pods
resource "kubernetes_network_policy_v1" "allow_ui_to_client" {
  metadata {
    name      = "allow-ui"
    namespace = "client"
  }
  spec {
    policy_types = ["Ingress"]
    pod_selector {
      match_labels = {
      }
    }
    ingress {
      from {
        namespace_selector {
          match_labels = {
            role = "management-ui"
          }
        }
      }
    }
  }
  depends_on = [module.Addons]
}

# Allow the frontend pod to access the backend pod within the stars namespace
resource "kubernetes_network_policy_v1" "allow_frontend_to_backend" {
  metadata {
    name      = "backend-policy"
    namespace = "stars"
  }
  spec {
    policy_types = ["Ingress"]
    pod_selector {
      match_labels = {
        role = "backend"
      }
    }
    ingress {
      from {
        pod_selector {
          match_labels = {
            role = "frontend"
          }
        }
      }
      ports {
        protocol = "TCP"
        port     = "6379"
      }
    }
  }
  depends_on = [module.Addons]
}

# Allow the client pod to access the frontend pod within the stars namespace
resource "kubernetes_network_policy_v1" "allow_client_to_backend" {
  metadata {
    name      = "frontend-policy"
    namespace = "stars"
  }

  spec {
    policy_types = ["Ingress"]
    pod_selector {
      match_labels = {
        role = "frontend"
      }
    }
    ingress {
      from {
        namespace_selector {
          match_labels = {
            role = "client"
          }
        }
      }
      ports {
        protocol = "TCP"
        port     = "80"
      }
    }
  }
  depends_on = [module.Addons]
}