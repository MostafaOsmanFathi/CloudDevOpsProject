# Kubernetes - Container Orchestration

The manifests that deploy the iVolve application on the EKS cluster created by
the Terraform `eks` module. Everything lives in the `ivolve` namespace.

## 1. Structure

```text
kubernetes/
├── namespace.yaml            # The ivolve namespace
├── configmap.yaml            # Non sensitive environment variables
├── secret.yaml               # Passwords and the session key
├── storageclass.yaml         # EBS storage class for the database
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

Two addons have to be present before the manifests can be applied.

**EBS CSI driver** - the StorageClass uses the `ebs.csi.aws.com` provisioner,
so the driver has to be installed and it needs an IAM role with the
`AmazonEBSCSIDriverPolicy` attached (IRSA).

```bash
helm repo add aws-ebs-csi-driver https://kubernetes-sigs.github.io/aws-ebs-csi-driver
helm upgrade --install aws-ebs-csi-driver aws-ebs-csi-driver/aws-ebs-csi-driver \
  --namespace kube-system --set controller.serviceAccount.annotations."eks\.amazonaws\.com/role-arn"=arn:aws:iam::<account-id>:role/ebs-csi-controller-role
```

**NGINX ingress controller** - the Ingress uses the `nginx` class.

```bash
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/aws/deploy.yaml
```

The images come from the Docker Hub repositories under the
`mostafaosmanfathi` account. If the repositories are public, no
`imagePullSecret` is needed; if they are private, create one as described in
[`.github/README.md`](../.github/README.md#3-first-run) and reference it from
each Deployment.

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

The ConfigMap holds the image references as well, which is what the image CI
reads when it updates the manifests. The actual `image:` field of a container
can not be templated, so the pipeline uses `kubectl set image`.

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
| `StorageClass/ivolve-storage` | `gp3` EBS volumes, encrypted, `WaitForFirstConsumer` |

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
`topologySpreadConstraints` on `topology.kubernetes.io/zone`, which matches the
two node groups of the EKS cluster.

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

The GitHub Actions image CI updates the manifests before it pushes them to the
repository. `kubectl set image --local` rewrites the image of the container
without needing a cluster:

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
