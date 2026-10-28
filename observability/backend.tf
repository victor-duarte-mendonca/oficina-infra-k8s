# State separado da infraestrutura (a raiz do repositório): um problema na API do New Relic nunca
# trava o apply da EC2/k3s. Mesmo bucket da raiz (oficina-tfstate-<account-id>, via -backend-config),
# chave própria: oficina/observability/<workspace>/terraform.tfstate.
terraform {
  backend "s3" {
    key                  = "terraform.tfstate"
    workspace_key_prefix = "oficina/observability"
    region               = "us-east-1"
    use_lockfile         = true
    encrypt              = true
  }
}
