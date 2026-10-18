# =====================================================================
# Step Functions: orquestra o pipeline diario de inferencia da V4.
#
# So e criado na Fase 2 (create_ml_lambda = true), pois depende da
# Lambda container de ML ja existir.
#
# Fluxo: invoca a Lambda ml_prediction, que para cada atleta monta a
# janela de 7 dias, roda o ensemble V4 e grava em injury_prediction.
# EventBridge Scheduler dispara a State Machine 1x/dia.
# =====================================================================

resource "aws_sfn_state_machine" "daily_prediction" {
  count    = var.create_ml_lambda ? 1 : 0
  name     = "${local.name_prefix}-daily-prediction"
  role_arn = aws_iam_role.sfn_exec[0].arn

  definition = jsonencode({
    Comment = "Pipeline diario de predicao de risco de lesao (V4)"
    StartAt = "RunDailyPrediction"
    States = {
      RunDailyPrediction = {
        Type     = "Task"
        Resource = "arn:aws:states:::lambda:invoke"
        Parameters = {
          FunctionName = aws_lambda_function.ml_prediction[0].arn
          "Payload.$"  = "$"
        }
        Retry = [{
          ErrorEquals     = ["Lambda.ServiceException", "Lambda.TooManyRequestsException", "States.TaskFailed"]
          IntervalSeconds = 5
          MaxAttempts     = 3
          BackoffRate     = 2.0
        }]
        End = true
      }
    }
  })

  tags = {
    Name = "${local.name_prefix}-daily-prediction"
  }
}

# ------------------------------------------------------------------
# Agendamento diario (EventBridge Scheduler)
# ------------------------------------------------------------------
resource "aws_scheduler_schedule" "daily_prediction" {
  count      = var.create_ml_lambda ? 1 : 0
  name       = "${local.name_prefix}-daily-prediction-schedule"
  group_name = "default"

  flexible_time_window {
    mode = "OFF"
  }

  schedule_expression = var.prediction_schedule

  target {
    arn      = aws_sfn_state_machine.daily_prediction[0].arn
    role_arn = aws_iam_role.scheduler_exec[0].arn
  }
}
