variable "project_name" {
  description = "Prefixo usado nos nomes dos recursos"
  type        = string
  default     = "oficina"
}

variable "newrelic_account_id" {
  description = "ID da conta New Relic (NEW_RELIC_ACCOUNT_ID)"
  type        = number
}

variable "alert_email" {
  description = "E-mail que recebe os alertas (canal gratuito, spec 05 §8)"
  type        = string

  validation {
    condition     = can(regex("^[^@ ]+@[^@ ]+[.][^@ ]+$", var.alert_email))
    error_message = "alert_email deve ser um endereço de e-mail válido."
  }
}

variable "gateway_url" {
  description = "URL base do API Gateway (SSM /oficina/<env>/api_gateway_url). Vazio = sem monitor Synthetics."
  type        = string
  default     = ""
}

variable "newrelic_api_key" {
  description = "User API key do New Relic (NRAK-...), com permissão para criar dashboards, alertas e monitores"
  type        = string
  sensitive   = true
}
