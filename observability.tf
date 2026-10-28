# E7 (spec 05 §4): agentes New Relic no k3s via chart nri-bundle.
#
# Por que não `helm_release` do Terraform (como a spec 06 §2 previa): o API do k3s (6443) nunca é
# exposto, só acessível por túnel SSM, e a EC2 nem existe quando o provider `helm` seria configurado.
# O k3s tem um controlador de Helm nativo: o user_data grava um manifesto HelmChart em
# /var/lib/rancher/k3s/server/manifests e o próprio cluster instala o chart no boot.
#
# A licença NUNCA entra no user_data nem no state em texto de manifesto: vai para um parâmetro SSM
# SecureString e a EC2 a lê no boot com o instance profile. Sem `newrelic_license_key` nada disto é
# criado e o cluster sobe sem agentes (a infraestrutura não depende do New Relic).

locals {
  nri_enabled = var.newrelic_license_key != ""

  nri_license_ssm_name = "/${var.project_name}/${local.env}/newrelic_license_key"

  # Reservas explícitas em todos os componentes: sem elas o scheduler não protege a aplicação no node
  # único (spec 05 §4). hml (t3.small, 2 GiB) roda a versão reduzida, sem o prometheus-agent.
  nri_resources = {
    small  = { requests = { cpu = "25m", memory = "48Mi" }, limits = { memory = "128Mi" } }
    medium = { requests = { cpu = "100m", memory = "128Mi" }, limits = { memory = "256Mi" } }
  }

  nri_values = {
    global = {
      cluster                = "${var.project_name}-${local.env}"
      region                 = "US"
      customSecretName       = "newrelic-license"
      customSecretLicenseKey = "licenseKey"
      # Reduz cardinalidade e volume: protege o teto de 100 GB/mês do free tier.
      lowDataMode = true
    }

    "newrelic-infrastructure" = {
      enabled = true
      # k3s embute o control plane no processo do servidor: o scraper de etcd/scheduler do chart
      # não encontra os endpoints e só consumiria memória.
      controlPlane = { enabled = false }
      kubelet = {
        agent   = { resources = local.nri_resources.medium }
        kubelet = { resources = local.nri_resources.small }
      }
      ksm = {
        ksm       = { resources = local.nri_resources.small }
        forwarder = { resources = local.nri_resources.small }
      }
    }

    "kube-state-metrics" = {
      enabled   = true
      resources = local.nri_resources.small
    }

    "nri-kube-events" = {
      enabled   = true
      resources = local.nri_resources.small
      forwarder = { resources = local.nri_resources.small }
    }

    "newrelic-logging" = {
      enabled   = true
      resources = local.nri_resources.small
    }

    # Coleta /q/metrics da aplicação (anotação newrelic.io/scrape no Deployment). Só em prod.
    "newrelic-prometheus-agent" = {
      enabled = local.config.prometheus_agent
      resources = {
        prometheus   = local.nri_resources.medium
        configurator = local.nri_resources.small
      }
    }

    # O webhook de injeção de metadados não é usado e custa memória.
    "nri-metadata-injection" = { enabled = false }
  }

  # Manifestos aplicados pelo k3s no boot. O Secret da licença é montado no shell (user_data), não aqui.
  nri_helmchart_manifest = yamlencode({
    apiVersion = "helm.cattle.io/v1"
    kind       = "HelmChart"
    metadata   = { name = "nri-bundle", namespace = "kube-system" }
    spec = {
      repo            = "https://helm-charts.newrelic.com"
      chart           = "nri-bundle"
      version         = "8.0.39"
      targetNamespace = "newrelic"
      createNamespace = true
      valuesContent   = yamlencode(local.nri_values)
    }
  })
}

resource "aws_ssm_parameter" "newrelic_license_key" {
  count = local.nri_enabled ? 1 : 0

  name  = local.nri_license_ssm_name
  type  = "SecureString"
  value = var.newrelic_license_key
}
