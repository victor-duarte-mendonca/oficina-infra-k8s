terraform {
  # 1.10 é o piso por causa de "use_lockfile" no backend S3 (backend.tf).
  required_version = ">= 1.10"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.60"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
  }
}

provider "aws" {
  region = var.aws_region

  # Toda a identificação de recursos em um lugar só: sem isto, as tags ficavam
  # dependentes de cada resource lembrar de repeti-las, e a varredura de órfãos do
  # workflow de destroy (que filtra por tag Project/Environment) perdia recursos.
  default_tags {
    tags = {
      Project     = var.project_name
      ManagedBy   = "terraform"
      Environment = terraform.workspace
    }
  }
}
