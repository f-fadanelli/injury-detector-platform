# =====================================================================
# API Gateway v2 (HTTP API)
# 1M chamadas/mes no free tier (12 meses).
#
# Rotas publicas:   POST /auth/login, POST /athletes (cadastro)
# Rotas protegidas: demais (exigem JWT via Lambda Authorizer)
# =====================================================================

resource "aws_apigatewayv2_api" "main" {
  name          = "${local.name_prefix}-api"
  protocol_type = "HTTP"
  description   = "API do InjuryDetector (auth, atleta, diario, treino, dashboard)"

  cors_configuration {
    allow_origins = ["*"] # restrinja ao dominio do front em producao
    allow_methods = ["GET", "POST", "PUT", "DELETE", "OPTIONS"]
    allow_headers = ["Content-Type", "Authorization"]
    max_age       = 300
  }

  tags = {
    Name = "${local.name_prefix}-api"
  }
}

resource "aws_apigatewayv2_stage" "default" {
  api_id      = aws_apigatewayv2_api.main.id
  name        = "$default"
  auto_deploy = true

  default_route_settings {
    throttling_burst_limit = 20
    throttling_rate_limit  = 20
  }

  tags = {
    Name = "${local.name_prefix}-api-stage"
  }
}

# ------------------------------------------------------------------
# Lambda Authorizer (JWT) - formato simples, resposta booleana
# ------------------------------------------------------------------
resource "aws_apigatewayv2_authorizer" "jwt" {
  api_id                            = aws_apigatewayv2_api.main.id
  authorizer_type                   = "REQUEST"
  identity_sources                  = ["$request.header.Authorization"]
  name                              = "${local.name_prefix}-jwt-authorizer"
  authorizer_uri                    = aws_lambda_function.authorizer.invoke_arn
  authorizer_payload_format_version = "2.0"
  enable_simple_responses           = true
  authorizer_result_ttl_in_seconds  = 0
}

# ------------------------------------------------------------------
# Integracoes Lambda-proxy (uma por funcao)
# ------------------------------------------------------------------
resource "aws_apigatewayv2_integration" "api" {
  for_each = local.api_functions

  api_id                 = aws_apigatewayv2_api.main.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.api[each.key].invoke_arn
  integration_method     = "POST"
  payload_format_version = "2.0"
}

# ------------------------------------------------------------------
# Rotas publicas (sem authorizer)
# ------------------------------------------------------------------
locals {
  public_routes = {
    "POST /auth/login" = "auth_login"
    "POST /athletes"   = "athlete_register"
  }

  protected_routes = {
    "GET /athletes/{athlete_id}"            = "athlete_get"
    "PUT /athletes/{athlete_id}"            = "athlete_upsert"
    "GET /athletes/{athlete_id}/daily"      = "daily_get"
    "POST /athletes/{athlete_id}/daily"     = "daily_upsert"
    "GET /athletes/{athlete_id}/trainings"  = "training_get"
    "POST /athletes/{athlete_id}/trainings" = "training_upsert"
    "GET /athletes/{athlete_id}/dashboard"  = "dashboard_get"
    "GET /athletes/{athlete_id}/explain"    = "explain_get"
  }
}

resource "aws_apigatewayv2_route" "public" {
  for_each = local.public_routes

  api_id    = aws_apigatewayv2_api.main.id
  route_key = each.key
  target    = "integrations/${aws_apigatewayv2_integration.api[each.value].id}"
}

resource "aws_apigatewayv2_route" "protected" {
  for_each = local.protected_routes

  api_id             = aws_apigatewayv2_api.main.id
  route_key          = each.key
  target             = "integrations/${aws_apigatewayv2_integration.api[each.value].id}"
  authorization_type = "CUSTOM"
  authorizer_id      = aws_apigatewayv2_authorizer.jwt.id
}
