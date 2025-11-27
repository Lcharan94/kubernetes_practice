provider "aws" {
  region = "us-east-1"
}

# --------------------- IAM -----------------------

resource "aws_iam_role" "master" {
  name = "charan-eks-master"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = { Service = "eks.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "AmazonEKSClusterPolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.master.name
}

resource "aws_iam_role_policy_attachment" "AmazonEKSServicePolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSServicePolicy"
  role       = aws_iam_role.master.name
}

resource "aws_iam_role_policy_attachment" "AmazonEKSVPCResourceController" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSVPCResourceController"
  role       = aws_iam_role.master.name
}

resource "aws_iam_role" "worker" {
  name = "charan-eks-worker"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_instance_profile" "worker" {
  name = "charan-eks-worker-new-profile"
  role = aws_iam_role.worker.name
}

# ------------------- VPC / SUBNETs --------------------

data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "eks_subnets" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]   # FIXED
  }
}

data "aws_subnet" "filtered_subnets" {
  for_each = toset(data.aws_subnets.eks_subnets.ids)
  id       = each.value
}

locals {
  supported_subnets = [
    for s in data.aws_subnet.filtered_subnets :
    s.id if contains(["us-east-1a", "us-east-1b", "us-east-1c", "us-east-1d", "us-east-1f"], s.availability_zone)
  ]
}

data "aws_security_group" "default" {
  filter {
    name   = "group-name"
    values = ["default"]
  }
  vpc_id = data.aws_vpc.default.id
}

# ---------------------- EKS Cluster ----------------------

resource "aws_eks_cluster" "eks" {
  name     = "eks-project"
  role_arn = aws_iam_role.master.arn

  vpc_config {
    subnet_ids         = local.supported_subnets
    security_group_ids = [data.aws_security_group.default.id]
  }

  upgrade_policy {
    support_type = "STANDARD"
  }

  depends_on = [
    aws_iam_role_policy_attachment.AmazonEKSClusterPolicy,
    aws_iam_role_policy_attachment.AmazonEKSServicePolicy,
    aws_iam_role_policy_attachment.AmazonEKSVPCResourceController,
  ]
}

# ---------------------- Node Group -----------------------

resource "aws_eks_node_group" "node-grp" {
  cluster_name    = aws_eks_cluster.eks.name
  node_group_name = "node-group-project"
  node_role_arn   = aws_iam_role.worker.arn

  subnet_ids = local.supported_subnets   # FIXED

  capacity_type  = "ON_DEMAND"
  disk_size      = 20
  instance_types = ["t2.small"]

  scaling_config {
    desired_size = 2
    max_size     = 4
    min_size     = 1
  }

  update_config {
    max_unavailable = 1
  }
}
