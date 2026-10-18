# =====================================================================
# Lambdas
#
# Arquitetura:
#   - APIs de CRUD + auth: Node.js 20 (zip). Custo zero parado.
#   - Serviço de ML (V4): Lambda CONTAINER a partir de imagem no ECR.
#
# Todas as Lambdas Node compartilham o MESMO zip (src/ com node_modules);
# cada funcao aponta para seu handler via o parametro `handler`.
#
# As Lambdas rodam DENTRO da VPC (Opcao B) e acessam o RDS de forma privada.
# =====================================================================

# Empacota todo o src/ (lib + handlers + node_modules) num unico zip.
# IMPORTANTE: rodar `npm install` em src/ antes do apply (ver README).
data "archive_file" "api" {
  type        = "zip"
  source_dir  = var.api_src_dir
  output_path = "${path.module}/build/api.zip"
  excludes    = ["placeholder/**", "package-lock.json"]
}

locals {
  # Variaveis de ambiente comuns.
  lambda_env = {
    DB_HOST       = aws_db_instance.main.address
    DB_PORT       = tostring(aws_db_instance.main.port)
    DB_NAME       = var.db_name
    DB_USER       = var.db_username
    DB_PASSWORD   = var.db_password
    DB_SECRET_ARN = aws_secretsmanager_secret.db.arn
    JWT_SECRET    = random_password.jwt.result
    MODEL_VERSION = var.model_version
  }

  # APIs em Node.js: nome logico -> { handler, descricao }
  api_functions = {
    auth_login       = { handler = "handlers/auth_login.handler", desc = "POST login (publico) -> JWT" }
    athlete_get      = { handler = "handlers/athlete_get.handler", desc = "GET perfil do atleta" }
    athlete_register = { handler = "handlers/athlete_register.handler", desc = "POST cadastro (publico)" }
    athlete_upsert   = { handler = "handlers/athlete_upsert.handler", desc = "PUT atualiza perfil" }
    daily_get        = { handler = "handlers/daily_get.handler", desc = "GET registros diarios" }
    daily_upsert     = { handler = "handlers/daily_upsert.handler", desc = "POST upsert diario" }
    training_get     = { handler = "handlers/training_get.handler", desc = "GET treinos" }
    training_upsert  = { handler = "handlers/training_upsert.handler", desc = "POST treino" }
    dashboard_get    = { handler = "handlers/dashboard_get.handler", desc = "GET dashboard (risco + graficos)" }
    explain_get      = { handler = "handlers/explain_get.handler", desc = "GET explicabilidade (SHAP + features)" }
  }
}

resource "aws_lambda_function" "api" {
  for_each = local.api_functions

  function_name = "${local.name_prefix}-${replace(each.key, "_", "-")}"
  description   = each.value.desc
  role          = aws_iam_role.lambda_exec.arn
  runtime       = "nodejs20.x"
  handler       = each.value.handler

  filename         = data.archive_file.api.output_path
  source_code_hash = data.archive_file.api.output_base64sha256

  timeout     = 15
  memory_size = 256

  vpc_config {
    subnet_ids         = aws_subnet.public[*].id
    security_group_ids = [aws_security_group.lambda.id]
  }

  environment {
    variables = local.lambda_env
  }

  tags = {
    Name = "${local.name_prefix}-${each.key}"
  }

  depends_on = [aws_iam_role_policy_attachment.lambda_vpc]
}

# ------------------------------------------------------------------
# Lambda Authorizer (valida JWT das rotas protegidas)
# ------------------------------------------------------------------
resource "aws_lambda_function" "authorizer" {
  function_name = "${local.name_prefix}-authorizer"
  description   = "Lambda Authorizer: valida JWT"
  role          = aws_iam_role.lambda_exec.arn
  runtime       = "nodejs20.x"
  handler       = "handlers/authorizer.handler"

  filename         = data.archive_file.api.output_path
  source_code_hash = data.archive_file.api.output_base64sha256

  timeout     = 10
  memory_size = 128

  environment {
    variables = {
      JWT_SECRET = random_password.jwt.result
    }
  }

  tags = {
    Name = "${local.name_prefix}-authorizer"
  }
}

# ------------------------------------------------------------------
# Lambda do serviço de ML (V4) - CONTAINER no ECR.
# ------------------------------------------------------------------
resource "aws_lambda_function" "ml_prediction" {
  count = var.create_ml_lambda ? 1 : 0

  function_name = "${local.name_prefix}-ml-prediction"
  description   = "Servico de ML (V4): monta janelas, roda ensemble, grava predicao + explicacao"
  role          = aws_iam_role.lambda_exec.arn

  package_type = "Image"
  image_uri    = "${aws_ecr_repository.ml.repository_url}:${var.ml_image_tag}"

  timeout     = 900 # backfill de todos os atletas pode demorar
  memory_size = 2048

  vpc_config {
    subnet_ids         = aws_subnet.public[*].id
    security_group_ids = [aws_security_group.lambda.id]
  }

  environment {
    variables = merge(local.lambda_env, {
      MODEL_THRESHOLD = var.model_threshold
    })
  }

  tags = {
    Name = "${local.name_prefix}-ml-prediction"
  }

  depends_on = [
    aws_ecr_repository.ml,
    aws_iam_role_policy_attachment.lambda_vpc,
  ]
}

# Permissao para o API Gateway invocar cada Lambda de API
resource "aws_lambda_permission" "apigw" {
  for_each = local.api_functions

  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.api[each.key].function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.main.execution_arn}/*/*"
}

# Permissao para o API Gateway invocar o authorizer
resource "aws_lambda_permission" "apigw_authorizer" {
  statement_id  = "AllowAPIGatewayInvokeAuthorizer"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.authorizer.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.main.execution_arn}/*"
}
