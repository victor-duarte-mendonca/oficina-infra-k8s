# Cada workspace (hml/prod) tem os seus dashboards, políticas e monitor, com o ambiente no nome.
locals {
  env    = terraform.workspace
  prefix = "${var.project_name}-${local.env}"

  # Nome do cluster no New Relic (nri-bundle, global.cluster em observability.tf da raiz).
  cluster = "${var.project_name}-${local.env}"

  # Nome do serviço nos traces OTLP (quarkus.application.name da aplicação).
  service = "oficina-mecanica"
}

# Mesma guarda da raiz: o workspace "default" não deve criar nada.
resource "terraform_data" "workspace_guard" {
  lifecycle {
    precondition {
      condition     = contains(["hml", "prod"], terraform.workspace)
      error_message = "Use o workspace hml ou prod (terraform workspace select -or-create hml)."
    }
  }
}
