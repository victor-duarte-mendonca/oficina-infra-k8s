# State remoto em S3, um por workspace (hml/prod):
#   s3://<bucket>/oficina/infra-k8s/<workspace>/terraform.tfstate
#
# O nome do bucket NÃO é fixo: nomes de S3 são globais e a conta AWS Academy é reciclada
# (conta nova = ID novo), então um nome literal colidia ou apontava para um bucket morto.
# Convenção: oficina-tfstate-<account-id>. Informado em tempo de init:
#   terraform init -backend-config="bucket=oficina-tfstate-$(aws sts get-caller-identity --query Account --output text)"
# O bucket é criado por scripts/bootstrap-state-bucket.sh (idempotente).
terraform {
  backend "s3" {
    key                  = "terraform.tfstate"
    workspace_key_prefix = "oficina/infra-k8s"
    region               = "us-east-1"

    # Trava de state nativa do S3 (Terraform >= 1.10): grava um .tflock ao lado do
    # state e falha rápido se outro apply estiver em andamento. Sem isto, dois
    # applies concorrentes — o da pipeline e o da sua máquina, cenário real neste
    # projeto — podem corromper o state. Substitui a antiga tabela DynamoDB, que a
    # conta AWS Academy nem sempre permite criar.
    use_lockfile = true

    # O state guarda a chave privada da EC2 em texto. Criptografia no lado do
    # servidor é obrigatória.
    encrypt = true
  }
}
