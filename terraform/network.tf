# =====================================================================
# Rede: VPC minima com subnets publicas.
#
# Escolha de design (free tier): NAO usamos NAT Gateway (~US$32/mes).
# O RDS fica em subnets publicas, protegido por Security Group que so
# libera a porta 5432 para o SG das Lambdas e (opcionalmente) para o
# seu IP. As Lambdas de API rodam FORA da VPC e acessam o RDS pelo
# endpoint publico.
# =====================================================================

data "aws_availability_zones" "available" {
  state = "available"
}

resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "${local.name_prefix}-vpc"
  }
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${local.name_prefix}-igw"
  }
}

# Duas subnets publicas em AZs distintas (RDS exige subnet group com >= 2 AZs).
resource "aws_subnet" "public" {
  count                   = 2
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.${count.index}.0/24"
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = true

  tags = {
    Name = "${local.name_prefix}-public-${count.index}"
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name = "${local.name_prefix}-public-rt"
  }
}

resource "aws_route_table_association" "public" {
  count          = length(aws_subnet.public)
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# ------------------------------------------------------------------
# Security Groups
# ------------------------------------------------------------------

# SG das Lambdas (identidade). Sem regras de entrada; saida liberada.
resource "aws_security_group" "lambda" {
  name        = "${local.name_prefix}-lambda-sg"
  description = "SG de identidade das Lambdas para acesso ao RDS"
  vpc_id      = aws_vpc.main.id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${local.name_prefix}-lambda-sg"
  }
}

# SG do RDS: libera 5432 apenas para o SG das Lambdas e para o allowed_cidr.
resource "aws_security_group" "rds" {
  name        = "${local.name_prefix}-rds-sg"
  description = "Permite Postgres apenas do SG das Lambdas e do IP autorizado"
  vpc_id      = aws_vpc.main.id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${local.name_prefix}-rds-sg"
  }
}

resource "aws_security_group_rule" "rds_from_lambda" {
  type                     = "ingress"
  from_port                = 5432
  to_port                  = 5432
  protocol                 = "tcp"
  security_group_id        = aws_security_group.rds.id
  source_security_group_id = aws_security_group.lambda.id
  description              = "Postgres a partir das Lambdas"
}

resource "aws_security_group_rule" "rds_from_my_ip" {
  count             = var.allowed_cidr == "" ? 0 : 1
  type              = "ingress"
  from_port         = 5432
  to_port           = 5432
  protocol          = "tcp"
  security_group_id = aws_security_group.rds.id
  cidr_blocks       = [var.allowed_cidr]
  description       = "Postgres a partir do IP autorizado (carga de dados/schema)"
}
