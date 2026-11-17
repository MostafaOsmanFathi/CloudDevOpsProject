# GitHub Actions - CI for the images

The workflows that build, scan and publish the microservice images.

## 1. Workflows

| Workflow | Trigger | What it does |
| -------- | ------- | ------------ |
| `ci-image.yml` | Called by the others | Reusable workflow: build, scan with Trivy, push to ECR, update the manifests |
| `frontend.yml` | Push, pull request, manual | Builds the frontend image |
| `auth-service.yml` | Push, pull request, manual | Builds the auth-service image |
| `roadmap-service.yml` | Push, pull request, manual | Builds the roadmap-service image |
| `validate.yml` | Pull request, manual | Validates the whole repository |

The three per-service workflows only pass the name, the context and the image
name to the reusable workflow, the same way the Jenkins shared library does it
for the Jenkins pipelines.

### Pipeline of the reusable workflow

```text
build  ──►  scan  ──►  update-manifests
```

| Job | Action |
| --- | ------ |
| `build` | Buildx build of the image, pushed to ECR with the `sha`, `latest` and branch tags. The BuildKit cache is stored in GitHub Actions, so the Maven and npm layers are reused. |
| `scan` | Trivy scans the image and the job fails on a `CRITICAL` or `HIGH` vulnerability that has a fix available |
| `update-manifests` | Rewrites the image in `kubernetes/<service>/deployment.yaml` with `kubectl set image --local` and commits the change |

On a pull request the image is built but not pushed, and the manifests are not
touched.

### Validation workflow

`validate.yml` runs on every pull request and checks the four parts of the
project:

| Job | Checks |
| --- | ------ |
| `terraform` | `terraform fmt -check`, `terraform validate` and `terraform test` |
| `ansible` | `ansible-lint` and the playbook syntax check |
| `kubernetes` | The manifests against the Kubernetes schemas with kubeconform, and the kustomization build |
| `images` | Builds all three images and scans them with Trivy |
| `compose` | Builds and starts the whole stack with Docker Compose and calls the three services |

## 2. Repository secrets and variables

Add these under **Settings -> Secrets and variables -> Actions**:

| Name | Type | Needed for |
| ---- | ---- | ----------- |
| `AWS_ROLE_ARN` | secret | Logging in to AWS with OIDC, the recommended way |
| `AWS_ACCESS_KEY_ID` | secret | Alternative to OIDC, a static access key |
| `AWS_SECRET_ACCESS_KEY` | secret | Alternative to OIDC |
| `AWS_REGION` | variable | The region of the ECR registry, `us-east-1` by default |

The workflow uses OIDC when `AWS_ROLE_ARN` is set and falls back to the static
keys otherwise. `configure-aws-credentials` supports both, so no change is
needed in the YAML.

### Setting up OIDC

```bash
aws iam create-open-id-connect-provider \
  --url https://token.actions.githubusercontent.com \
  --client-id-list sts.amazonaws.com \
  --thumbprint-list 6938fd4d98bab03faadb97b34396831e3780aea1
```

Then create a role that trusts the repository and attach
`AmazonEC2ContainerRegistryPowerUser` to it, plus `AmazonEKSClusterPolicy` if
the workflow should update the cluster.

## 3. First run

The images in the manifests use the placeholder account id `123456789012`.
Replace it with the real one before the first deployment:

```bash
cd kubernetes
sed -i "s/123456789012.dkr.ecr.us-east-1.amazonaws.com/<account-id>.dkr.ecr.us-east-1.amazonaws.com/g" \
  frontend/deployment.yaml auth-service/deployment.yaml roadmap-service/deployment.yaml
```

The ECR repositories themselves are created by the Terraform `ecr` module.

## 4. Running the workflows locally

The same steps can be reproduced on a workstation:

```bash
cd src/frontend
docker build -t ivolve-frontend:local .
trivy image --severity CRITICAL,HIGH ivolve-frontend:local
```
