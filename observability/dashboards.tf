# Dashboards versionados como JSON (spec 05 §7): dashboard criado só pela interface se perde no
# primeiro acidente e não passa por revisão. O JSON é um template; os placeholders são resolvidos aqui.
locals {
  dashboard_vars = {
    account_id = var.newrelic_account_id
    env        = local.env
    cluster    = local.cluster
    service    = local.service
    prefix     = local.prefix
  }
}

resource "newrelic_one_dashboard_json" "negocio" {
  json = templatefile("${path.module}/dashboards/negocio.json.tftpl", local.dashboard_vars)
}

resource "newrelic_one_dashboard_json" "operacao" {
  json = templatefile("${path.module}/dashboards/operacao.json.tftpl", local.dashboard_vars)
}
