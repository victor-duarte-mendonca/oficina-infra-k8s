#!/bin/bash
set -euxo pipefail

# Redundante em algumas AMIs Amazon Linux 2023 (já vem pré-instalado), mantido explícito para não
# depender de suposição que pode mudar entre variantes da AMI.
dnf install -y aws-cli

%{ if newrelic_enabled ~}
# E7: agentes New Relic. A licença vem do SSM (SecureString) e nunca fica no user_data. Sem `set -x`
# neste trecho para o valor não ir ao log do cloud-init. Se a leitura falhar, o k3s sobe sem agentes.
set +x
MANIFESTS=/var/lib/rancher/k3s/server/manifests
if NR_LICENSE_KEY="$(aws ssm get-parameter --region ${aws_region} --name ${license_ssm_name} \
      --with-decryption --query Parameter.Value --output text)"; then
  umask 077
  mkdir -p "$MANIFESTS"
  cat > "$MANIFESTS/newrelic-license.yaml" <<NR_SECRET
apiVersion: v1
kind: Namespace
metadata:
  name: newrelic
---
apiVersion: v1
kind: Secret
metadata:
  name: newrelic-license
  namespace: newrelic
type: Opaque
stringData:
  licenseKey: "$NR_LICENSE_KEY"
NR_SECRET
  cat > "$MANIFESTS/nri-bundle.yaml" <<'NR_CHART'
${helmchart_manifest}
NR_CHART
  umask 022
else
  echo "AVISO: licença do New Relic indisponível no SSM; k3s sobe sem agentes." >&2
fi
unset NR_LICENSE_KEY
set -x

%{ endif ~}
# --tls-san é essencial: sem isso, o certificado autoassinado do k3s só cobre os IPs conhecidos no
# momento da instalação (IP privado, 127.0.0.1) — o Elastic IP é associado por um recurso Terraform
# separado, então o k3s nunca saberia que precisa incluir esse IP no certificado, e todo acesso via
# kubectl/kubeconfig externo falharia com "certificate is valid for X, not <eip>".
curl -sfL https://get.k3s.io | sh -s - --write-kubeconfig-mode 644 --tls-san ${k3s_public_ip}

mkdir -p /home/ec2-user/.kube
cp /etc/rancher/k3s/k3s.yaml /home/ec2-user/.kube/config
sed -i "s/127.0.0.1/${k3s_public_ip}/" /home/ec2-user/.kube/config
chown -R ec2-user:ec2-user /home/ec2-user/.kube
