#!/usr/bin/env bash
# Publica as credenciais STS da sessão AWS Academy como *organization secrets*,
# visíveis aos 4 repositórios (spec 08 §5). Rodar a cada sessão, antes de qualquer
# pipeline que toque a AWS.
#
# Uso:
#   1. No AWS Academy: "AWS Details" -> "Show" -> copie o bloco [default]
#   2. Exporte no shell:   export AWS_ACCESS_KEY_ID=... AWS_SECRET_ACCESS_KEY=... AWS_SESSION_TOKEN=...
#   3. ./scripts/set-aws-session-secrets.sh
#
# Segredos por environment (DB_PASSWORD, JWT_*, GATEWAY_KEY, NEW_RELIC_LICENSE_KEY...) não
# expiram por sessão: são definidos uma vez, nas etapas que os introduzem (specs 02-07).
set -euo pipefail

ORG="${ORG:-victor-duarte-mendonca}"
REPOS="oficina-app,oficina-auth-lambda,oficina-infra-k8s,oficina-infra-database"

for v in AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_SESSION_TOKEN; do
  if [ -z "${!v:-}" ]; then
    echo "erro: variável $v não exportada" >&2
    exit 1
  fi
done

for v in AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_SESSION_TOKEN; do
  gh secret set "$v" --org "$ORG" --visibility selected --repos "$REPOS" --body "${!v}"
  echo "ok  $v"
done

echo
echo "Credenciais publicadas em $ORG (validade: até o fim da sessão do Academy)."
gh secret list --org "$ORG"
