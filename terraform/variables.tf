variable "aws_region" {
  description = "Regiao AWS onde a infra sera provisionada."
  type        = string
  default     = "sa-east-1"
}

variable "project_name" {
  description = "Prefixo usado nos nomes dos recursos."
  type        = string
  default     = "injurydetector"
}

variable "environment" {
  description = "Ambiente (dev, staging, prod)."
  type        = string
  default     = "dev"
}

# ------------------------------------------------------------------
# Banco de dados
# ------------------------------------------------------------------
variable "db_name" {
  description = "Nome do banco de dados inicial."
  type        = string
  default     = "injurydetector"
}

variable "db_username" {
  description = "Usuario master do RDS."
  type        = string
  default     = "injury_admin"
}

variable "db_password" {
  description = "Senha do usuario master do RDS. Defina em terraform.tfvars (nao versionar)."
  type        = string
  sensitive   = true
}

variable "db_instance_class" {
  description = "Classe da instancia RDS. db.t3.micro/db.t4g.micro estao no free tier."
  type        = string
  default     = "db.t3.micro"
}

variable "db_allocated_storage" {
  description = "Armazenamento do RDS em GB (free tier ate 20GB)."
  type        = number
  default     = 20
}

variable "db_engine_version" {
  description = "Versao do PostgreSQL (16.9 e a mais antiga disponivel em sa-east-1)."
  type        = string
  default     = "16.9"
}

variable "db_backup_retention" {
  description = <<-EOT
    Dias de retencao de backup. O plano gratuito novo (Free Tier) limita
    este valor: use 1 (aceito). Se a conta ainda recusar, use 0 (sem backup).
  EOT
  type        = number
  default     = 1
}

# ------------------------------------------------------------------
# Acesso / seguranca
# ------------------------------------------------------------------
variable "allowed_cidr" {
  description = <<-EOT
    CIDR autorizado a acessar o RDS diretamente (ex.: seu IP publico em /32
    para rodar o schema.sql e carregar os CSVs). Ex.: "203.0.113.4/32".
    Deixe vazio para nao liberar acesso externo direto.
  EOT
  type        = string
  default     = ""
}

# ------------------------------------------------------------------
# Pipeline ML
# ------------------------------------------------------------------
variable "prediction_schedule" {
  description = "Expressao de agendamento (EventBridge) do pipeline diario de inferencia."
  type        = string
  default     = "cron(0 6 * * ? *)" # todo dia as 06:00 UTC
}

variable "model_version" {
  description = "Versao do modelo em producao."
  type        = string
  default     = "V4"
}

variable "model_threshold" {
  description = "Threshold de decisao do ensemble V4 (>= => risco de lesao)."
  type        = string
  default     = "0.5"
}

# ------------------------------------------------------------------
# Container de ML (ECR)
# ------------------------------------------------------------------
variable "ml_image_tag" {
  description = <<-EOT
    Tag da imagem do servico de ML no ECR que a Lambda container usara.
    Faca o build/push da imagem ANTES do apply da Lambda ml_prediction
    (ver terraform/README.md). Ex.: "latest" ou um SHA de commit.
  EOT
  type        = string
  default     = "latest"
}

variable "api_src_dir" {
  description = <<-EOT
    Caminho para o diretorio 'src' do repo injury-detector-api (codigo das
    Lambdas Node). Default assume os repos como pastas-irmas. Rode
    'npm install' nesse diretorio antes do apply para empacotar as deps.
  EOT
  type        = string
  default     = "../../injury-detector-api/src"
}

variable "create_ml_lambda" {
  description = <<-EOT
    Controla a criacao da Lambda container de ML e da Step Function.
    A Lambda container EXIGE que a imagem ja exista no ECR. Por isso o
    deploy e feito em 2 fases:
      Fase 1: create_ml_lambda = false  -> cria ECR (e o resto). Faca build/push.
      Fase 2: create_ml_lambda = true   -> cria a Lambda de ML + Step Function.
  EOT
  type        = bool
  default     = false
}
