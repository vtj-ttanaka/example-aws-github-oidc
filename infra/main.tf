# https://github.com/terraform-aws-modules/terraform-aws-iam/tree/master/modules/iam-assumable-role-with-oidc
# https://github.com/terraform-aws-modules/terraform-aws-ecr

terraform {
  required_version = ">= 1.2"
  required_providers {
    aws = {
      source = "hashicorp/aws"
    }
  }
}

provider "aws" {
  region     = "ap-northeast-1"
  access_key = var.access_key
  secret_key = var.secret_key
}

data "http" "github_actions_openid_configuration" {
  url = "https://token.actions.githubusercontent.com/.well-known/openid-configuration"
}

data "tls_certificate" "github_actions" {
  url = jsondecode(data.http.github_actions_openid_configuration.body).jwks_uri
  # url = "https://token.actions.githubusercontent.com/.well-known/jwks"
}

resource "aws_iam_openid_connect_provider" "github_actions" {
  url             = "https://token.actions.githubusercontent.com"
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.github_actions.certificates[0].sha1_fingerprint]
}

module "iam_assumable_role_with_oidc" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-assumable-role-with-oidc"
  version = "5.3.0"

  create_role = true

  role_name = "role-with-oidc"

  tags = {
    Terraform = "true"
    Role      = "role-with-oidc"
  }

  provider_url = "token.actions.githubusercontent.com"

  role_policy_arns = [
    "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryFullAccess",
  ]
}

module "private_ecr" {
  source  = "terraform-aws-modules/ecr/aws"
  version = "1.4.0"

  repository_name = var.repository_name
  repository_type = "private"

  repository_read_write_access_arns = [module.iam_assumable_role_with_oidc.iam_role_arn]
  repository_lifecycle_policy = jsonencode({
    rules = [
      {
        rulePriority = 1,
        description  = "Keep last 10 images",
        selection = {
          tagStatus     = "tagged",
          tagPrefixList = ["v"],
          countType     = "imageCountMoreThan",
          countNumber   = 10
        },
        action = {
          type = "expire"
        }
      }
    ]
  })

  tags = {
    Terraform   = "true"
    Envrionment = "example"
  }
}
