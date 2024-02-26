#  1. EKS Cluster IAM Role

resource "aws_iam_role" "eks_cluster_iam_role" {
  name = "eks-cluster-iam-role"
  assume_role_policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "eks.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
POLICY
}

# 2. IAM Role policy 

resource "aws_iam_role_policy_attachment" "AmazonEKSClusterPolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.eks_cluster_iam_role.name
}

# 3. EKS Cluster

resource "aws_eks_cluster" "my_eks_cluster" {
  name     = "temprmn-eks-cluster"
  role_arn =  aws_iam_role.eks_cluster_iam_role.arn 
  version = "1.29"
  vpc_config {
    security_group_ids = [data.aws_security_group.my_sg_web.id]         
    subnet_ids         = concat(data.aws_subnet.my_pvt_2a[*].id, data.aws_subnet.my_pvt_2c[*].id) # 두 개 이상 배열 결합, [*]는 해당 데이터 소스로부터 반환된 모든 요소를 나열하도록 Terraform에 지시합니다.
    endpoint_private_access = true # 동일 vpc 내 private ip간 통신허용
    endpoint_public_access = false 
   }
  }

# 4. Node Group IAM Role

resource "aws_iam_role" "eks_node_iam_role" {
  name = "eks-node-iam-role"
  assume_role_policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
POLICY
}

# iam role policy

resource "aws_iam_role_policy_attachment" "AmazonEKSWorkerNodePolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.eks_node_iam_role.name
}

resource "aws_iam_role_policy_attachment" "AmazonEKS_CNI_Policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.eks_node_iam_role.name
}

resource "aws_iam_role_policy_attachment" "AmazonEC2ContainerRegistryReadOnly" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.eks_node_iam_role.name
}

# 5. EKS Node Group

resource "aws_eks_node_group" "eks_node_group" {
  cluster_name    = aws_eks_cluster.my_eks_cluster.name
  node_group_name = "worker-node-group"
  node_role_arn   = aws_iam_role.eks_node_iam_role.arn
  subnet_ids      = concat(data.aws_subnet.my_pvt_2a[*].id, data.aws_subnet.my_pvt_2c[*].id)
  instance_types = ["t2.micro"]
  capacity_type  = "ON_DEMAND"
  remote_access {
#    source_security_group_ids = [data.aws_security_group.my_sg_web.id]
    ec2_ssh_key               = "my-key"
  }
  labels = {
    "role" = "eks_node_iam_role"
  }
  scaling_config {
    desired_size = 2
    min_size     = 2
    max_size     = 4
    }
  depends_on = [
    aws_iam_role_policy_attachment.AmazonEKSWorkerNodePolicy,
    aws_iam_role_policy_attachment.AmazonEKS_CNI_Policy,
    aws_iam_role_policy_attachment.AmazonEC2ContainerRegistryReadOnly,
  ]
}
