# Terraform - Azure Infrastructure Provisioning

The Azure equivalent of the AWS project in the parent directory. It provisions
the same topology on Azure: the network, the Jenkins VM, an AKS cluster with two
worker nodes and a container registry. The state is stored in an Azure Storage
account.

## 1. Structure

```text
azure/
├── backend.tf                 # Azure Storage backend (partial config)
├── backend.hcl.example         # Template for the backend configuration
├── providers.tf                # AzureRM provider
├── versions.tf                 # azurerm and random providers
├── variables.tf                # Root variables
├── locals.tf                   # Common tags
├── main.tf                     # Wires the modules together
├── outputs.tf                  # Values exported for the other parts of the project
├── terraform.tfvars.example
├── bootstrap/                  # Phase 1: creates the Azure Storage state backend
├── tests/                      # Offline plan test, no Azure credentials needed
└── modules/
    ├── network/               # VNet, public/private subnets, NSGs, NAT gateway
    ├── server/                # VM for Jenkins + NSG + managed identity
    ├── aks/                   # AKS cluster + one node pool per availability zone
    └── acr/                   # Azure Container Registry
```

### What the modules create, versus the AWS modules

| AWS | Azure |
| --- | ----- |
| VPC, IGW, public/private subnets, NAT, NACLs | Virtual Network, public/private subnets, Network Security Groups, NAT Gateway |
| EC2 Jenkins server with a security group and an IAM role | Virtual Machine (Ubuntu 24.04) with an NSG, a public IP and a user assigned identity with `AcrPull` |
| EKS with two node groups, one per AZ | AKS with a system node pool and one user node pool per zone |
| ECR repositories | Azure Container Registry |
| S3 remote state + DynamoDB lock table | Azure Storage account backend. The azurerm backend locks through a blob lease, so there is no separate lock table |

## 2. Azure authentication

**The credentials never go into the Terraform files.** Pick one of the options
below.

### Option A - Azure CLI session (recommended for a workstation)

```bash
az login
az account set --subscription "<subscription-id>"
```

The provider picks the current subscription and the current tenant up
automatically, so `subscription_id`, `tenant_id`, `client_id` and `client_secret`
can stay empty in `terraform.tfvars`.

### Option B - service principal via environment variables

```bash
export ARM_CLIENT_ID="xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
export ARM_CLIENT_SECRET="xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"
export ARM_SUBSCRIPTION_ID="xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
export ARM_TENANT_ID="xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
```

### Option C - service principal via terraform.tfvars

```hcl
subscription_id = "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
tenant_id       = "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
client_id       = "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
client_secret   = "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"
```

`azure_client_secret` has to be set, it is marked `sensitive`. `az` is not
required for this form.

### Option D - managed identity

When Terraform runs on an Azure VM with a system assigned or user assigned
identity, the provider uses it automatically. No variables have to be set.

### Creating the service principal

```bash
az ad sp create-for-rbac --name ivolve-devops --role Contributor \
  --scopes /subscriptions/<subscription-id>
```

The output contains `appId`, `password` and `tenant`. Put them in the
environment variables from option B.

### Permissions the principal needs

`Contributor` is enough for the infrastructure. To grant the Jenkins VM the
`AcrPull` role on the ACR, the principal also needs permission to create role
assignments (`User Access Administrator` or a custom role with
`Microsoft.Authorization/roleAssignments/write`).

### Where NOT to put the credentials

| Location | Verdict |
| -------- | ------- |
| `terraform.tfvars` | Ignored by git, still plaintext on disk. Keep it for non secret values only |
| `*.tf` files | Never, they end up in git history |
| `backend.hcl` | Only the storage account and container names |

`terraform/azure/.gitignore` blocks `*.tfvars`, `*.tfstate*`, `backend.hcl`,
`.terraform/`.

## 3. Deployment, two phases

### Phase 1 - create the remote state (once per subscription)

```bash
cd terraform/azure/bootstrap
terraform init
terraform apply
```

This creates:

- the resource group `ivolvedevops-state-rg`
- the storage account `ivolvedevopsstate<random>` (versioned blob, private
  container, versioning on, HTTPS only, TLS 1.2)
- the blob container `tfstate`
- the `Storage Blob Data Contributor` role assignment, so Azure AD backend
  authentication works from the current account

### Phase 2 - the infrastructure

```bash
cd terraform/azure

cp backend.hcl.example backend.hcl
# paste the values printed by: terraform -chdir=bootstrap output backend_config

terraform init -backend-config=backend.hcl
cp terraform.tfvars.example terraform.tfvars
# adjust the values, especially admin_cidr and the subscription id

terraform plan
terraform apply
```

The azurerm backend locks the state with a blob lease, so no DynamoDB lock
table exists here.

### Useful commands

```bash
terraform fmt -recursive
terraform validate
terraform test              # offline plan test
terraform plan -out=tfplan
terraform apply tfplan
terraform output
terraform destroy
```

## 4. Authentication of the application created inside the cluster

The AKS kubelet identity has `AcrPull` on the registry. The Jenkins VM has a
user assigned identity with `AcrPull` on the registry, so it can pull the
images to build and push.

## 5. Outputs used by the other parts of the project

```bash
terraform output jenkins_public_ip   # VM that Ansible configures
terraform output acr_login_server    # registry the Jenkins pipeline pushes to
terraform output aks_cluster_name    # cluster target for the Kubernetes manifests
terraform output aks_oidc_issuer_url # OIDC issuer for workload identity
```

The Ansible playbooks and the Kubernetes manifests that live in the repository
can be run against the Azure cluster by pointing the inventory and the kube
context at the AKS cluster. The credentials are read from the same Azure
session.
