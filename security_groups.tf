# Faixas IPv4 do API Gateway na região: a porta 80 precisa aceitá-las para o gateway
# alcançar o Traefik (spec 03 §5). Vêm de um data source, nunca de variável — por isso
# a proibição de 0.0.0.0/0 em var.allowed_cidr continua valendo.
data "aws_ip_ranges" "api_gateway" {
  regions  = [var.aws_region]
  services = ["api_gateway"]
}

locals {
  api_gateway_cidrs = toset(data.aws_ip_ranges.api_gateway.cidr_blocks)
}

# Regras como recursos separados (e não inline): o conjunto de faixas do API Gateway é
# dinâmico, e misturar regras inline com aws_vpc_security_group_ingress_rule faz o
# Terraform brigar pelo mesmo conjunto de regras.
resource "aws_security_group" "k3s" {
  name_prefix = "${local.name_prefix}-k3s-"
  description = "k3s: SSH e HTTP do aluno, HTTP do API Gateway"
  vpc_id      = aws_vpc.main.id

  tags = { Name = "${local.name_prefix}-k3s-sg" }

  lifecycle {
    # Cota padrão: 60 regras de entrada por security group. Se a AWS ampliar as faixas
    # do API Gateway além do limite, o plan falha aqui, com causa explícita, em vez de
    # estourar no apply com um erro genérico de cota.
    precondition {
      condition     = length(local.api_gateway_cidrs) + 2 <= 60
      error_message = "As faixas do API Gateway (${length(local.api_gateway_cidrs)}) excedem a cota de 60 regras de entrada do security group."
    }
  }
}

resource "aws_vpc_security_group_ingress_rule" "ssh" {
  security_group_id = aws_security_group.k3s.id
  description       = "SSH do aluno"
  ip_protocol       = "tcp"
  from_port         = 22
  to_port           = 22
  cidr_ipv4         = var.allowed_cidr
}

# Porta que o Traefik (ingress controller embarcado no k3s) publica no node.
# Sem esta regra a aplicação só era alcançável por "kubectl port-forward" — o
# Service é ClusterIP e nada no security group abria caminho de fora.
resource "aws_vpc_security_group_ingress_rule" "http_student" {
  security_group_id = aws_security_group.k3s.id
  description       = "HTTP do aluno (Traefik/Ingress da aplicacao)"
  ip_protocol       = "tcp"
  from_port         = 80
  to_port           = 80
  cidr_ipv4         = var.allowed_cidr
}

resource "aws_vpc_security_group_ingress_rule" "http_api_gateway" {
  for_each = local.api_gateway_cidrs

  security_group_id = aws_security_group.k3s.id
  description       = "HTTP do API Gateway"
  ip_protocol       = "tcp"
  from_port         = 80
  to_port           = 80
  cidr_ipv4         = each.value
}

# A API do k3s (6443) NÃO é exposta. O acesso administrativo, inclusive o da
# pipeline, passa por túnel do SSM Session Manager sobre a saída HTTPS da
# instância. Isso elimina a necessidade de reabrir o security group para o IP
# dinâmico do runner do GitHub.
resource "aws_vpc_security_group_egress_rule" "all" {
  security_group_id = aws_security_group.k3s.id
  description       = "Saida liberada: instalacao do k3s, pull do ECR e canal do SSM"
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
}

# O security group do RDS (ingresso 5432 a partir deste SG) vive em oficina-infra-database,
# que lê k3s_security_group_id do SSM (ssm_outputs.tf).
