# Uptime (spec 05 §6): ping monitor contra GET <api-gateway>/health a cada 5 min. É o único item
# que enxerga a aplicação de fora da VPC, passando pelo gateway como um cliente real.
resource "newrelic_synthetics_monitor" "health" {
  count = var.gateway_url == "" ? 0 : 1

  name             = local.health_monitor
  type             = "SIMPLE"
  status           = "ENABLED"
  period           = "EVERY_5_MINUTES"
  uri              = "${trimsuffix(var.gateway_url, "/")}/health"
  locations_public = ["AWS_US_EAST_1"]

  # /health responde 200 com {"status":"UP"} quando a aplicação e o banco estão de pé.
  validation_string = "UP"
}
