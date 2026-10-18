output "api_base_url" {
  description = "URL base da HTTP API (use no front-end)."
  value       = aws_apigatewayv2_stage.default.invoke_url
}

output "rds_endpoint" {
  description = "Endpoint (host) do RDS PostgreSQL."
  value       = aws_db_instance.main.address
}

output "rds_port" {
  description = "Porta do RDS."
  value       = aws_db_instance.main.port
}

output "db_secret_arn" {
  description = "ARN do secret com as credenciais do banco."
  value       = aws_secretsmanager_secret.db.arn
}

output "ecr_repository_url" {
  description = "URL do repositorio ECR para push da imagem de ML."
  value       = aws_ecr_repository.ml.repository_url
}

output "ml_lambda_name" {
  description = "Nome da Lambda container de ML (vazio na Fase 1)."
  value       = var.create_ml_lambda ? aws_lambda_function.ml_prediction[0].function_name : ""
}

output "state_machine_arn" {
  description = "ARN da State Machine do pipeline diario (vazio na Fase 1)."
  value       = var.create_ml_lambda ? aws_sfn_state_machine.daily_prediction[0].arn : ""
}

output "frontend_bucket" {
  description = "Nome do bucket S3 do front-end (destino do upload do build)."
  value       = aws_s3_bucket.frontend.bucket
}

output "frontend_url" {
  description = "URL pública do front-end (CloudFront)."
  value       = "https://${aws_cloudfront_distribution.frontend.domain_name}"
}

output "cloudfront_distribution_id" {
  description = "ID da distribuição CloudFront (para invalidar cache após deploy)."
  value       = aws_cloudfront_distribution.frontend.id
}

output "psql_connection_hint" {
  description = "Comando para aplicar o schema.sql apos o apply (preencha a senha)."
  value       = "psql \"host=${aws_db_instance.main.address} port=${aws_db_instance.main.port} dbname=${var.db_name} user=${var.db_username} sslmode=require\" -f ../db/schema.sql"
}
