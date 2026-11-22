# Access and live URLs

Everything is reached through the Jenkins VM in `denmarkeast`. The subscription
allows only 3 public IPs per region and all three are used, so there is no public
load balancer: nginx on the VM reverse-proxies to the cluster.

## Public entry points

| What | URL | How it resolves |
| --- | --- | --- |
| **Application** | <http://ivolve.denmarkeast.cloudapp.azure.com/> | Azure public-IP DNS label → `9.205.91.181` → nginx → frontend NodePort 30300 |
| **Argo CD** | <http://ivolve-argocd.denmarkeast.cloudapp.azure.com/> | second public-IP DNS label → `9.205.89.178` → same nginx → Argo CD NodePort 30080 |
| Argo CD (HTTPS) | <https://charger-compilation-haven-newport.trycloudflare.com/> | Cloudflare Tunnel from the VM → Argo CD NodePort; the URL changes when the tunnel restarts |
| Application (raw IP) | <http://9.205.91.181/> | same as the app URL, no DNS needed |
| AKS API | `az aks show -g ivolve-dev-rg -n ivolve-aks --query fqdn` | cluster API server, kubeconfig via `az aks get-credentials` |

Both Microsoft-owned names were checked live: `curl -o /dev/null -w '%{http_code}'`
returns **200** for each. Argo CD's admin login `POST /api/v1/session` also
returns 200.

### Why two public IPs on one VM

The free Microsoft name comes from a DNS *label on a public IP*, so one name per
IP. The second IP (`9.205.89.178`) is a secondary `ip_configuration` on the same
NIC. Azure does not configure secondary IPs inside the guest, so a small systemd
unit re-adds `10.0.0.5` at boot (`ansible/files/ivolve-secondary-ip.service`).
nginx listens on `0.0.0.0:80`, so it answers for both addresses.

The proxy config is [`ansible/files/ivolve-proxy.conf`](../ansible/files/ivolve-proxy.conf):

```
/         → 10.0.10.4:30300   (frontend NodePort)
/argocd/  → 10.0.10.4:30080   (Argo CD HTTP NodePort)
```

Argo CD 3.x ignores `server.basehref`, so it is served under its own hostname at
`/`, not under a path prefix — a `/argocd/` path loads the page but its assets
resolve to `/`.

### Optional local fallback

If you would rather use a hosts entry than a public name:

```
9.205.91.181  argocd.ivolve.local
```

Then open <http://argocd.ivolve.local/>. Locally without any DNS:

```bash
kubectl -n argocd port-forward svc/argocd-server 8080:80
# http://localhost:8080
```

## Argo CD login

```bash
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath='{.data.password}' | base64 -d
```

Username `admin`. Rotate this password for anything beyond a lab.

## Network facts

| | |
| --- | --- |
| Resource group | `ivolve-dev-rg` |
| Region | `denmarkeast` |
| VNet | `ivolve-vnet` 10.0.0.0/16 |
| Public subnets | 10.0.0.0/24, 10.0.1.0/24 |
| Private subnets | 10.0.10.0/24, 10.0.11.0/24 |
| Jenkins VM | `ivolve-jenkins-server`, `Standard_B2s` (2 vCPU), primary IP 10.0.0.4 |
| AKS | `ivolve-aks`, system pool `Standard_DS3_v2` ×1 (4 vCPU), user pools 0 nodes |
| Public IPs | `9.205.91.181` (app), `9.205.89.178` (Argo CD), `9.205.92.29` (NAT gateway) |
| Regional budget | 6 vCPU total, 3/3 public IPs used |

See [`docs/azure-infrastructure.md`](azure-infrastructure.md) for the failures
that shaped this design (SKU restrictions, quota, RBAC, public-IP limit) and the
diagrams in [`docs/aws-architecture/`](aws-architecture/README.md) for the
AWS-named view.
