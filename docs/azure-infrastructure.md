# iVolve on Azure — what broke, and how it was fixed

This document explains the Azure infrastructure of the iVolve DevOps project: what is
deployed, why the first `terraform apply` attempts failed, and exactly what was changed
so the same failures do not come back.

The project brief was written for **AWS** (VPC, EC2, EKS, ECR). This repository runs the
same design on **Azure** because no AWS account was available. Every Azure resource is
labelled with its AWS equivalent throughout.

---

## 1. What is deployed right now

| | |
| --- | --- |
| Region | **Denmark East** (`denmarkeast`) |
| Resource group | `ivolve-dev-rg` |
| Remote state | Storage account `ivolvedevopsstate23zkbj`, container `tfstate` |
| Jenkins VM | `ivolve-jenkins-server` — `Standard_B2s`, Ubuntu 22.04, `10.0.0.4`, public IP `9.205.91.181` |
| Container registry | `ivolveacrgf7a4e.azurecr.io` (ACR, SKU Standard) |
| Kubernetes | `ivolve-aks` — Kubernetes 1.36, Azure CNI, system pool `Standard_DS3_v2` × 1 node |
| Network | `ivolve-vnet` `10.0.0.0/16`, 2 public + 2 private subnets, 3 NSGs, 1 NAT gateway (`9.205.92.29`) |

Budgets, both fully used on purpose:

| Budget | Limit | Used by |
| --- | --- | --- |
| Regional vCPUs | 6 | Jenkins VM 2 + AKS system pool 4 |
| Public IP addresses | 3 | `ivolve-jenkins-ip` + `ivolve-nat-ip-1` + AKS API server |

Verified live: `kubectl get nodes` shows `aks-system-15165067-vmss000000` **Ready**
(Azure Linux 3.0, v1.36.5), and `terraform output` returns the ACR login server, the
Jenkins IP and the AKS OIDC issuer.

## 2. AWS → Azure naming map

| AWS (original brief) | Azure (this repository) | Notes |
| --- | --- | --- |
| VPC | Virtual Network | `10.0.0.0/16` |
| Public / private subnets | Subnets | one pair per availability zone |
| Internet Gateway | Azure default internet connectivity | no resource to create |
| NAT Gateway | NAT Gateway | same name, same role |
| Security Group / NACL | Network Security Group (NSG) | NSGs are stateful; there is no separate NACL |
| EC2 (Jenkins) | Virtual Machine | `Standard_B2s`, user-assigned identity instead of an IAM role |
| IAM role / instance profile | Managed identity + `AcrPull` role assignment | |
| EKS | Azure Kubernetes Service (AKS) | system pool + one user pool per AZ |
| ECR | Azure Container Registry (ACR) | |
| S3 backend + DynamoDB lock | Azurerm backend (blob lease) | no separate lock table |
| CloudFormation / CDK | Terraform | same modules as `terraform/aws` |

## 3. The failures, in order

1. `SkuNotAvailable` for `Standard_B2s` in `France Central` (Jenkins VM).
2. AKS: the same SKU reported as capacity-restricted, plus a long list of SKUs that
   "failed for Capacity Restrictions".
3. `SubnetNotFound` / `InvalidResourceReference` while the region move was half-applied.
4. `Provider produced inconsistent result after apply: Root object was present, but now absent`.
5. `AuthorizationFailed … Microsoft.Authorization/roleAssignments/write` for the ACR scope.
6. `PublicIPCountLimitReached — Cannot create more than 3 public IP addresses`.

## 4. Root causes

### 4.1 The subscription cannot use most VM families in most regions

The subscription is **Azure for Students**. Two independent gates decide what can be
deployed, and both have to pass:

* **Region policy** — an Azure Policy assignment (`sys.regionrestriction`) allows only
  `francecentral`, `uaenorth`, `switzerlandnorth`, `denmarkeast`, `austriaeast`.
* **SKU eligibility** — `az vm list-skus --location <region> --all` reports, per SKU,
  `NotAvailableForSubscription` with a *type*: `Location` (cannot be used there at all)
  or `Zone` (blocked only in those zones).

In `francecentral`, `uaenorth` and `switzerlandnorth` **every family that has a non-zero
vCPU quota** (B, Dv2/Dv3/Dv4, E, F, G, L, NC/NV) is `NotAvailableForSubscription` at
*location* level, while the families that look unrestricted (Dv6/v7, FX, M) have quota
`0`. So no VM could be created there at all — the B-family quota of 4/10 vCPUs was
irrelevant.

`denmarkeast` is the first region where real SKUs are usable (`Standard_B2s`,
`Standard_DS3_v2`, `D2_v2`, …). `austriaeast` works partially.

**Fix:** move the stack to Denmark East.

```bash
az vm list-usage --location denmarkeast -o table
az vm list-skus --location denmarkeast --resource-type virtualMachines --all -o json
```

### 4.2 The regional vCPU quota is 6, and AKS needs a 4-vCPU system node

`Total Regional vCPUs` is **6** in every region. AKS rules make the floor higher than
the brief assumed:

* a **system** node pool needs a **non-B** SKU of at least **4 vCPUs**;
* a user node pool needs at least 2 vCPUs;
* the system pool needs at least 1 node (a 1-node system pool is accepted).

Two availability zones mean a system pool **plus two user pools**, so
`4 + 2 + 2 = 8 vCPUs` — over budget before Jenkins is even counted. The only layout that
fits is Jenkins 2 + system pool 4, with the worker pools created but scaled to **0 nodes**
(`azurerm_kubernetes_cluster_node_pool` accepts `min_count = max_count = 0`).

### 4.3 The public IP quota is 3 — the hidden blocker

`az network list-usages --location denmarkeast` shows `Public IP Addresses = 3`. Each
`azurerm_public_ip`, each NAT gateway and each AKS egress consumes one. AKS with the
default `outbound_type = "loadBalancer"` creates its **own outbound public IP** on top of
the API server address, so the stack needed 4 and died with `PublicIPCountLimitReached`.

**Fix:** two changes together.

* `single_nat_gateway = true` — one NAT gateway instead of two (frees one IP, and halves
  the NAT bill).
* `outbound_type = "userAssignedNATGateway"` on the cluster — egress rides the NAT gateway
  that the network module already associated with the private subnets, so AKS creates no
  outbound IP.

Result: Jenkins IP + NAT IP + AKS API server = **3/3**.

### 4.4 The service principal needs two roles, and the grant is deleted with the RG

`Contributor` on the subscription is not enough for the `AcrPull` role assignments that
Terraform creates for the kubelet identity and the Jenkins identity. The principal also
needs **`User Access Administrator`** — and it must be granted on the resource group that
holds the ACR (`ivolve-dev-rg`), not on the state-backend resource group.

`az group delete` removes role assignments scoped to that resource group, so the grant has
to be re-created after every resource group rebuild.

```bash
az role assignment create \
  --assignee <service-principal-client-id> \
  --role "User Access Administrator" \
  --scope /subscriptions/<subscription-id>/resourceGroups/ivolve-dev-rg
```

### 4.5 Azure Resource Manager read flapping after a region move

Creating resources in a region the subscription has never used makes ARM reads
inconsistent for a while: `GET` on a just-created VNet or NSG returns **404**, and the
azurerm provider reports `Root object was present, but now absent`. This is not data loss
— `az resource list` shows the resources exist.

Two rules follow:

* **Never hand-create resources in the portal to satisfy Terraform.** It converts the
  problem into `a resource with the ID … already exists`, which then needs
  `terraform import` per object.
* Re-running `terraform apply` converges. If state and Azure have drifted badly (many
  `already exists` errors), wipe and rebuild: `az group delete`, empty the state with
  `terraform state rm`, then `apply`.

## 5. Every change that was made

| File | Change |
| --- | --- |
| `terraform/azure/variables.tf` | `location` default → `Denmark East`; `aks_node_vm_size` → `Standard_DS3_v2`; worker counts default to `0`; new `aks_system_node_count` / `aks_system_min_count` / `aks_system_max_count` |
| `terraform/azure/main.tf` | passes the new `aks_system_*` variables to the AKS module |
| `modules/aks/variables.tf` | separate system-pool counts; `node_vm_size` default `Standard_DS3_v2`; `min_count` / `max_count` default `0` |
| `modules/aks/main.tf` | system pool uses `var.system_*`; `outbound_type = "userAssignedNATGateway"`; explicit `upgrade_settings { max_surge = "10%" }` so the AKS API defaults do not create a perpetual plan diff |
| `terraform/azure/terraform.tfvars` | `location = "Denmark East"`, `single_nat_gateway = true`, AKS sizes/counts, system-pool counts |
| `terraform/azure/terraform.tfvars.example` | same defaults, so a fresh clone behaves identically |
| `terraform/azure/tests/plan.tftest.hcl` | test region updated |
| `terraform/azure/README.md` | new "Region and quota constraints" section |

Outside Terraform: the service principal was granted `User Access Administrator` on
`ivolve-dev-rg`, and the failed leftover AKS cluster was deleted once so Terraform could
recreate it with the corrected egress settings.

## 6. How to check it is still healthy

```bash
cd terraform/azure
terraform plan                       # expect: 0 to add, 0 to change, 0 to destroy

az vm list-usage --location denmarkeast -o table | grep "Total Regional vCPUs"   # 6 / 6
az network list-usages --location denmarkeast -o table | grep "Public IP"        # 3 / 3
az aks show -g ivolve-dev-rg -n ivolve-aks -o table
az aks get-credentials -g ivolve-dev-rg -n ivolve-aks --file /tmp/ivolve.kubeconfig
KUBECONFIG=/tmp/ivolve.kubeconfig kubectl get nodes
```

## 7. Runbook — when something fails again

| Symptom | What it means | What to do |
| --- | --- | --- |
| `SkuNotAvailable`, `NotAvailableForSubscription` | SKU not usable by this offer in this region | re-run `az vm list-skus --all`, pick an unrestricted SKU in a quota-bearing family; if none, change region within the policy allow-list |
| `PublicIPCountLimitReached` | the 3-IP regional cap | drop a NAT gateway, or set `outbound_type = "userAssignedNATGateway"` |
| `quota exceeded` / `cores` | the 6-vCPU cap | shrink node counts, or request a quota increase (Azure for Students often refuses) |
| `AuthorizationFailed … roleAssignments/write` | SP lacks `User Access Administrator` on the target RG | grant it (§4.4); remember it dies with the RG |
| `SubnetNotFound`, `ResourceNotFound`, `Root object was present, but now absent` | ARM read flapping in a fresh region | wait 60–120 s, re-run `terraform apply`; verify with `az resource list` first |
| `a resource with the ID … already exists` | state and Azure diverged | `terraform import` that one resource, or wipe and rebuild (§4.5) |

Before every apply, in this order:

1. `az account show` — right subscription.
2. `az policy assignment show --name sys.regionrestriction` — target region still allowed.
3. `az vm list-usage --location <region>` — vCPU and public IP headroom.
4. `az vm list-skus --location <region> --all` — the size you want is unrestricted **and**
   its family has quota > 0.
5. `terraform fmt -recursive && terraform validate && terraform test && terraform plan`.

## 8. Diagrams

| File | Contents |
| --- | --- |
| `diagrams/01-architecture.png` | whole stack: users, Jenkins VM, ACR, ArgoCD, AKS, network — AWS names in brackets |
| `diagrams/02-network.png` | VNet, the four subnets, NSG rules, NAT gateway egress, AKS API server |
| `diagrams/03-cicd-flow.png` | Jenkins pipeline stages → ACR → ArgoCD → AKS workloads |
| `diagrams/04-constraints-and-fixes.png` | region/SKU eligibility, the 6-vCPU and 3-IP budgets, RBAC and ARM notes |
| `diagrams/06-public-access.png` | how the app is exposed: public IP -> nginx on the Jenkins VM -> NodePort -> pods |
| `diagrams/05-egress-animation.gif` | animated pod egress: node → NAT gateway → internet |

The diagrams are generated from `diagrams/src/make_diagrams.py` (SVG → PNG/GIF via
`rsvg-convert` and `ffmpeg`); re-run `python3 src/make_diagrams.py` to regenerate them.

## 9. How the application is exposed to the network

The subscription has only **3 public IPs** per region, and the Jenkins VM, the NAT
gateway and the AKS API server already use all three. A public LoadBalancer for the
application is therefore impossible, and the ingress controller can only be internal
(which still needs a browser tunnel). The design that works with what exists:

```
browser ─▶ 9.205.91.181:80 ─▶ nginx on the Jenkins VM (10.0.0.4, public-subnet-1)
          ─▶ 10.0.10.4:30300 (NodePort Service frontend-nodeport)
          ─▶ frontend pods ─▶ ClusterIP auth-service / roadmap-service / mysql
```

| Piece | Why |
| --- | --- |
| `Azure Public IP 9.205.91.181` (AWS: Elastic IP) | the only public address available; it belongs to the Jenkins VM |
| NSG rule `JenkinsHttp` (port 80) | the subnet NSG already allowed 80, the NIC-level NSG did not |
| nginx reverse proxy on the Jenkins VM | forwards to the cluster; installed with `az vm run-command invoke` |
| `Service/frontend-nodeport` (NodePort 30300) | the pod IPs are Azure CNI addresses from the VNet, so the VM reaches the node directly |
| ClusterIP services + in-cluster DNS | the frontend calls auth/roadmap **server-side**, so the browser only ever talks to port 80 |

**AWS equivalent:** an ALB/NLB with an Elastic IP in front of the service, with
Security Groups in place of NSGs.

Trade-offs: the entry point is a single VM (not a load balancer), the NodePort is
reachable from anywhere inside the VNet, and the node IP is not guaranteed to stay
`10.0.10.4` if the node is replaced. If a public quota increase is ever granted, the
cleaner design is a public LoadBalancer (or a public ingress) and nginx is dropped.

## 10. How Argo CD is exposed to the network

Argo CD runs in the `argocd` namespace, installed with the official Helm chart
(`argo/argo-cd` 10.18.1, Argo CD v3.6.1) by `ansible/playbooks/argocd.yml`. The
same public-IP limit applies, so the UI is published from the Jenkins VM under a
free Microsoft name:

```
browser ─▶ http://ivolve-argocd.denmarkeast.cloudapp.azure.com
          ─▶ 9.205.89.178 (second public IP of the Jenkins NIC)
          ─▶ nginx vhost argocd ─▶ 10.0.10.4:30080 (NodePort argocd-server)
```

| Piece | Why |
| --- | --- |
| `argocd_dns_label = "ivolve-argocd"` | free Microsoft name; the application uses `ivolve` on the first public IP |
| second `ip_configuration` on the NIC, `10.0.0.5` static | Azure maps the public IP to a private address the guest must own |
| `ivolve-secondary-ip.service` on the VM | re-adds `10.0.0.5` at boot, because Azure does not configure secondary IPs inside the guest |
| `server.service.type: NodePort` (HTTP 30080) | no public IP is left for a LoadBalancer |
| `configs.params."server.insecure": "true"` | plain HTTP from the node to Argo CD, so no certificate is needed |

A Cloudflare Tunnel (`cloudflared.service`, `ansible/files/setup-cloudflared.sh`)
is installed as well, for an `https://` URL; read it with
`journalctl -u cloudflared --no-pager -o cat | grep -o 'https://[a-z0-9-]*\.trycloudflare\.com' | tail -1`.

Both names cost nothing: the public-IP quota is 3 and this uses the last free
slot (Jenkins app IP, NAT gateway, Argo CD IP).

**AWS equivalent:** an ALB in front of the Argo CD service, or an SSH tunnel
through the bastion.

Two findings worth remembering:

* Argo CD 3.x ignores `server.basehref`. Serving the UI under a path prefix
  (`http://9.205.91.181/argocd/`) loads the page but every asset resolves to `/`,
  so the wrong app is served. It has to be served by **name**, at `/`.
* Argo CD syncs the **Git revision**, not the working tree. An uncommitted change
  made with `kubectl` stays `OutOfSync` and is reverted by self-heal.

## 11. What is still left (not Terraform)

* **Ansible** configures the Jenkins VM (Java, Jenkins, Docker, Trivy). Until that runs,
  port 8080 on `9.205.91.181` stays closed.
* **ArgoCD** application manifest, then the Kubernetes manifests in `kubernetes/`
  (namespace, frontend, backend services, MySQL StatefulSet + headless Service,
  StorageClass, ConfigMap/Secret, Ingress).
* The **user node pools** stay at 0 nodes while the quota is 6 vCPUs. To run the
  microservices on dedicated workers, raise `aks_node_count` and `aks_max_count` together
  after a quota increase — or drop to one availability zone with a 2-vCPU system pool.
