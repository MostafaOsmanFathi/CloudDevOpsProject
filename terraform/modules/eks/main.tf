data "aws_caller_identity" "current" {}

# -----------------------------------------------------------------------------
# IAM roles
# -----------------------------------------------------------------------------

data "aws_iam_policy_document" "cluster_assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["eks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "cluster" {
  name               = "${var.cluster_name}-cluster-role"
  assume_role_policy = data.aws_iam_policy_document.cluster_assume_role.json

  tags = merge(var.tags, {
    Name = "${var.cluster_name}-cluster-role"
  })
}

resource "aws_iam_role_policy_attachment" "cluster" {
  role       = aws_iam_role.cluster.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}

data "aws_iam_policy_document" "node_assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "node" {
  name               = "${var.cluster_name}-node-role"
  assume_role_policy = data.aws_iam_policy_document.node_assume_role.json

  tags = merge(var.tags, {
    Name = "${var.cluster_name}-node-role"
  })
}

resource "aws_iam_role_policy_attachment" "node" {
  for_each = toset([
    "AmazonEKSWorkerNodePolicy",
    "AmazonEKS_CNI_Policy",
    "AmazonEC2ContainerRegistryReadOnly",
  ])

  role       = aws_iam_role.node.name
  policy_arn = "arn:aws:iam::aws:policy/${each.value}"
}

# -----------------------------------------------------------------------------
# Control plane
# -----------------------------------------------------------------------------

resource "aws_eks_cluster" "this" {
  name     = var.cluster_name
  role_arn = aws_iam_role.cluster.arn
  version  = var.kubernetes_version != "" ? var.kubernetes_version : null

  enabled_cluster_log_types = ["api", "audit", "authenticator", "controllerManager", "scheduler"]

  vpc_config {
    subnet_ids              = var.private_subnet_ids
    endpoint_private_access = true
    endpoint_public_access  = var.endpoint_public_access
    public_access_cidrs     = var.endpoint_public_access ? var.endpoint_public_cidrs : null
  }

  depends_on = [aws_iam_role_policy_attachment.cluster]

  tags = merge(var.tags, {
    Name = var.cluster_name
  })
}

# -----------------------------------------------------------------------------
# Worker nodes - one node group per private subnet, so the two workers run in
# different availability zones
# -----------------------------------------------------------------------------

resource "aws_eks_node_group" "workers" {
  for_each = var.private_subnet_ids_by_az

  cluster_name    = aws_eks_cluster.this.name
  node_group_name = "${var.cluster_name}-workers-${each.key}"
  node_role_arn   = aws_iam_role.node.arn
  subnet_ids      = [each.value]
  ami_type        = var.node_ami_type
  instance_types  = var.node_instance_types
  capacity_type   = "ON_DEMAND"

  scaling_config {
    desired_size = var.node_desired_size
    min_size     = var.node_min_size
    max_size     = var.node_max_size
  }

  update_config {
    max_unavailable = 1
  }

  labels = {
    "node-role" = "worker"
  }

  depends_on = [aws_iam_role_policy_attachment.node]

  tags = merge(var.tags, {
    Name        = "${var.cluster_name}-workers-${each.key}"
    Environment = each.key
  })
}

# -----------------------------------------------------------------------------
# Managed addons
# -----------------------------------------------------------------------------

resource "aws_eks_addon" "this" {
  for_each = toset(var.enabled_addons)

  cluster_name  = aws_eks_cluster.this.name
  addon_name    = each.value
  addon_version = data.aws_eks_addon_version.this[each.value].version

  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"

  depends_on = [aws_eks_node_group.workers]
}

data "aws_eks_addon_version" "this" {
  for_each = toset(var.enabled_addons)

  addon_name         = each.value
  kubernetes_version = aws_eks_cluster.this.version
  most_recent        = true
}
