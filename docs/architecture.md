# Architecture overview

The brief was written for AWS. The project was built on Azure because no AWS
account was available, but the design is the same. There are two diagram sets:

- [**AWS-named diagrams**](aws-architecture/README.md) — the same running system
  drawn with AWS service names and the official AWS Architecture Icons, so it
  reads like the brief. Start with the [animated system overview](aws-architecture/01-system-overview-animated.gif).
- [**Azure-named diagrams**](diagrams/) — the actual services, including the
  quota/capacity fixes, the egress animation and the public-access path.

A name-by-name translation is in
[`docs/aws-architecture/README.md`](aws-architecture/README.md#aws-name--what-actually-runs).

## The system in one paragraph

A browser resolves `ivolve.denmarkeast.cloudapp.azure.com` (or the Argo CD name)
to a public IP attached to the Jenkins VM. nginx on that VM reverse-proxies to a
NodePort on the AKS worker node: port 30300 for the frontend, 30080 for Argo CD.
Inside the cluster the frontend calls `auth-service` and `roadmap-service` over
ClusterIP Services, and those call a MySQL StatefulSet backed by an Azure Disk
StorageClass. Images come from Docker Hub / ACR. GitHub Actions builds, Trivy
scans and pushes them, writes the new `sha-<commit>` tag into
`kubernetes/kustomization.yaml`, and Argo CD — configured with automated sync,
prune and self-heal — rolls the Deployments. Terraform owns the resource group,
VNet, subnets, NAT gateway, NSGs, AKS, ACR, managed identity and both public IPs;
Ansible owns Argo CD and the VM's proxy/tunnel units.

```
Browser ──▶ Azure DNS label ──▶ nginx on Jenkins VM ──▶ NodePort ──▶ EKS/AKS pods
                                                                    ├─ frontend
                                                                    ├─ auth-service
                                                                    ├─ roadmap-service
                                                                    └─ MySQL + Disk
GitHub ──▶ Actions (build/scan/push) ──▶ registry ──┐
             └──▶ new tag in kubernetes/ ──▶ Argo CD ──▶ rolling update
```

## Components

| Layer | AWS name in diagrams | Running on Azure |
| --- | --- | --- |
| DNS | Route 53 | public-IP DNS labels (`cloudapp.azure.com`) |
| Edge | Elastic IP + EC2/nginx | Azure Public IPs + Linux VM `ivolve-jenkins-server` |
| Network | VPC, 2 AZs, IGW, NAT, NACL | VNet `ivolve-vnet`, NSGs, NAT gateway |
| Compute | EKS + worker nodes | AKS `ivolve-aks`, `Standard_DS3_v2` system pool |
| Registry | ECR | ACR + Docker Hub (`mostafaosmanfathi/*`) |
| Storage | EBS gp3 | Azure Managed Disk `StandardSSD_LRS` |
| State | S3 + DynamoDB | Azure Blob container `tfstate` (blob lease) |
| CI | CodeBuild / CodePipeline | GitHub Actions (`image-ci.yml`) |
| CD | Argo CD Application | Argo CD v3.6.1 via Helm |

## Constraints that shaped it

The subscription is Azure for Students:

- Azure Policy allows only five regions; only `denmarkeast` had deployable B/D
  SKUs (`NotAvailableForSubscription` elsewhere).
- Regional vCPU quota is **6**: Jenkins `Standard_B2s` (2) + AKS system pool
  `Standard_DS3_v2` ×1 (4). User node pools are pinned to 0 nodes.
- Public IP quota is **3** and all three are allocated (app, Argo CD, NAT).
  That is why there is no public LoadBalancer and why both services share one VM.
- AKS uses a user-assigned NAT gateway for egress and an internal ingress; the
  browser-facing path is NodePort + nginx.

The failures, root causes and fixes are written up in
[`azure-infrastructure.md`](azure-infrastructure.md) and drawn in
[`diagrams/04-constraints-and-fixes.png`](diagrams/04-constraints-and-fixes.png).

## Request flow

The numbered browser-to-database walkthrough is
[`04-request-path.drawio`](aws-architecture/04-request-path.drawio) /
[PNG](aws-architecture/04-request-path.png). The network detail (subnets, AZs,
security groups, NAT) is
[`02-network-topology.png`](aws-architecture/02-network-topology.png).
