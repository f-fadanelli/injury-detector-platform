# =====================================================================
# IAM: roles e policies para Lambdas e Step Functions
# =====================================================================

# ------------------------------------------------------------------
# Role de execucao das Lambdas de API/ML
# ------------------------------------------------------------------
data "aws_iam_policy_document" "lambda_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "lambda_exec" {
  name               = "${local.name_prefix}-lambda-exec"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume.json
}

# Logs no CloudWatch
resource "aws_iam_role_policy_attachment" "lambda_logs" {
  role       = aws_iam_role.lambda_exec.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# Permissao para a Lambda criar/gerenciar ENIs na VPC (Opcao B: Lambda em VPC).
# Obrigatorio para funcoes com vpc_config.
resource "aws_iam_role_policy_attachment" "lambda_vpc" {
  role       = aws_iam_role.lambda_exec.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

# Ler a senha do banco no Secrets Manager
data "aws_iam_policy_document" "lambda_secrets" {
  statement {
    actions   = ["secretsmanager:GetSecretValue"]
    resources = [aws_secretsmanager_secret.db.arn]
  }
}

resource "aws_iam_role_policy" "lambda_secrets" {
  name   = "${local.name_prefix}-lambda-secrets"
  role   = aws_iam_role.lambda_exec.id
  policy = data.aws_iam_policy_document.lambda_secrets.json
}

# ------------------------------------------------------------------
# Role da State Machine (Step Functions)
# ------------------------------------------------------------------
data "aws_iam_policy_document" "sfn_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["states.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "sfn_exec" {
  count              = var.create_ml_lambda ? 1 : 0
  name               = "${local.name_prefix}-sfn-exec"
  assume_role_policy = data.aws_iam_policy_document.sfn_assume.json
}

data "aws_iam_policy_document" "sfn_invoke_lambda" {
  count = var.create_ml_lambda ? 1 : 0

  statement {
    actions = ["lambda:InvokeFunction"]
    resources = [
      aws_lambda_function.ml_prediction[0].arn,
      "${aws_lambda_function.ml_prediction[0].arn}:*",
    ]
  }
}

resource "aws_iam_role_policy" "sfn_invoke_lambda" {
  count  = var.create_ml_lambda ? 1 : 0
  name   = "${local.name_prefix}-sfn-invoke-lambda"
  role   = aws_iam_role.sfn_exec[0].id
  policy = data.aws_iam_policy_document.sfn_invoke_lambda[0].json
}

# ------------------------------------------------------------------
# Role do EventBridge Scheduler para iniciar a State Machine
# ------------------------------------------------------------------
data "aws_iam_policy_document" "scheduler_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["scheduler.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "scheduler_exec" {
  count              = var.create_ml_lambda ? 1 : 0
  name               = "${local.name_prefix}-scheduler-exec"
  assume_role_policy = data.aws_iam_policy_document.scheduler_assume.json
}

data "aws_iam_policy_document" "scheduler_start_sfn" {
  count = var.create_ml_lambda ? 1 : 0

  statement {
    actions   = ["states:StartExecution"]
    resources = [aws_sfn_state_machine.daily_prediction[0].arn]
  }
}

resource "aws_iam_role_policy" "scheduler_start_sfn" {
  count  = var.create_ml_lambda ? 1 : 0
  name   = "${local.name_prefix}-scheduler-start-sfn"
  role   = aws_iam_role.scheduler_exec[0].id
  policy = data.aws_iam_policy_document.scheduler_start_sfn[0].json
}
