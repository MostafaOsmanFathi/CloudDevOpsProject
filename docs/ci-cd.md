# CI / CD explained

## What actually runs

CI is **GitHub Actions**; CD is **Argo CD**. The brief asks for Jenkins with a
shared library. This page maps every named Jenkins stage to the workflow step
that performs it so the substitution is visible rather than silent.

| Brief stage (Jenkins) | GitHub Actions implementation | File |
| --- | --- | --- |
| Build Image | `docker build` with `latest` and `sha-<commit>` tags, matrix over frontend / auth-service / roadmap-service | [`.github/workflows/image-ci.yml`](../.github/workflows/image-ci.yml) `image` job |
| Scan Image | `aquasecurity/trivy-action` on the local image before push, severity CRITICAL/HIGH, report-only | same |
| Push Image | `docker push` both tags to `mostafaosmanfathi/<service>` | same |
| Delete Image Locally | no equivalent needed — GitHub-hosted runners are ephemeral and discarded after the job | — |
| Update Manifests | sed rewrites `images[].newTag` in `kubernetes/kustomization.yaml` to `sha-<commit>` | `gitops` job |
| Push Manifests | `git commit -m "chore(gitops): pin images to sha-… [skip ci]"` and `git push origin main` | `gitops` job |
| Shared Library | no `vars/` directory; the reusable logic lives in one workflow and the Ansible [`argocd` role](../ansible/roles/argocd) | — |

`needs: image` makes the manifest commit happen only after all three images were
pushed, so the tag always exists. `[skip ci]` on the bot commit stops a loop.
Job-level `permissions: contents: write` is the only extra privilege.

Argo CD watches `HEAD` of `main`, path `kubernetes/`, with `automated.enabled:
true`, `prune` and `selfHeal`. A new tag commit is therefore a deployment:

```
push to main
  → build + Trivy + push  mostafaosmanfathi/<service>:sha-<commit>
  → gitops job edits kubernetes/kustomization.yaml and pushes
  → Argo CD detects the new revision, syncs, rolls the Deployments
```

Verified live: `kubectl -n argocd get application ivolve` → `sync=Synced
health=Healthy`; `kubectl -n ivolve get deploy` → all three images pinned to
`sha-<commit>`; `POST /api/v1/session` → 200.

## The Jenkins alternative

Section 6 names `Jenkinsfile` and a `vars/` shared library as deliverables.
Those artifacts are **not present** — GitHub Actions covers the behaviour but
not the named files. The intended Jenkins equivalent, drawn in
[`03-cicd-pipeline.png`](aws-architecture/03-cicd-pipeline.png), is:

```
EC2 (Jenkins controller)
  → vars/buildImage.groovy
  → vars/scanImage.groovy        (Trivy)
  → vars/pushImage.groovy
  → vars/updateManifests.groovy
  → Jenkinsfile per microservice with the six stages
```

The Ansible roles for a Jenkins controller already exist
([`ansible/roles/jenkins`](../ansible/roles/jenkins), plus `java`, `docker`,
`trivy`), and [`ansible/inventory/aws_ec2.yml`](../ansible/inventory/aws_ec2.yml)
is the dynamic inventory the brief asks for. The Azure VM does not currently run
Jenkins; CI runs in GitHub Actions instead.

## Validation workflow

[`.github/workflows/validate.yml`](../.github/workflows/validate.yml) runs on
pull requests:

- `terraform fmt -check`, `terraform validate`, `terraform test` for both AWS and Azure
- `ansible-galaxy collection install`, `ansible-lint`, playbook syntax check
- kubeconform on `kubernetes/` and `kubectl kustomize kubernetes/`
- image builds with Trivy as a hard gate (`exit-code: '1'`)
- `docker compose config`, `docker compose up --build --wait` and health checks

The image workflow keeps Trivy report-only (`exit-code: '0'`) so a vulnerable
base image does not block a demo deployment; change it to `'1'` to make it a gate.
