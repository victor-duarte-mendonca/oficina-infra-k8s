# Mensageria da Saga (Fase 4, spec 12 §2 e spec 03 §1): SQS FIFO + DLQ, uma fila por destinatario.
#   billing-commands   OS -> Billing    (comandos: orcamento, pagamento, estorno)
#   execution-commands OS -> Execution  (comandos: enfileirar/realizar execucao)
#   os-saga-replies    Billing/Execution -> OS (respostas e eventos da Saga)
#
# FIFO com MessageGroupId = workOrderId: ordem estrita por OS, paralelismo entre OS. A deduplicacao e explicita
# (content_based_deduplication = false): MessageDeduplicationId = messageId, que NAO substitui a idempotencia do
# consumidor. A DLQ de uma fila FIFO tambem precisa ser FIFO.
locals {
  queues = {
    billing_commands   = "billing-commands"
    execution_commands = "execution-commands"
    os_replies         = "os-saga-replies"
  }
}

resource "aws_sqs_queue" "dlq" {
  for_each = local.queues

  name                        = "${local.name_prefix}-${each.value}-dlq.fifo"
  fifo_queue                  = true
  content_based_deduplication = false
  message_retention_seconds   = 1209600 # 14 dias: tempo de investigar e reprocessar (runbook, spec 12 §7)
  sqs_managed_sse_enabled     = true

  tags = { Name = "${local.name_prefix}-${each.value}-dlq" }
}

resource "aws_sqs_queue" "main" {
  for_each = local.queues

  name                        = "${local.name_prefix}-${each.value}.fifo"
  fifo_queue                  = true
  content_based_deduplication = false
  visibility_timeout_seconds  = 60
  message_retention_seconds   = 345600 # 4 dias
  sqs_managed_sse_enabled     = true

  # 5 recebimentos sem sucesso levam a mensagem para a DLQ (alerta por profundidade > 0).
  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.dlq[each.key].arn
    maxReceiveCount     = 5
  })

  tags = { Name = "${local.name_prefix}-${each.value}" }
}
