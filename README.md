# CloudDevOpsProject

Microservices DevOps training project (NTI x iVolve). The application source
code lives in [`src/`](./src), the AWS infrastructure in
[`terraform/`](./terraform), the server configuration in
[`ansible/`](./ansible) and the Kubernetes manifests in
[`kubernetes/`](./kubernetes).

| Service         | Technology               | Port |
| --------------- | ------------------------ | ---- |
| Frontend        | Node.js / Express / EJS  | 3000 |
| Auth Service    | Python / Flask           | 5000 |
| Roadmap Service | Java / Spring Boot       | 8080 |
| MySQL           | MySQL 8                  | 3306 |

## Running the stack locally (Docker Compose)

The repository ships a [`docker-compose.yml`](./docker-compose.yml) that builds
every microservice from its own Dockerfile and starts the application together
with a local MySQL database.

```bash
# Build the images and start everything in the background
docker compose up --build -d

# Check that all four containers are healthy
docker compose ps

# Follow the logs
docker compose logs -f frontend

# Stop the stack (add -v to also delete the database volume)
docker compose down -v
```

Then open <http://localhost:3000> and create an account to reach the DevOps
roadmap page.

### Verifying the stack

```bash
# Database + auth service health
curl http://localhost:5000/health
# {"database":"connected","status":"UP"}

# Roadmap service
curl http://localhost:8080/api/roadmap

# Sign up / log in through the auth service
curl -X POST http://localhost:5000/api/auth/signup \
  -H 'Content-Type: application/json' \
  -d '{"username":"john@example.com","password":"password123"}'

curl -X POST http://localhost:5000/api/auth/login \
  -H 'Content-Type: application/json' \
  -d '{"username":"john@example.com","password":"password123"}'
```

### Configuration

All ports, database credentials and secrets can be overridden with environment
variables or with a local `.env` file. Copy the template and edit it:

```bash
cp .env.example .env
```

`.env` must never be committed to git.

### Default local credentials

| Variable            | Default        |
| ------------------- | -------------- |
| `MYSQL_DATABASE`    | `ivolve`       |
| `MYSQL_USER`        | `ibrahim`      |
| `MYSQL_PASSWORD`    | `pass@123`     |
| `MYSQL_ROOT_PASSWORD` | `rootpassword` |
| `SESSION_SECRET`    | `change-me-in-k8s` |

## Infrastructure provisioning (Terraform)

The [`terraform/`](./terraform) directory holds the AWS modules for the network
(VPC, public and private subnets, IGW, NAT, Network ACLs), the Jenkins server
(EC2 + security group), the EKS cluster with two worker nodes in different
availability zones, and the ECR repositories. The state is kept in an S3 bucket
created by the `terraform/bootstrap` module.

```bash
# Phase 1 - remote state bucket and lock table
terraform -chdir=terraform/bootstrap init && terraform -chdir=terraform/bootstrap apply

# Phase 2 - infrastructure
cd terraform
cp backend.hcl.example backend.hcl    # paste the values from the bootstrap output
terraform init -backend-config=backend.hcl
terraform apply
```

Where to put the AWS credentials is documented in
[`terraform/README.md`](./terraform/README.md#2-aws-authentication).

## Server configuration (Ansible)

The [`ansible/`](./ansible) directory holds the roles that configure the Jenkins
EC2 instance: Java, Jenkins, Docker and Trivy. The inventory is dynamic and
reads the running instances from AWS using the tags that Terraform sets on
them.

```bash
cd ansible
ansible-galaxy collection install -r requirements.yml
ansible-playbook playbooks/site.yml
```

Details are in [`ansible/README.md`](./ansible/README.md).

## Container orchestration (Kubernetes)

The [`kubernetes/`](./kubernetes) directory holds the manifests for the
`ivolve` namespace: a Deployment and a Service per microservice, a MySQL
StatefulSet with a headless service and a StorageClass, the ConfigMap and the
Secret with the environment variables, and an Ingress for the frontend.

```bash
kubectl apply -k kubernetes/
```

Details are in [`kubernetes/README.md`](./kubernetes/README.md).

## Continuous integration (GitHub Actions)

The [`.github/workflows`](./.github/workflows) directory holds the workflows
that build, scan with Trivy and push the microservice images to ECR, plus a
validation workflow that checks the Terraform, the Ansible, the manifests and
the Docker Compose stack on every pull request.

```bash
# The reusable workflow is called by frontend.yml, auth-service.yml
# and roadmap-service.yml. The AWS credentials are read from the
# repository secrets AWS_ROLE_ARN or AWS_ACCESS_KEY_ID / AWS_SECRET_ACCESS_KEY.
```

Details are in [`.github/README.md`](./.github/README.md).
