# Cada workspace é uma stack fisicamente separada (spec 06 §4). O workspace "default" é
# propositalmente inválido: "terraform plan" falha com 'Invalid index' em vez de criar
# recursos sem ambiente definido.
locals {
  env = terraform.workspace

  environments = {
    hml = {
      instance_type = "t3.small" # 2 GiB — comporta k3s + 2 réplicas; sem nri-bundle completo (spec 06 §4.3)
      volume_size   = 20
    }
    prod = {
      instance_type = "t3.medium" # 4 GiB — comporta k3s + 4 réplicas + observabilidade completa
      volume_size   = 20
    }
  }

  config        = local.environments[local.env]
  instance_type = coalesce(var.instance_type_override, local.config.instance_type)

  # Prefixo único por stack: key pair, security group e ECR têm nome único na região,
  # e hml/prod coexistem na mesma conta.
  name_prefix = "${var.project_name}-${local.env}"
}
