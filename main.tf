/*
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"
    }
  }
}
# Configure the AWS Provider
provider "aws" {
  region = "eu-west-3"
}
*/
########################### VPC #########################################################
resource "aws_vpc" "project-vpc" {
  cidr_block       = "10.0.0.0/16"
  instance_tenancy = "default"
  tags = {
    Name = "project-vpc"
  }
}
################################# subnets ###############################################
resource "aws_subnet" "projet-private-subnet-1" {
  vpc_id     = aws_vpc.project-vpc.id
  cidr_block = "10.0.0.0/24"
  availability_zone = "eu-west-3a"
  tags = {
    Name = "projet-private-subnet-1"
  }
}
resource "aws_subnet" "projet-private-subnet-2" {
  vpc_id     = aws_vpc.project-vpc.id
  cidr_block = "10.0.1.0/24"
  availability_zone = "eu-west-3b"
  tags = {
    Name = "projet-private-subnet-2"
  }
}
resource "aws_subnet" "projet-private-subnet-3" {
  vpc_id     = aws_vpc.project-vpc.id
  cidr_block = "10.0.2.0/24"
  availability_zone = "eu-west-3c"
  tags = {
    Name = "projet-private-subnet-3"
  }
}
# public subnet qui contient l'instance EC2 et la nat-gateway pour gérer le traffic vers 0.0.0.0 des private-subnets
resource "aws_subnet" "projet-public-subnet-1" {
  vpc_id     = aws_vpc.project-vpc.id
  cidr_block = "10.0.3.0/24"
  map_public_ip_on_launch = true
  tags = {
    Name = "projet-public-subnet-1"
  }
}
############################ internet gateway ############################################
# création d'une internet gateway
resource "aws_internet_gateway" "projet-igatew" {
  vpc_id = aws_vpc.project-vpc.id
  tags = {
    Name        = "projet-igatew"
  }
  depends_on = [aws_vpc.project-vpc]
}
############## table de routage et route pour le réseau public vers 0.0.0.0 ##############
resource "aws_route_table" "projet-rt-public-subnet-1" {
  vpc_id = aws_vpc.project-vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id             = aws_internet_gateway.projet-igatew.id
  }
  tags = {
    Name = "projet-rt-public-subnet-1"
  }
}
############## Ajouter le sous-réseau public à la table de routage #######################
resource "aws_route_table_association" "projet-rt-association-public-subnet" {
  subnet_id      = aws_subnet.projet-public-subnet-1.id
  route_table_id = aws_route_table.projet-rt-public-subnet-1.id
  depends_on = [aws_route_table.projet-rt-public-subnet-1]
}

############################ nat gateway et Elastic IP####################################
resource "aws_eip" "projet-nat-gw-eip" {
  vpc = true
}
resource "aws_nat_gateway" "projet-nat-gw" {
  allocation_id = aws_eip.projet-nat-gw-eip.id
  subnet_id     = aws_subnet.projet-public-subnet-1.id
  tags = {
      Name = "projet-nat-gw-eip"
        }
    }

############### route table et route pour le réseau privé 1 vers la nat ##################
resource "aws_route_table" "projet-rt-private-subnet-1" {
  vpc_id = aws_vpc.project-vpc.id
  route {
    cidr_block = "10.0.0.0/24"
    nat_gateway_id = aws_nat_gateway.projet-nat-gw.id
  }
  tags = {
    Name = "projet-rt-private-subnet-1"
  }
}
############## Ajouter le sous-réseaux privé 1 à la table de routage 1 #######################
resource "aws_route_table_association" "projet-rt-association-private-subnet-1" {
  subnet_id      = aws_subnet.projet-private-subnet-1.id
  route_table_id = aws_route_table.projet-rt-private-subnet-1.id
}

############### route table et route pour le réseau privé 2 vers la nat ##################
resource "aws_route_table" "projet-rt-private-subnet-2" {
  vpc_id = aws_vpc.project-vpc.id
  route {
    cidr_block = "10.0.0.0/24"
    nat_gateway_id = aws_nat_gateway.projet-nat-gw.id
  }
  tags = {
    Name = "projet-rt-private-subnet-2"
  }
}

############## Ajouter le sous-réseaux privé 2 à la table de routage 2 #######################
resource "aws_route_table_association" "projet-rt-association-private-subnet-2" {
  subnet_id      = aws_subnet.projet-private-subnet-2.id
  route_table_id = aws_route_table.projet-rt-private-subnet-2.id
}

############### route table et route pour le réseau privé 3 vers la nat ##################
resource "aws_route_table" "projet-rt-private-subnet-3" {
  vpc_id = aws_vpc.project-vpc.id
  route {
    cidr_block = "10.0.0.0/24"
    nat_gateway_id = aws_nat_gateway.projet-nat-gw.id
  }
  tags = {
    Name = "projet-rt-private-subnet-3"
  }
}

############## Ajouter le sous-réseaux privé 3 à la table de routage 3#######################
resource "aws_route_table_association" "projet-rt-association-private-subnet-3" {
  subnet_id      = aws_subnet.projet-private-subnet-3.id
  route_table_id = aws_route_table.projet-rt-private-subnet-3.id
}

###################### creation de l'ec2 dans le réseau public ##########################

##### creation de la clé d'acces pour la machine
#resource "aws_key_pair" "projet-ec2key" {
#  key_name   = "projet-keypair"
#  public_key = "${file("~/.ssh/projet-keypair")}"
#}
##### création du security group de l'ec2. NB: normalement on doit restreindre les blocs CIDR pour limiter les ip d'acces
resource "aws_security_group" "projet-sg-port-22" {

  name   = "projet-sg-port-22"
  vpc_id = aws_vpc.project-vpc.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = "0"
    to_port     = "0"
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Name        = "projet-sg-port-22"
  }
}
##### création des NACL
resource "aws_network_acl" "projet-nacl-public-1" {
  vpc_id = aws_vpc.project-vpc.id

  subnet_ids = [aws_subnet.projet-public-subnet-1.id]

  tags = {
    Name        = "projet-nacl-public-1"
  }
}
resource "aws_network_acl_rule" "projet-nacl-rule-inbound-public-1" {
  network_acl_id = aws_network_acl.projet-nacl-public-1.id
  rule_number    = 200
  egress         = false
  protocol       = "-1"
  rule_action    = "allow"
  # L'ouverture à 0.0.0.0/0 peut entraîner des failles de sécurité. vous devez restreindre uniquement l'acces à votre ip publique
  cidr_block = "0.0.0.0/0"
  from_port  = 0
  to_port    = 0
  depends_on = [aws_network_acl.projet-nacl-public-1]
}
resource "aws_network_acl_rule" "projet-nacl-rule-outbound-public-1" {
  network_acl_id = aws_network_acl.projet-nacl-public-1.id
  rule_number    = 200
  egress         = true
  protocol       = "-1"
  rule_action    = "allow"
  # L'ouverture à 0.0.0.0/0 peut entraîner des failles de sécurité. vous devez restreindre uniquement l'acces à votre ip publique
  cidr_block = "0.0.0.0/0"
  from_port  = 0
  to_port    = 0
  depends_on = [aws_network_acl.projet-nacl-public-1]
}
##### creation de l'ec2 (bastion) avec récuperation de l'image AMI
/*
data "aws_ami" "projet-ec2-ami" { 
  most_recent = true          
  owners      = ["amazon"]    # Le proriétaire de l'image

  filter {                    
    name   = "name"
    values = ["*linux*2023*"]           
  }
}
*/
resource "aws_instance" "projet-ec2" {
#  ami                    = data.aws_ami.projet-ec2-ami.id
  ami                    = "ami-014571f1593b7be25"
  instance_type          = "t2.micro"
  subnet_id              = aws_subnet.projet-public-subnet-1.id
  vpc_security_group_ids = [aws_security_group.projet-sg-port-22.id]
  key_name               = "projet-keypair"

  tags = {
    Name        = "projet-ec2"
  }

}



############################ module EKS ##################################################

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 19.0"
  cluster_name    = "projet-cluster"
  cluster_version = "1.24"
  cluster_endpoint_public_access = true
  cluster_addons = {
    coredns = {
      most_recent = true
    }
    kube-proxy = {
      most_recent = true
    }
    vpc-cni = {
      most_recent = true
    }
  }
  vpc_id                   = aws_vpc.project-vpc.id
  subnet_ids               = ["${aws_subnet.projet-private-subnet-1.id}  ", "${aws_subnet.projet-private-subnet-2.id}", "${aws_subnet.projet-private-subnet-3.id}"]
  #control_plane_subnet_ids = ["subnet-xyzde987", "subnet-slkjf456", "subnet-qeiru789"]
  # Self Managed Node Group(s)
  self_managed_node_group_defaults = {
    instance_type                          = "t2.micro"
    update_launch_template_default_version = true
    iam_role_additional_policies = {
      AmazonSSMManagedInstanceCore = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
    }
  }
  self_managed_node_groups = {
    one = {
      name         = "projet-mixed-1"
      max_size     = 5
      desired_size = 2
      use_mixed_instances_policy = true
      mixed_instances_policy = {
        instances_distribution = {
          on_demand_base_capacity                  = 0
          on_demand_percentage_above_base_capacity = 10
          spot_allocation_strategy                 = "capacity-optimized"
        }
        override = [
          {
            instance_type     = "t2.micro"
            weighted_capacity = "1"
          },
          {
            instance_type     = "t2.micro"
            weighted_capacity = "2"
          },
        ]
      }
    }
  }
  # EKS Managed Node Group(s)
  eks_managed_node_group_defaults = {
    instance_types = ["t2.micro"]
  }
  eks_managed_node_groups = {
    blue = {}
    green = {
      min_size     = 1
      max_size     = 10
      desired_size = 1
      instance_types = ["t3.micro"]
      capacity_type  = "SPOT"
    }
  }
  # Fargate Profile(s)
  fargate_profiles = {
    default = {
      name = "default"
      selectors = [
        {
          namespace = "default"
        }
      ]
    }
  }
  # aws-auth configmap
  manage_aws_auth_configmap = true
  aws_auth_roles = [
    {
      rolearn  = "arn:aws:iam::66666666666:role/role1"
      username = "role1"
      groups   = ["system:masters"]
    },
  ]
  aws_auth_users = [
    {
      userarn  = "arn:aws:iam::66666666666:user/user1"
      username = "user1"
      groups   = ["system:masters"]
    },
    {
      userarn  = "arn:aws:iam::66666666666:user/user2"
      username = "user2"
      groups   = ["system:masters"]
    },
  ]
  aws_auth_accounts = [
    "777777777777",
    "888888888888",
  ]
  tags = {
    Environment = "dev"
    Terraform   = "true"
  }
}

