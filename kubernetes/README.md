# Kubernetes - Container Orchestration

The manifests that deploy the iVolve application on the AKS cluster created by
the Terraform `aks` module (`terraform/azure`). Everything lives in the `ivolve`
namespace. The design was written for AWS/EKS; the Azure equivalents are noted
where they differ.

## 1. Structure

```text
kubernetes/
├── namespace.yaml            # The ivolve namespace
├── configmap.yaml            # Non sensitive environment variables
├── secret.yaml               # Passwords and the session key
├── storageclass.yaml         # Azure managed disk (Standard SSD) for the database
├── regcred.yaml.example      # Template for the Docker Hub pull secret
├── ingress-nginx.azure-values.yaml  # Ingress controller with an internal load balancer
├── mysql/
│   ├── service.yaml          # Headless service that governs the StatefulSet
│   └── statefulset.yaml      # MySQL with a persistent volume
├── auth-service/
│   ├── deployment.yaml
│   └── service.yaml
├── roadmap-service/
│   ├── deployment.yaml
│   └── service.yaml
├── frontend/
│   ├── deployment.yaml
│   ├── service.yaml
│   └── ingress.yaml          # Ingress for the web interface
└── kustomization.yaml        # Applies everything with one command
```

## 2. Prerequisites on the cluster

**Azure Disk CSI driver** - already part of AKS, nothing to install. The
StorageClass uses the built-in `disk.csi.azure.com` provisioner, so the MySQL
StatefulSet can provision a managed disk. (AWS equivalent: the EBS CSI driver,
`ebs.csi.aws.com`, with an IRSA role.)

**Docker Hub pull secret** - the three images are private repositories, so every
pod needs a pull secret named `dockerhub` in the `ivolve` namespace. All four
workloads already reference it through `imagePullSecrets`:

```bash
kubectl -n ivolve create secret docker-registry dockerhub \
  --docker-server=https://index.docker.io/v1/ \
  --docker-username=mostafaosmanfathi \
  --docker-password='<DOCKERHUB_ACCESS_TOKEN>' \
  --docker-email='<your email>'
```

Create the token at <https://app.hub.docker.com> -> Account settings -> Security
-> Access tokens (Read access is enough). `regcred.yaml.example` is a template;
the real secret is never committed (`kubernetes/regcred.yaml` is gitignored).

**NGINX ingress controller** - optional, only needed for `Ingress/frontend`.
Install it with an **internal** load balancer, because the subscription is
capped at 3 public IPs per region and Jenkins, the NAT gateway and the AKS API
server already use all three:

```bash
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm upgrade --install ingress-nginx ingress-nginx/ingress-nginx \
  --namespace ingress-nginx --create-namespace \
  -f kubernetes/ingress-nginx.azure-values.yaml
```

With an internal address the ingress is reachable from inside the VNet (the
Jenkins VM) or through `kubectl port-forward`.

## 3. Applying the manifests

```bash
# Everything at once
kubectl apply -k kubernetes/

# Or one resource at a time
kubectl apply -f kubernetes/namespace.yaml
kubectl apply -f kubernetes/configmap.yaml -f kubernetes/secret.yaml
kubectl apply -f kubernetes/storageclass.yaml
kubectl apply -f kubernetes/mysql/
kubectl apply -f kubernetes/auth-service/
kubectl apply -f kubernetes/roadmap-service/
kubectl apply -f kubernetes/frontend/
```

The StorageClass and the namespace are cluster scoped, everything else lives in
the `ivolve` namespace.

## 4. What each resource does

### Namespace, ConfigMap and Secret

| Resource | Purpose |
| -------- | ------- |
| `Namespace/ivolve` | Holds every resource of the project |
| `ConfigMap/ivolve-config` | Image references, service URLs, ports, database name and user |
| `Secret/ivolve-secret` | `MYSQL_ROOT_PASSWORD`, `MYSQL_PASSWORD` and `SESSION_SECRET` |

The ConfigMap holds image references as documentation of the images in use.
The actual `image:` field of a container can not be templated, so pinning a
Deployment to a specific build uses `kubectl set image` as shown in section 7.

The Secret uses `stringData`, so the values are readable in the file. Replace
them before a real deployment:

```bash
kubectl -n ivolve create secret generic ivolve-secret \
  --from-literal=MYSQL_ROOT_PASSWORD='...' \
  --from-literal=MYSQL_PASSWORD='...' \
  --from-literal=SESSION_SECRET='...' \
  --dry-run=client -o yaml | kubectl apply -f -
```

### MySQL

| Resource | Purpose |
| -------- | ------- |
| `Service/mysql` | Headless service, `clusterIP: None`, governing service of the StatefulSet |
| `StatefulSet/mysql` | One replica with a `volumeClaimTemplate` of 20 Gi |
| `StorageClass/ivolve-storage` | Azure managed disk, `StandardSSD_LRS`, ext4, `WaitForFirstConsumer` |

The headless service gives the database a stable identity,
`mysql.ivolve.svc.cluster.local`, which is the `DB_HOST` of the auth service.
The pod keeps its data in a PersistentVolumeClaim that is created from the
volume claim template and survives a restart of the pod.

### Microservices

Every microservice has a `Deployment` with two replicas and a `ClusterIP`
`Service`:

| Service | Port | Image |
| ------- | ---- | ----- |
| `frontend` | 3000 | `mostafaosmanfathi/frontend` |
| `auth-service` | 5000 | `mostafaosmanfathi/auth-service` |
| `roadmap-service` | 8080 | `mostafaosmanfathi/roadmap-service` |

The replicas are spread over the availability zones with a
`topologySpreadConstraints` on `topology.kubernetes.io/zone`. On this cluster the
constraint is a no-op: the subscription is capped at 6 regional vCPUs, so the AKS
user node pools run **0 nodes** and all six application pods plus MySQL land on
the single `Standard_DS3_v2` system node (4 vCPU / 14 GiB). The requests total
about 1.05 vCPU and 1.8 GiB, which fits. Raise the quota and the worker pools
before increasing `replicas`.

### Ingress

`Ingress/frontend` routes `frontend.ivolve.local` to the frontend service on
port 3000. Add the host to the DNS server or to `/etc/hosts` to open the
application in a browser:

```
<ingress-address>  frontend.ivolve.local
```

The TLS block is included as a comment, enable it after creating the
certificate:

```bash
kubectl -n ivolve create secret tls ivolve-tls --cert=tls.crt --key=tls.key
```

## 5. Probes

| Workload | Readiness | Liveness | Startup |
| -------- | --------- | -------- | ------- |
| `auth-service` | `GET /health`, checks the database | TCP on 5000 | - |
| `roadmap-service` | `GET /api/roadmap` | TCP on 8080 | `GET /api/roadmap`, 5 minutes |
| `frontend` | `GET /` | `GET /` | - |
| `mysql` | `mysqladmin ping` | `mysqladmin ping` | `mysqladmin ping`, 5 minutes |

The liveness probe of the auth service only checks the TCP port on purpose. The
health endpoint queries MySQL, so using it as a liveness probe would restart
the pods whenever the database is unavailable.

## 6. Verification

```bash
kubectl get all -n ivolve
kubectl get pvc -n ivolve
kubectl get endpoints -n ivolve
kubectl logs -n ivolve statefulset/mysql
kubectl describe pod -n ivolve -l app.kubernetes.io/name=frontend
```

Port forward to reach the application without the ingress:

```bash
kubectl port-forward -n ivolve svc/frontend 3000:3000
```

## 7. Updating the image references

The image CI pushes `mostafaosmanfathi/<service>:latest` and a
`:sha-<commit>` tag for every successful build. The Deployments use `latest`,
so they pick up the newest image on restart. To pin a Deployment to a specific
build, `kubectl set image --local` rewrites the image without needing a
cluster:

```bash
kubectl set image --local \
  -f frontend/deployment.yaml \
  "frontend=mostafaosmanfathi/frontend:<tag>" \
  -o yaml > frontend/deployment.yaml.tmp
mv frontend/deployment.yaml.tmp frontend/deployment.yaml
```

Against a live cluster the same command works without `--local`:

```bash
kubectl -n ivolve set image deployment/frontend \
  frontend=mostafaosmanfathi/frontend:<tag>
```

> `kustomize edit set image` does **not** work here. The transformer matches
> on the full repository name, not on the short one, so the key would have to be
> `mostafaosmanfathi/frontend` and not `frontend`.
