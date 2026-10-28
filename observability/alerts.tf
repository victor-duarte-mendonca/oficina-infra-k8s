# Seis políticas de alerta (spec 05 §8), cada uma com as suas condições NRQL. O New Relic só tem
# prioridade critical/warning por condição; a severidade da spec (crítica/alta/média) vai no nome da
# política, e todas abrem incidente (bloco critical) para chegar por e-mail.
#
# Consultas que dependem de dados reais (traces OTLP, métricas do prometheus-agent, K8s samples) foram
# escritas contra os nomes documentados e devem ser confirmadas na sessão AWS (spec 05 §10).
locals {
  # Nome do monitor Synthetics (synthetics.tf); também usado no dashboard de operação.
  health_monitor = "${local.prefix}-health"

  # Cada condição: janela de agregação e duração em segundos, operador/limiar e ocorrências.
  # occurrences: ALL = violado durante toda a duração; AT_LEAST_ONCE = ao menos uma vez na duração.
  alert_policies = {
    latencia = {
      name = "[CRÍTICA] Latência da API"
      conditions = {
        p95 = {
          name        = "p95 acima de 1,5 s"
          query       = "SELECT percentile(duration.ms, 95) FROM Span WHERE entity.name = '${local.service}' AND span.kind = 'server' AND deployment.environment = '${local.env}'"
          threshold   = 1500
          window      = 60
          duration    = 300
          occurrences = "ALL"
        }
      }
    }

    ordens_de_servico = {
      name = "[CRÍTICA] Falha no processamento de ordens de serviço"
      conditions = {
        transicoes_invalidas = {
          name        = "Erros de transição de OS"
          query       = "SELECT sum(oficina_work_order_transition_errors_total) FROM Metric WHERE cluster_name = '${local.cluster}'"
          threshold   = 0
          window      = 60
          duration    = 300
          occurrences = "AT_LEAST_ONCE"
        }
      }
    }

    saude_do_cluster = {
      name = "[ALTA] Saúde do cluster"
      conditions = {
        crashloop = {
          name        = "Pod em CrashLoopBackOff"
          query       = "SELECT uniqueCount(podName) FROM K8sContainerSample WHERE clusterName = '${local.cluster}' AND reason = 'CrashLoopBackOff'"
          threshold   = 0
          window      = 60
          duration    = 300
          occurrences = "ALL"
        }
        pending = {
          name        = "Pod em Pending por mais de 5 min"
          query       = "SELECT uniqueCount(podName) FROM K8sPodSample WHERE clusterName = '${local.cluster}' AND status = 'Pending'"
          threshold   = 0
          window      = 60
          duration    = 300
          occurrences = "ALL"
        }
      }
    }

    saturacao = {
      name = "[ALTA] Saturação"
      conditions = {
        cpu = {
          name        = "CPU do container acima de 85% por 10 min"
          query       = "SELECT average(cpuCoresUtilization) FROM K8sContainerSample WHERE clusterName = '${local.cluster}' FACET podName"
          threshold   = 85
          window      = 60
          duration    = 600
          occurrences = "ALL"
        }
        memoria = {
          name        = "Memória acima de 90% do limite por 10 min"
          query       = "SELECT average(memoryWorkingSetUtilization) FROM K8sContainerSample WHERE clusterName = '${local.cluster}' FACET podName"
          threshold   = 90
          window      = 60
          duration    = 600
          occurrences = "ALL"
        }
      }
    }

    autenticacao = {
      name = "[MÉDIA] Autenticação negada"
      conditions = {
        negadas = {
          name        = "Mais de 50 negações em 5 min (enumeração de CPF)"
          query       = "SELECT sum(oficina_auth_denied_total) FROM Metric WHERE cluster_name = '${local.cluster}'"
          threshold   = 50
          window      = 300
          duration    = 300
          occurrences = "AT_LEAST_ONCE"
        }
      }
    }
  }

  # Só existe com a URL do gateway (o monitor Synthetics também depende dela).
  disponibilidade_policy = var.gateway_url == "" ? {} : {
    disponibilidade = {
      name = "[CRÍTICA] Disponibilidade"
      conditions = {
        health = {
          name        = "Monitor /health falhando em 2 verificações"
          query       = "SELECT count(*) FROM SyntheticCheck WHERE monitorName = '${local.health_monitor}' AND result = 'FAILED'"
          threshold   = 1
          window      = 600
          duration    = 600
          occurrences = "AT_LEAST_ONCE"
        }
      }
    }
  }

  all_policies = merge(local.alert_policies, local.disponibilidade_policy)

  # Condições achatadas: uma chave "<política>.<condição>".
  all_conditions = merge([
    for policy_key, policy in local.all_policies : {
      for condition_key, condition in policy.conditions :
      "${policy_key}.${condition_key}" => merge(condition, { policy = policy_key })
    }
  ]...)
}

resource "newrelic_alert_policy" "this" {
  for_each = local.all_policies

  name                = "${local.prefix} ${each.value.name}"
  incident_preference = "PER_CONDITION"
}

resource "newrelic_nrql_alert_condition" "this" {
  for_each = local.all_conditions

  policy_id = newrelic_alert_policy.this[each.value.policy].id
  type      = "static"
  name      = "${local.prefix} ${each.value.name}"
  enabled   = true

  nrql {
    query = each.value.query
  }

  critical {
    operator              = "above"
    threshold             = each.value.threshold
    threshold_duration    = each.value.duration
    threshold_occurrences = lower(each.value.occurrences)
  }

  aggregation_window = each.value.window
  aggregation_method = "event_flow"
  aggregation_delay  = 120

  # Sem dados = sem violação: a aplicação pode estar desligada (hml sob demanda) sem abrir incidente.
  fill_option                  = "none"
  violation_time_limit_seconds = 86400
}

# E-mail (gratuito). Um destino, um canal e um workflow que roteia as incidências das políticas acima.
resource "newrelic_notification_destination" "email" {
  name = "${local.prefix} e-mail"
  type = "EMAIL"

  property {
    key   = "email"
    value = var.alert_email
  }
}

resource "newrelic_notification_channel" "email" {
  name           = "${local.prefix} e-mail"
  type           = "EMAIL"
  destination_id = newrelic_notification_destination.email.id
  product        = "IINT"

  property {
    key   = "subject"
    value = "[${local.prefix}] {{ issueTitle }}"
  }
}

resource "newrelic_workflow" "alerts" {
  name                  = "${local.prefix} alertas"
  muting_rules_handling = "NOTIFY_ALL_ISSUES"

  issues_filter {
    name = "Políticas ${local.prefix}"
    type = "FILTER"

    predicate {
      attribute = "labels.policyIds"
      operator  = "EXACTLY_MATCHES"
      values    = [for policy in newrelic_alert_policy.this : tostring(policy.id)]
    }
  }

  destination {
    channel_id = newrelic_notification_channel.email.id
  }
}
