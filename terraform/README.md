# Terraform - AWS Infrastructure Provisioning

> The same stack exists for Azure in [`azure/`](./azure), with the same module
> layout, the same variables and the same two phase deployment.

Terraform modules that provision the AWS infrastructure for the iVolve DevOps
project: the network, the Jenkins server, the EKS cluster and the ECR
registries. The state is stored remotely in an S3 bucket.

## 1. Structure

```text
terraform/
├── backend.tf                 # S3 backend (partial config, values in backend.hcl)
├── backend.hcl.example        # Template for the backend configuration
├── providers.tf               # AWS provider + default tags
├── variables.tf               # Root variables
├── locals.tf                  # Common tags
├── main.tf                    # Wires the four modules together
├── outputs.tf                 # Values exported for the other parts of the project
├── terraform.tfvars.example   # Template for the variable values
├── bootstrap/                 # Phase 1: creates the S3 state bucket + lock table
├── tests/                     # Offline plan test, runs without AWS credentials
└── modules/
    ├── network/               # VPC, public/private subnets, IGW, NAT, Network ACLs
    ├── server/                # EC2 instance for Jenkins + security group + IAM role
    ├── eks/                   # EKS cluster + one node group per availability zone
    └── ecr/                   # ECR repositories for the microservices
```

### What each module creates

**`modules/network`**

| Resource                | Details                                                     |
| ----------------------- | ----------------------------------------------------------- |
| `aws_vpc`               | DNS support and DNS hostnames enabled                        |
| `aws_subnet` (public)   | One per availability zone, auto public IPs, ELB tags         |
| `aws_subnet` (private)  | One per availability zone, internal ELB tags                 |
| `aws_internet_gateway`  | Attached to the VPC                                          |
| `aws_eip` + `aws_nat_gateway` | One NAT gateway per AZ (or a single one with `single_nat_gateway = true`) |
| `aws_route_table`       | Public route to the IGW, private routes to the NAT gateways  |
| `aws_network_acl`       | Custom NACL for the public and the private subnets           |

**`modules/server`** - the Jenkins server.

| Resource                | Details                                                      |
| ----------------------- | ------------------------------------------------------------ |
| `aws_instance`          | Amazon Linux 2023, encrypted gp3 root volume, IMDSv2         |
| `aws_security_group`    | SSH from `admin_cidr`, Jenkins UI on 8080, VPC internal      |
| `aws_eip`               | Stable public address for the server                         |
| `aws_iam_role`          | `AmazonSSMManagedInstanceCore` for keyless shell access      |

**`modules/eks`** - the Kubernetes cluster.

| Resource                | Details                                                      |
| ----------------------- | ------------------------------------------------------------ |
| `aws_eks_cluster`       | Private subnets, API server logs enabled                     |
| `aws_eks_node_group`    | One group per private subnet, so 2 workers in 2 AZs          |
| `aws_iam_role`          | Control plane role and node role (`AmazonEKS_CNI_Policy`, ECR read) |
| `aws_eks_addon`         | Managed `vpc-cni` and `coredns` addons                      |

**`modules/ecr`** - one repository per microservice
(`frontend`, `auth-service`, `roadmap-service`), scan on push, immutable
tags, lifecycle policy that keeps the last 10 images and a repository policy
that allows push and pull inside the account.

---

## 2. AWS authentication

**The keys never go into the Terraform files.** The provider uses the standard
AWS credential chain, so pick one of the options below.

### Option A - environment variables (recommended for CI/CD)

```bash
export AWS_ACCESS_KEY_ID="AKIAIOSFODNN7EXAMPLE"
export AWS_SECRET_ACCESS_KEY="wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY"
export AWS_SESSION_TOKEN="..."   # only for temporary STS credentials
export AWS_REGION="us-east-1"
```

### Option B - `~/.aws/credentials` (recommended for a workstation)

Create the file if it does not exist:

```bash
mkdir -p ~/.aws
cat > ~/.aws/credentials <<'EOF'
[default]
aws_access_key_id = AKIAIOSFODNN7EXAMPLE
aws_secret_access_key = wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY
EOF

chmod 600 ~/.aws/credentials
```

To use a named profile instead of `default`, add it to the same file:

```ini
[ivolve]
aws_access_key_id = AKIAIOSFODNN7EXAMPLE
aws_secret_access_key = wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY
```

and point Terraform at it:

```bash
terraform plan -var="aws_profile=ivolve"
```

or set it permanently in `terraform.tfvars`:

```hcl
aws_profile = "ivolve"
```

### Option C - SSO / IAM Identity Center

```bash
aws configure sso        # once, needs the AWS CLI
aws sso login --profile ivolve
```

then use `aws_profile = "ivolve"` in `terraform.tfvars`. The session token is
refreshed automatically by `aws sso login`.

### Option D - instance profile

When Terraform runs on an EC2 instance that already has an IAM role attached,
nothing has to be configured at all. The provider picks up the role
automatically.

### Where NOT to put the credentials

| Location | Verdict |
| -------- | ------- |
| `terraform.tfvars` | Git ignored, but still on disk in plain text. Use only for non secret values. |
| `*.tf` files | Never. They end up in git history. |
| `backend.hcl` | Only bucket names and regions, never keys. |
| `*.auto.tfvars` | Same as `terraform.tfvars`, git ignored. |

The repository ignores `*.tfvars`, `*.tfstate*`, `backend.hcl` and `.terraform/`
so a secret cannot be committed by accident.

### Permissions the user needs

For a training account the simplest option is to attach `AdministratorAccess` to
the IAM user. A scoped-down policy needs at least:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "ec2:*", "eks:*", "iam:*", "elasticloadbalancing:*",
        "s3:*", "dynamodb:*", "ecr:*", "elasticache:*",
        "logs:*", "kms:*", "autoscaling:*"
      ],
      "Resource": "*"
    }
  ]
}
```

### Creating the IAM user and the access key

In the AWS console: **IAM -> Users -> Create user** (name it `ivolve-devops`),
attach the policy, then **Security credentials -> Create access key**. The
secret is shown only once.

With the CLI:

```bash
aws iam create-user --user-name ivolve-devops
aws iam attach-user-policy --user-name ivolve-devops --policy-arn arn:aws:iam::aws:policy/AdministratorAccess
aws iam create-access-key --user-name ivolve-devops --output json
```

Store the result in the shared credentials file:

```bash
aws-set-credentials
```

The helper reads the key id and the secret without echoing them, writes both the
`[default]` and the `[ivolve]` profiles into `~/.aws/credentials` with `600`
permissions and verifies the result with `aws sts get-caller-identity`.

---

## 3. Deployment

The remote state has to exist before the main configuration can be initialised,
so the deployment runs in two phases.

### Phase 1 - create the remote state (once per account)

```bash
cd terraform/bootstrap
terraform init
terraform apply
```

This creates:

- the S3 bucket `ivolve-devops-tfstate-<account id>` (versioned, encrypted,
  public access blocked)
- the DynamoDB table `ivolve-devops-tfstate-locks` used to lock the state

### Phase 2 - the infrastructure

```bash
cd terraform

cp backend.hcl.example backend.hcl
# paste the bucket and table names printed by: terraform -chdir=bootstrap output backend_config

terraform init -backend-config=backend.hcl
cp terraform.tfvars.example terraform.tfvars
# adjust the values, especially admin_cidr

terraform plan
terraform apply
```

### Useful commands

```bash
terraform fmt -recursive
terraform validate
terraform test              # offline plan test, no credentials needed
terraform plan -out=tfplan
terraform apply tfplan
terraform output                      # all outputs
terraform output jenkins_public_ip    # one value
terraform state list
terraform destroy                     # tear everything down
```

---

## 4. Outputs used by the other parts of the project

```bash
terraform output jenkins_public_ip    # EC2 that Ansible configures
terraform output eks_cluster_name     # namespace target for the Kubernetes manifests
terraform output ecr_repository_urls  # registries the Jenkins pipeline pushes to
terraform output vpc_id
terraform output private_subnet_ids
```

The Kubernetes manifests of the next stage use the same names (`ivolve`
namespace, `ivolve-eks` cluster) and read their credentials from a Kubernetes
Secret instead of the Terraform state.
