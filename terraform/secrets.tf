# =====================================================================
# Secrets Manager: credenciais do banco disponiveis para as Lambdas
# =====================================================================

resource "aws_secretsmanager_secret" "db" {
  name        = "${local.name_prefix}-db-credentials"
  description = "Credenciais de conexao do RDS PostgreSQL do InjuryDetector"

  recovery_window_in_days = 0 # facilita recriar em dev; use 7-30 em producao
}

resource "aws_secretsmanager_secret_version" "db" {
  secret_id = aws_secretsmanager_secret.db.id
  secret_string = jsonencode({
    host     = aws_db_instance.main.address
    port     = aws_db_instance.main.port
    dbname   = var.db_name
    username = var.db_username
    password = var.db_password
  })
}

# ------------------------------------------------------------------
# Segredo da chave JWT (assinatura dos tokens de login)
# ------------------------------------------------------------------
resource "random_password" "jwt" {
  length  = 48
  special = false
}

resource "aws_secretsmanager_secret" "jwt" {
  name                    = "${local.name_prefix}-jwt-secret"
  description             = "Chave de assinatura dos JWT do InjuryDetector"
  recovery_window_in_days = 0
}

resource "aws_secretsmanager_secret_version" "jwt" {
  secret_id     = aws_secretsmanager_secret.jwt.id
  secret_string = random_password.jwt.result
}
