# Terraform — Infra AWS do InjuryDetector

Provisiona toda a infraestrutura do backend no AWS Free Tier.

## Arquitetura

| Camada | Tecnologia | Serviço AWS | Custo parado |
|---|---|---|---|
| Front-end | React + TS | S3 + CloudFront (Etapa 5) | US$0 |
| Back-end (CRUD) | **Node.js 20** | Lambda + API Gateway (HTTP API) | US$0 |
| Machine Learning | Python (FastAPI) | **Lambda container** (ECR) | US$0 |
| Banco | PostgreSQL | RDS `db.t3.micro` | free tier |

> Só o **ML** vira container (PyTorch + LightGBM). Ele roda como **Lambda
> container** — dispara sob demanda, custo zero parado. As APIs de CRUD são
> Lambdas Node. Nada fica ligado 24/7, então não há gasto com a infra ociosa.
>
> **NAT Gateway foi evitado de propósito** (~US$32/mês). O RDS fica em subnet
> pública protegido por Security Group.

### Acesso ao banco

- **Lambdas → RDS:** as Lambdas rodam **dentro da VPC** e acessam o RDS de
  forma **privada**, autorizadas pelo Security Group (`rds_from_lambda`). Não
  passam pela internet.
- **Credenciais:** como as Lambdas na VPC não têm saída para a internet (sem
  NAT), as credenciais do banco são **injetadas como variáveis de ambiente** no
  deploy (`DB_HOST`, `DB_PORT`, `DB_NAME`, `DB_USER`, `DB_PASSWORD`). A senha
  continua guardada no Secrets Manager como fonte de verdade.
- **Você → RDS:** apenas se definir `allowed_cidr` com seu IP/32, só para
  carregar o `schema.sql` e os CSVs da sua máquina.

## O que é criado

| Recurso | Arquivo |
|---|---|
| VPC + 2 subnets públicas + IGW + route table | `network.tf` |
| Security Groups (RDS e Lambda) | `network.tf` |
| RDS PostgreSQL `db.t3.micro` (20GB) | `database.tf` |
| Secrets Manager (credenciais do banco) | `secrets.tf` |
| ECR (repositório da imagem de ML) | `ecr.tf` |
| 7 Lambdas de API (Node) | `lambda.tf` |
| Lambda container de ML | `lambda.tf` (Fase 2) |
| HTTP API + rotas | `apigateway.tf` |
| Step Functions + agendamento | `stepfunctions.tf` (Fase 2) |
| IAM roles/policies | `iam.tf` |

## Pré-requisitos

1. [Terraform >= 1.6](https://developer.hashicorp.com/terraform/install)
2. [AWS CLI v2](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html)
3. [Docker Desktop](https://www.docker.com/products/docker-desktop/) (para build da imagem de ML)
4. Credenciais: `aws configure`

## Deploy em 2 fases

A Lambda container de ML **exige** que a imagem já exista no ECR. Por isso o
deploy é feito em duas fases, controladas pela variável `create_ml_lambda`.

### Fase 1 — Base + ECR (`create_ml_lambda = false`, padrão)

```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars   # defina db_password e allowed_cidr
terraform init
terraform plan
terraform apply
```

Isso cria VPC, RDS, Secrets, ECR, as 7 Lambdas de API e a HTTP API.

### Build & push da imagem de ML para o ECR

```bash
# variáveis (PowerShell)
$ACCOUNT = (aws sts get-caller-identity --query Account --output text)
$REGION  = "sa-east-1"
$REPO    = (terraform output -raw ecr_repository_url)

# login no ECR
# ATENCAO (Windows/PowerShell): o pipe "|" direto corrompe o token e gera
# "400 Bad Request". Grave o token em ASCII puro antes de passar ao docker:
$token = (aws ecr get-login-password --region $REGION)
$token | Out-File "$env:TEMP\ecr_token.txt" -Encoding ascii -NoNewline
Get-Content "$env:TEMP\ecr_token.txt" -Raw | docker login --username AWS --password-stdin "$ACCOUNT.dkr.ecr.$REGION.amazonaws.com"
Remove-Item "$env:TEMP\ecr_token.txt" -Force

# build + push (a partir de ../ml)
docker build -t "${REPO}:latest" ../ml
docker push "${REPO}:latest"
```

### Fase 2 — Lambda de ML + Step Functions

```bash
terraform destroy -var="create_ml_lambda=true"
```
