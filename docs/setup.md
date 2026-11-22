# Setup instructions

Two paths: run the stack locally with Docker Compose, or rebuild the deployed
Azure environment. The live environment is already up; the URLs are in
[access.md](access.md).

## A. Local development (Docker Compose)

```bash
git clone https://github.com/MostafaOsmanFathi/CloudDevOpsProject.git
cd CloudDevOpsProject
cp .env.example .env            # adjust if needed; never commit .env
docker compose up --build -d
docker compose ps               # mysql, auth, roadmap, frontend
```

Open <http://localhost:3000>. Verify the other services:

```bash
curl http://localhost:5000/health        # auth + MySQL
curl http://localhost:8080/api/roadmap   # roadmap service
```

Stop with `docker compose down` (add `-v` to remove the database volume).

## B. Azure environment

### 1. Credentials

The service principal needs `Contributor` on the resource group and `User Access
Administrator` where the ACR role assignment is created. See
[`terraform/azure/README.md`](../terraform/azure/README.md#2-azure-authentication)
for the exact variables. Do not commit `*.hcl` backend files or credentials.

### 2. Backend, then infrastructure

```bash
cd terraform/azure/bootstrap
terraform init && terraform apply

cd terraform/azure
cp backend.hcl.example backend.hcl
terraform init -backend-config=backend.hcl
terraform plan      # expect the SKU/count choices below
terraform apply
```

The defaults matter: `location = "Denmark East"`, `vm_size = "Standard_B2s"`,
`aks_node_vm_size = "Standard_DS3_v2"`, `aks_node_count = 0`. The subscription
policy only allows five regions and only `denmarkeast` has deployable B/D SKUs;
the regional vCPU quota is 6 (2 Jenkins + 4 AKS system pool). Every change must
end with `terraform plan` reporting `No changes`.

### 3. Cluster access and workloads

```bash
az aks get-credentials -g ivolve-dev-rg -n ivolve-aks
kubectl create secret docker-registry dockerhub -n ivolve \
  --docker-server=https://index.docker.io/v1/ \
  --docker-username=mostafaosmanfathi \
  --docker-password='<DOCKERHUB_ACCESS_TOKEN>'
kubectl apply -k kubernetes/
kubectl -n ivolve get pods        # 7 Running
kubectl -n ivolve get pvc         # Bound
```

`kubernetes/regcred.yaml` is gitignored; only the `.example` is committed.

### 4. Argo CD

Installed by Ansible, not by hand:

```bash
cd ansible
ansible-galaxy collection install -r requirements.yml
ansible-playbook -i inventory/localhost.yml playbooks/argocd.yml
```

This installs chart `argo/argo-cd` 10.18.1 into namespace `argocd` and applies
[`argocd/application.yaml`](../argocd/application.yaml). Confirm:

```bash
helm list -n argocd
kubectl -n argocd get application ivolve
```

### 5. Public entry points

The DNS labels are part of Terraform (`jenkins_dns_label`, `argocd_dns_label`).
nginx on the VM and the systemd units are configured in
[`ansible/files/`](../ansible/files). Re-apply them after replacing the VM:

```bash
# copy ivolve-proxy.conf into /etc/nginx/conf.d/ivolve-proxy.conf on the VM
# install ivolve-secondary-ip.service, then:
systemctl daemon-reload && systemctl enable --now ivolve-secondary-ip
nginx -t && systemctl reload nginx
# optional HTTPS URL:
bash ansible/files/setup-cloudflared.sh
```

### 6. Verify

```bash
curl -s -o /dev/null -w '%{http_code}' http://ivolve.denmarkeast.cloudapp.azure.com/
curl -s -o /dev/null -w '%{http_code}' http://ivolve-argocd.denmarkeast.cloudapp.azure.com/
```

Both should print 200. Full details in [access.md](access.md).

## C. CI/CD

No manual step is needed after a push to `main`:

```
push → GitHub Actions builds/scans/pushes sha-<commit>
     → gitops job rewrites kubernetes/kustomization.yaml and pushes [skip ci]
     → Argo CD syncs and rolls the Deployments
```

Repository secrets needed: `DOCKERHUB_USERNAME`, `DOCKERHUB_TOKEN`. See
[ci-cd.md](ci-cd.md) and [`.github/README.md`](../.github/README.md).
