# Requirements compliance

This page maps every section of `NTI Final Project.pdf` to the artifacts in this
repository and to the resources running in Azure. The brief was written for AWS;
the deployment runs on Azure because no AWS account was available. Each AWS name
in the diagrams has its Azure counterpart in [the AWS/Azure name map](aws-architecture/README.md#aws-name--what-actually-runs).

**Repository:** <https://github.com/MostafaOsmanFathi/CloudDevOpsProject>

---

## 1. GitHub Repository Setup

| | |
| --- | --- |
| Task | Create a `CloudDevOpsProject` repository with a README |
| Deliverable | Repository URL |
| Evidence | <https://github.com/MostafaOsmanFathi/CloudDevOpsProject>, [`README.md`](../README.md) |
| Status | **Met** |

## 2. Containerization with Docker

| | |
| --- | --- |
| Task | `docker-compose.yml` building and testing the app with the database locally; source from `Ibrahim-Adel15/iVolveFinalProject` |
| Deliverable | Compose file committed |
| Evidence | [`docker-compose.yml`](../docker-compose.yml) — mysql + auth-service + roadmap-service + frontend, shared volume and network; [`src/`](../src); CI job `compose` in [`.github/workflows/validate.yml`](../.github/workflows/validate.yml) runs `docker compose up --build --wait` and health-checks all services |
| Status | **Met** |

```bash
docker compose up --build -d
curl http://localhost:5000/health
```

## 3. Infrastructure Provisioning with Terraform

| | |
| --- | --- |
| Task | Four modules: Network (VPC, public/private subnets, IGW, NAT, NACL), Server (EC2 for Jenkins + SG), EKS (2 workers in different private subnets/AZs), ECR; S3 backend |
| Deliverable | Modules committed |
| Evidence | [`terraform/aws/modules/network`](../terraform/aws/modules/network) (`aws_network_acl` + rules), [`server`](../terraform/aws/modules/server), [`eks`](../terraform/aws/modules/eks) (`for_each` node group per AZ, 2 AZs), [`ecr`](../terraform/aws/modules/ecr), [`backend.tf`](../terraform/aws/backend.tf) (`backend "s3"`) + `bootstrap/` |
| Status | **Met (code)** — the AWS stack is committed but was never applied: there is no AWS account. The infrastructure actually running is the Azure stack in [`terraform/azure`](../terraform/azure), whose state matches exactly (`terraform plan` → `No changes`). [Network topology diagram](aws-architecture/02-network-topology.png). |
| Live check | `az network public-ip list -g ivolve-dev-rg -o table` → 3 IPs; `kubectl get nodes` → AKS node in the private subnet |

## 4. Configuration Management with Ansible

| | |
| --- | --- |
| Task | Playbooks for the Jenkins EC2: Java, Jenkins, Docker, Trivy; roles; dynamic inventory |
| Deliverable | Inventory, playbook and roles committed |
| Evidence | [`ansible/roles/java`](../ansible/roles/java), [`jenkins`](../ansible/roles/jenkins), [`docker`](../ansible/roles/docker), [`trivy`](../ansible/roles/trivy), [`base`](../ansible/roles/base); [`playbooks/site.yml`](../ansible/playbooks/site.yml); [`inventory/aws_ec2.yml`](../ansible/inventory/aws_ec2.yml) (`amazon.aws.aws_ec2` dynamic inventory) |
| Status | **Met (code, AWS)**; adapting roles for the Azure VM is partial. The Azure VM runs nginx, cloudflared and the Docker tooling, but **Jenkins itself is not installed there** — GitHub Actions performs CI instead. See [CI/CD mapping](ci-cd.md). |
| Live check | `ansible-playbook -i inventory/localhost.yml playbooks/argocd.yml` → `ok=… failed=0`; `ansible-lint playbooks/ roles/` → clean in CI |

## 5. Container Orchestration with Kubernetes

| | |
| --- | --- |
| Task | `ivolve` namespace; Deployment + Service per microservice; MySQL StatefulSet + headless Service; StorageClass; ConfigMap + Secret; frontend Ingress |
| Deliverable | YAML files committed |
| Evidence | [`kubernetes/kustomization.yaml`](../kubernetes/kustomization.yaml) renders 14 resources; [`namespace.yaml`](../kubernetes/namespace.yaml), `frontend/`, `auth-service/`, `roadmap-service/`, `mysql/statefulset.yaml`, `mysql/service.yaml` (`clusterIP: None`), `storageclass.yaml` (Azure Disk CSI / `StandardSSD_LRS`), `configmap.yaml`, `secret.yaml`, `frontend/ingress.yaml`, `frontend/nodeport.yaml` |
| Status | **Met** |
| Live check | `kubectl -n ivolve get pods` → 7 Running (frontend ×2, auth ×2, roadmap ×2, mysql ×1); `kubectl -n ivolve get pvc` → Bound; the app returns HTTP 200 at the URL in [access.md](access.md) |

## 6. Continuous Integration with Jenkins

| | |
| --- | --- |
| Task | Jenkins pipeline per microservice; stages Build Image, Scan Image, Push Image, Delete Image Locally, Update Manifests, Push Manifests; shared library |
| Deliverable | Jenkinsfiles + `vars/` directory |
| Evidence | GitHub Actions implements every stage: [`image-ci.yml`](../.github/workflows/image-ci.yml) builds, Trivy-scans and pushes, then its `gitops` job rewrites `images[].newTag` in `kubernetes/kustomization.yaml` and pushes; the `if: push to main` + `[skip ci]` commit prevents a loop. Full stage-by-stage mapping in [ci-cd.md](ci-cd.md). |
| Status | **Functionally covered by GitHub Actions; artifact gap**: there is no `Jenkinsfile` and no `vars/` shared-library directory. This is a deliberate substitution, documented rather than hidden. |
| Live check | GitHub Actions runs for `bbec163`, `7daefab`, `a673b8e` → `success`; each produced a `chore(gitops): pin images to sha-…` commit; ArgoCD rolled those tags out |

## 7. Continuous Deployment with Argo CD

| | |
| --- | --- |
| Task | Argo CD syncs and deploys the app into the cluster |
| Deliverable | Argo CD Application committed |
| Evidence | [`argocd/application.yaml`](../argocd/application.yaml) — source `https://github.com/MostafaOsmanFathi/CloudDevOpsProject.git`, `targetRevision: HEAD`, `path: kubernetes`, destination `ivolve`, `automated.enabled: true`, prune + self-heal. Installed via Helm by [`ansible/roles/argocd`](../ansible/roles/argocd) with chart `argo/argo-cd` 10.18.1 (Argo CD v3.6.1). |
| Status | **Met** |
| Live check | `kubectl -n argocd get application ivolve` → `sync=Synced health=Healthy`; `helm list -n argocd` → `deployed`; UI at the URLs in [access.md](access.md) |

## 8. Documentation

| | |
| --- | --- |
| Task | Comprehensive documentation: setup instructions and architecture overview |
| Evidence | [This page](requirements.md), [setup](setup.md), [architecture](architecture.md), [CI/CD](ci-cd.md), [access](access.md), [deployment history and fixes](azure-infrastructure.md), [AWS-style diagrams](aws-architecture/README.md), [Azure diagrams](diagrams/), [screenshots](../tasks/Terraform/README.md) |
| Status | **Met** |

---

## Summary

| # | Section | Status |
| --- | --- | --- |
| 1 | GitHub repository | Met |
| 2 | Docker Compose | Met |
| 3 | Terraform | Met (code) — AWS not applied, Azure applied |
| 4 | Ansible | Met (code) — Jenkins install on the Azure VM not applied |
| 5 | Kubernetes | Met |
| 6 | Jenkins CI | Functionally covered by GitHub Actions — `Jenkinsfile`/`vars/` absent |
| 7 | Argo CD | Met |
| 8 | Documentation | Met |
