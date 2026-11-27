# force_delete = true: sem isso, "terraform destroy" falha se houver imagem dentro do repositório,
# exigindo remoção manual antes — risco real de virar recurso órfão numa sessão apressada de 4h.
resource "aws_ecr_repository" "main" {
  name                 = "${local.name_prefix}-app"
  image_tag_mutability = "MUTABLE"
  force_delete         = true

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = { Name = "${local.name_prefix}-ecr" }
}

# Fase 4: um repositorio por servico (spec 11 §2: pipelines independentes, imagem e rollback por servico).
# O "main" acima continua sendo o do OS Service (nao renomear: mudaria o endereco no state e recriaria o repositorio).
resource "aws_ecr_repository" "services" {
  for_each = toset(["billing", "execution"])

  name                 = "${local.name_prefix}-${each.key}"
  image_tag_mutability = "MUTABLE"
  force_delete         = true

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = { Name = "${local.name_prefix}-${each.key}-ecr" }
}
