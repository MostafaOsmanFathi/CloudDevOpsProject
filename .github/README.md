# GitHub Actions - CI for the images

The workflows that build, scan and publish the microservice images to Docker
Hub under the `mostafaosmanfathi` namespace.

## 1. Workflows

| Workflow | Trigger | What it does |
| -------- | ------- | ------------ |
| `ci-image.yml` | Called by the others | Reusable workflow: build, scan with Trivy, push to Docker Hub, update the manifests |
| `frontend.yml` | Push, pull request, manual | Builds the `mostafaosmanfathi/frontend` image |
| `auth-service.yml` | Push, pull request, manual | Builds the `mostafaosmanfathi/auth-service` image |
| `roadmap-service.yml` | Push, pull request, manual | Builds the `mostafaosmanfathi/roadmap-service` image |
| `validate.yml` | Pull request, manual | Validates the whole repository |

The three per-service workflows pass the name, the context and the Docker Hub
repository name to the reusable workflow. The namespace is set in each caller
(`mostafaosmanfathi`) and is also the reusable workflow default.

### Pipeline of the reusable workflow

```text
build  ──►  scan  ──►  update-manifests
```

| Job | Action |
| --- | ------ |
| `build` | Buildx build of the image, pushed to Docker Hub with the `sha-<full commit sha>`, `latest` and branch tags. The BuildKit cache is stored in GitHub Actions, so the Maven and npm layers are reused. |
| `scan` | Trivy scans the immutable `sha-` tagged image and the job fails on a `CRITICAL` or `HIGH` vulnerability that has a fix available |
| `update-manifests` | Rewrites the image in `kubernetes/<service>/deployment.yaml` with `kubectl set image --local` and commits the change |

On a pull request the image is built but not pushed, and the manifests are not
touched. Fork pull requests need no Docker Hub credentials because login is
skipped when nothing is pushed.

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

## 2. Repository secrets

Add these under **Settings -> Secrets and variables -> Actions -> Repository
secrets**. Paste the values yourself; do not commit them.

| Name | Value | Needed for |
| ---- | ----- | ---------- |
| `DOCKERHUB_USERNAME` | Your Docker Hub username (`mostafaosmanfathi`) | Logging in to Docker Hub |
| `DOCKERHUB_TOKEN` | A Docker Hub **access token**, not your account password | Logging in to Docker Hub |

Create the token at <https://app.hub.docker.com> -> Account settings -> Security
-> Access tokens -> New access token. Give it **Write** access on the
repositories (Read, Write, Delete is fine too).

With `gh` already authenticated, the same two secrets can be added from a
terminal — each command prompts for the value:

```bash
gh secret set DOCKERHUB_USERNAME --repo MostafaOsmanFathi/CloudDevOpsProject
gh secret set DOCKERHUB_TOKEN    --repo MostafaOsmanFathi/CloudDevOpsProject
```

No AWS secrets or OIDC role are used by the image CI anymore. Any `AWS_*`
secrets left in the repository can be removed.

## 3. First run

1. Create the three repositories on Docker Hub if they do not exist yet:
   `frontend`, `auth-service` and `roadmap-service`, all under the
   `mostafaosmanfathi` account. The CI does not create them. Choose public or
   private to match your deployment.
2. Add the two secrets above.
3. Push to `src/<service>/` on `main` (or run the per-service workflow from the
   Actions tab with **Run workflow**). The images appear as
   `mostafaosmanfathi/<service>`.
4. If you chose **private** repositories, the Kubernetes nodes need a pull
   secret in the `ivolve` namespace:

   ```bash
   kubectl -n ivolve create secret docker-registry dockerhub \
     --docker-server=https://index.docker.io/v1/ \
     --docker-username=mostafaosmanfathi \
     --docker-password='<DOCKERHUB_TOKEN>' \
     --docker-email='<your email>'
   ```

   Then add `imagePullSecrets: [{ name: dockerhub }]` under `spec.template.spec`
   in each of the three deployments. Public repositories need none of this.

The manifests start at `mostafaosmanfathi/<service>:latest`; after the first
push the CI pins them to the immutable `sha-<commit>` tag.

## 4. Running the workflows locally

The same steps can be reproduced on a workstation:

```bash
cd src/frontend
docker build -t mostafaosmanfathi/frontend:local .
trivy image --severity CRITICAL,HIGH mostafaosmanfathi/frontend:local
```
