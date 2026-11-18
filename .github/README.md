# GitHub Actions - image CI

One workflow, one job, three images: `image-ci.yml` builds each service, scans
it with Trivy, and pushes it to Docker Hub under `mostafaosmanfathi/`.

| Service | Image |
| ------- | ----- |
| `frontend` | `mostafaosmanfathi/frontend` |
| `auth-service` | `mostafaosmanfathi/auth-service` |
| `roadmap-service` | `mostafaosmanfathi/roadmap-service` |

Triggers: push to `main`, pull request, manual **Run workflow**. On pull
requests the images are built and scanned but not pushed (no credentials are
needed). Every image gets a `latest` tag and a `sha-<commit>` tag.

Steps per image: `docker build` -> Trivy scan -> `docker push`. The scan runs
on the locally built image, before the push. It reports fixable
`CRITICAL`/`HIGH` vulnerabilities in OS and library packages; Trivy caches its
vulnerability database automatically. The scan is currently report-only
(`exit-code: '0'`) because the existing base images/dependencies have known
findings. Set `exit-code: '1'` in `image-ci.yml` to make it a hard gate once
those are fixed.

## Repository secrets

Add these under **Settings -> Secrets and variables -> Actions -> Repository
secrets** (paste the values yourself, never commit them):

| Name | Value |
| ---- | ----- |
| `DOCKERHUB_USERNAME` | `mostafaosmanfathi` |
| `DOCKERHUB_TOKEN` | A Docker Hub **access token** with Write access, not your password |

```bash
gh secret set DOCKERHUB_USERNAME --repo MostafaOsmanFathi/CloudDevOpsProject
gh secret set DOCKERHUB_TOKEN    --repo MostafaOsmanFathi/CloudDevOpsProject
```

Create the token at <https://app.hub.docker.com> -> Account settings ->
Security -> Access tokens. Create the three repositories on Docker Hub first if
they do not exist; the workflow does not create them.

If the repositories are private, add a pull secret to the `ivolve` namespace
and reference it with `imagePullSecrets` in each Deployment. Public
repositories need none:

```bash
kubectl -n ivolve create secret docker-registry dockerhub \
  --docker-server=https://index.docker.io/v1/ \
  --docker-username=mostafaosmanfathi \
  --docker-password='<DOCKERHUB_TOKEN>' \
  --docker-email='<your email>'
```

## Other workflow

`validate.yml` still runs on pull requests and checks Terraform, Ansible, the
Kubernetes manifests, the images and the Docker Compose stack.

## Run it locally

```bash
docker build -t mostafaosmanfathi/frontend:local src/frontend
trivy image --severity CRITICAL,HIGH --ignore-unfixed mostafaosmanfathi/frontend:local
```
