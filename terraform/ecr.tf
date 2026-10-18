# =====================================================================
# ECR: repositorio da imagem do servico de ML (Lambda container).
#
# Fluxo: build da imagem em ml/ -> push para este repo -> a Lambda
# ml_prediction referencia a imagem por tag (var.ml_image_tag).
#
# Free tier ECR: 500MB/mes de armazenamento por 12 meses. A imagem CPU
# do torch pode passar disso; a lifecycle policy abaixo mantem apenas as
# imagens mais recentes para conter custo.
# =====================================================================

resource "aws_ecr_repository" "ml" {
  name                 = "${local.name_prefix}-ml"
  image_tag_mutability = "MUTABLE"
  force_delete         = true # facilita terraform destroy em dev

  image_scanning_configuration {
    scan_on_push = false
  }

  tags = {
    Name = "${local.name_prefix}-ml"
  }
}

# Mantem apenas as ultimas 3 imagens para economizar armazenamento.
resource "aws_ecr_lifecycle_policy" "ml" {
  repository = aws_ecr_repository.ml.name

  policy = jsonencode({
    rules = [{
      rulePriority = 1
      description  = "Manter apenas as 3 imagens mais recentes"
      selection = {
        tagStatus   = "any"
        countType   = "imageCountMoreThan"
        countNumber = 3
      }
      action = { type = "expire" }
    }]
  })
}
