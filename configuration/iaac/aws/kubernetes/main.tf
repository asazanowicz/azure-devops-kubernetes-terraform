# aws --version
# aws eks --region us-east-1 update-kubeconfig --name in28minutes-cluster
# Uses default VPC and Subnet. Create Your Own VPC and Private Subnets for Prod Usage.
# terraform-backend-state-asazanowicz

terraform {
  backend "s3" {
    bucket = "mybucket" # Will be overridden from build
    key    = "path/to/my/key" # Will be overridden from build
    region = "eu-north-1"
  }
}

resource "aws_default_vpc" "default" {

}

data "aws_subnet_ids" "subnets" {
  vpc_id = aws_default_vpc.default.id
}

provider "kubernetes" {
  host                   = data.aws_eks_cluster.cluster.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.cluster.certificate_authority.0.data)
  token                  = data.aws_eks_cluster_auth.cluster.token
  load_config_file       = false
  version                = "~> 1.9"
}

module "asazanowicz-cluster" {
  source          = "terraform-aws-modules/eks/aws"
  cluster_name    = "k8s-cluster"
  cluster_version = "1.20"
  subnets         = ["subnet-18ef7c71", "subnet-7faf1d04"] #CHANGE
  #subnets = data.aws_subnet_ids.subnets.ids
  vpc_id          = aws_default_vpc.default.id

  #vpc_id         = "vpc-d67be9bf"

  worker_groups = [
    {
      name                          = "k8s-cluster-worker-group-1"
      instance_type                 = "t3.micro"
      #additional_userdata           = "echo foo bar"
      asg_desired_capacity          = 2
      #additional_security_group_ids = [aws_security_group.worker_group_mgmt_one.id]
    }
  ]

  # node_groups = [
  #   {
  #     instance_type = "t2.micro"
  #     max_capacity  = 5
  #     desired_capacity = 3
  #     min_capacity  = 3
  #   }
  # ]
}

data "aws_eks_cluster" "cluster" {
  name = module.asazanowicz-cluster.cluster_id
}

data "aws_eks_cluster_auth" "cluster" {
  name = module.asazanowicz-cluster.cluster_id
}


# We will use ServiceAccount to connect to K8S Cluster in CI/CD mode
# ServiceAccount needs permissions to create deployments 
# and services in default namespace
resource "kubernetes_cluster_role_binding" "example" {
  metadata {
    name = "fabric8-rbac"
  }
  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = "cluster-admin"
  }
  subject {
    kind      = "ServiceAccount"
    name      = "default"
    namespace = "default"
  }
}

# Needed to set the default region
provider "aws" {
  region  = "eu-north-1"
}