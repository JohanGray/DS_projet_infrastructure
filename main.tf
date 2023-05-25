module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "3.14.3"
  name = "projet-vpc"
  cidr = "10.0.0.0/16"
  azs                    = ["eu-west-3a", "eu-west-3b"]
  private_subnets        = ["10.0.0.0/19", "10.0.32.0/19"]
  public_subnets         = ["10.0.64.0/19", "10.0.96.0/19"]
  enable_nat_gateway     = true
  single_nat_gateway     = false
  one_nat_gateway_per_az = true
  enable_dns_hostnames   = true
  enable_dns_support     = true
  tags = {
    Environment = "projet-DS"
  }
}
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "19.15.0"
  cluster_name    = "projet-eks"
  cluster_version = "1.24"
  cluster_endpoint_private_access = true
  cluster_endpoint_public_access  = true
  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets
  enable_irsa = true
  eks_managed_node_group_defaults = {
    disk_size = 50
  }
  eks_managed_node_groups = {
    general = {
      desired_size = 1
      min_size     = 1
      max_size     = 10
      labels = {
        role = "general"
      }
      instance_types = ["t2.micro"]
      capacity_type  = "ON_DEMAND"
    }
    spot = {
      desired_size = 1
      min_size     = 1
      max_size     = 10
      labels = {
        role = "spot"
      }
      taints = [{
        key    = "market"
        value  = "spot"
        effect = "NO_SCHEDULE"
      }]
      instance_types = ["t2.micro"]
      capacity_type  = "SPOT"
    }
  }
  tags = {
    Environment = "projet-Eks"
  }
}
module "ec2_instance" {
  source  = "terraform-aws-modules/ec2-instance/aws"

  name = "Projet-ec2"

  instance_type          = "t2.micro"
  key_name               = "projet-keypair"
  monitoring             = true
  subnet_id              = element(module.vpc.public_subnets, 0)
#  vpc_security_group_ids = [module.security_group.security_group_id]
  associate_public_ip_address = true

  tags = {
    Terraform   = "true"
    Environment = "Projet-DS"
  }
}
