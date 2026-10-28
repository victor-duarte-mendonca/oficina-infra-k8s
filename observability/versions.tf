terraform {
  required_version = ">= 1.10"

  required_providers {
    newrelic = {
      source  = "newrelic/newrelic"
      version = "~> 3.60"
    }
  }
}

# Credenciais por variável de ambiente (TF_VAR_newrelic_api_key, TF_VAR_newrelic_account_id), nunca em arquivo.
# A User API key (NRAK-...) é diferente da licença de ingestão dos agentes, que vive na raiz do repositório.
provider "newrelic" {
  account_id = var.newrelic_account_id
  api_key    = var.newrelic_api_key
  region     = "US"
}
