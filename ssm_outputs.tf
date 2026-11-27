# Contrato publicado para os outros repositórios (spec 06 §3). Parâmetros standard são
# gratuitos e legíveis por qualquer identidade da conta — evita terraform_remote_state, que
# daria acesso ao state de outro módulo (o de infra-database guarda a senha do RDS).
locals {
  ssm_contract = {
    vpc_id                = aws_vpc.main.id
    private_subnet_ids    = join(",", [aws_subnet.private_a.id, aws_subnet.private_b.id])
    k3s_security_group_id = aws_security_group.k3s.id
    k3s_eip               = aws_eip.k3s.public_ip
    ecr_repository_url    = aws_ecr_repository.main.repository_url
    application_url       = "http://${aws_eip.k3s.public_ip}"
    # Fase 4 (spec 12 §1): um ECR por servico novo e as filas da Saga, lidos pelos deploys.
    ecr_billing_url   = aws_ecr_repository.services["billing"].repository_url
    ecr_execution_url = aws_ecr_repository.services["execution"].repository_url
  }

  # "sqs/<chave>_url" e "sqs/<chave>_dlq_url" (ex.: /oficina/hml/sqs/billing_commands_url).
  ssm_queue_contract = merge(
    { for k, q in aws_sqs_queue.main : "sqs/${k}_url" => q.url },
    { for k, q in aws_sqs_queue.dlq : "sqs/${k}_dlq_url" => q.url },
  )
}

resource "aws_ssm_parameter" "contract" {
  for_each = merge(local.ssm_contract, local.ssm_queue_contract)

  name  = "/${var.project_name}/${local.env}/${each.key}"
  type  = "String"
  value = each.value
}
