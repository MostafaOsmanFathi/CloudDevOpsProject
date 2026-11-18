# Terraform - Multi-cloud Infrastructure Provisioning

The same topology deployed on AWS and on Azure, in two self-contained
configurations with an identical module layout.

| Provider | Directory | Modules | Backend |
| -------- | --------- | ------- | ------- |
| AWS      | [`aws/`](./aws) | network, server, eks, ecr | S3 bucket + DynamoDB lock table |
| Azure    | [`azure/`](./azure) | network, server, aks, acr | Azure Storage account |

## 1. Layout

```text
terraform/
├── aws/
│   ├── main.tf / variables.tf / outputs.tf / locals.tf
│   ├── providers.tf / versions.tf / backend.tf / backend.hcl.example
│   ├── terraform.tfvars.example
│   ├── README.md                  # Full AWS guide
│   ├── bootstrap/                 # Phase 1: S3 state bucket and lock table
│   ├── tests/plan.tftest.hcl      # Offline plan test
│   └── modules/
│       ├── network/               # VPC, subnets, IGW, NAT, Network ACLs
│       ├── server/                # EC2 for Jenkins
│       ├── eks/                   # EKS cluster + worker node groups
│       └── ecr/                   # ECR repositories
└── azure/
    ├── main.tf / variables.tf / outputs.tf / locals.tf
    ├── providers.tf / versions.tf / backend.tf / backend.hcl.example
    ├── azure-credentials.env.example
    ├── terraform.tfvars.example
    ├── README.md                  # Full Azure guide
    ├── bootstrap/                 # Phase 1: Azure Storage account for the state
    ├── tests/plan.tftest.hcl      # Offline plan test
    └── modules/
        ├── network/               # VNet, subnets, NSGs, NAT gateway
        ├── server/                # VM for Jenkins
        ├── aks/                   # AKS cluster + node pools
        └── acr/                   # Azure Container Registry
```

## 2. Quick start

AWS:

```bash
cd terraform/aws
cd bootstrap && terraform init && terraform apply
cd ..
cp backend.hcl.example backend.hcl
terraform init -backend-config=backend.hcl
terraform plan && terraform apply
```

Azure:

```bash
cd terraform/azure
az login
cd bootstrap && terraform init && terraform apply
cd ..
cp backend.hcl.example backend.hcl
terraform init -backend-config=backend.hcl
terraform plan && terraform apply
```

Both phases and the credentials for each provider are documented in the
[AWS README](./aws/README.md) and the [Azure README](./azure/README.md).

## 3. Authentication

| Provider | Where to put the credentials |
| -------- | -------------------------- |
| AWS      | `~/.aws/credentials`, `AWS_ACCESS_KEY_ID` / `AWS_SECRET_ACCESS_KEY`, or the IAM instance profile |
| Azure    | `az login`, `ARM_CLIENT_ID` / `ARM_CLIENT_SECRET` / `ARM_SUBSCRIPTION_ID` / `ARM_TENANT_ID`, or `azure-credentials.env` |

Neither file is committed, and the repositories' `terraform/aws/.gitignore` and
`terraform/azure/.gitignore` block every `*.tfvars`, `*.tfstate*`, `.terraform/`
and `backend.hcl`.

## 4. Validation

```bash
terraform -chdir=terraform/aws fmt -recursive -check && terraform -chdir=terraform/aws validate
terraform -chdir=terraform/aws test

terraform -chdir=terraform/azure fmt -recursive -check && terraform -chdir=terraform/azure validate
terraform -chdir=terraform/azure test
```
