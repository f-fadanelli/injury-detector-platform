# injury-detector-platform

Infraestrutura (Terraform) e banco de dados do InjuryDetector. Provisiona
toda a stack AWS e orquestra o deploy das Lambdas de API e do serviço de ML.

Faz parte de um conjunto de 4 repositórios:

| Repo | Responsabilidade |
|---|---|
| `injury-detector` | Front-end (React + TS) |
| `injury-detector-api` | APIs Node |
| `injury-detector-ml` | Serviço de ML (V4) em container |
| **`injury-detector-platform`** | **Infra (Terraform) + banco (este repo)** |

## Estrutura

```
terraform/      # IaC: VPC, RDS, Lambdas, API Gateway, ECR, Step Functions, S3/CloudFront
db/
├── schema.sql              DDL (espelho do modelo da V4)
├── migrations/             alterações incrementais
├── seed_demo.py            popula atletas de demonstração
├── set_demo_credentials.mjs
└── set_demo_password.mjs
```

## Dependência entre repos

O Terraform empacota as Lambdas Node a partir do repo `injury-detector-api`.
Por padrão espera os repos como **pastas-irmãs**:

```
InjuryDetector/
├── injury-detector/
├── injury-detector-api/        <- src/ empacotado aqui
├── injury-detector-ml/
└── injury-detector-platform/   <- você está aqui
```

O caminho é configurável via a variável `api_src_dir`
(default `../../injury-detector-api/src`).

O serviço de ML é referenciado pela **imagem no ECR** (não precisa do código
local): basta a imagem ter sido buildada/pushada pelo repo `injury-detector-ml`.

## Deploy

Pré-requisitos: Terraform >= 1.6, AWS CLI, Docker (para a imagem de ML).

```bash
# 1. deps do repo de API (necessárias para empacotar as Lambdas)
cd ../../injury-detector-api/src && npm install --omit=dev

# 2. infra (2 fases: ver terraform/README.md)
cd ../../injury-detector-platform/terraform
cp terraform.tfvars.example terraform.tfvars   # defina db_password e allowed_cidr
terraform init
terraform apply                                 # Fase 1 (base + ECR)
#   build/push da imagem de ML (repo injury-detector-ml)
terraform apply -var="create_ml_lambda=true"    # Fase 2 (ML + Step Functions)
```

Detalhes em `terraform/README.md` e `terraform/FRONTEND_DEPLOY.md`.

