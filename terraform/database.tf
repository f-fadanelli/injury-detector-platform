# =====================================================================
# RDS PostgreSQL (free tier)
# =====================================================================

resource "aws_db_subnet_group" "main" {
  name       = "${local.name_prefix}-db-subnet-group"
  subnet_ids = aws_subnet.public[*].id

  tags = {
    Name = "${local.name_prefix}-db-subnet-group"
  }
}

resource "aws_db_instance" "main" {
  identifier     = "${local.name_prefix}-db"
  engine         = "postgres"
  engine_version = var.db_engine_version
  instance_class = var.db_instance_class

  allocated_storage     = var.db_allocated_storage
  max_allocated_storage = 0 # desabilita autoscaling de storage (evita custo surpresa)
  storage_type          = "gp2"
  # Contas do plano gratuito novo (Free Tier) costumam bloquear encryption/KMS.
  storage_encrypted = false

  db_name  = var.db_name
  username = var.db_username
  password = var.db_password
  port     = 5432

  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [aws_security_group.rds.id]

  # Acesso publico controlado por Security Group (design free tier, sem NAT).
  publicly_accessible = true

  multi_az = false # free tier = single AZ
  # Plano gratuito novo limita a retencao de backup. 1 dia e aceito;
  # use 0 para desabilitar backups caso a conta ainda recuse.
  backup_retention_period    = var.db_backup_retention
  auto_minor_version_upgrade = true
  deletion_protection        = false # troque para true em producao
  skip_final_snapshot        = true  # troque para false em producao

  performance_insights_enabled = false # nao coberto no free tier para t3.micro

  tags = {
    Name = "${local.name_prefix}-db"
  }
}
