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
  }
}

resource "aws_ssm_parameter" "contract" {
  for_each = local.ssm_contract

  name  = "/${var.project_name}/${local.env}/${each.key}"
  type  = "String"
  value = each.value
}
