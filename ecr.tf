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
