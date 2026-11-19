# Ansible - Configuration of the Jenkins server

Ansible roles and playbooks that configure the Jenkins EC2 instance created by
the Terraform `server` module. The server is prepared with Java, Jenkins,
Docker and Trivy so it can run the CI pipelines.

## 1. Structure

```text
ansible/
├── ansible.cfg                  # Inventory path, roles path, SSH settings
├── requirements.yml             # Collections needed by the dynamic inventory
├── inventory/
│   ├── aws_ec2.yml              # Dynamic inventory (amazon.aws.aws_ec2)
│   ├── azure_vm.yml             # Static inventory for the Azure Jenkins VM
│   ├── localhost.yml            # Static inventory for a syntax check
│   ├── group_vars/
│   │   ├── all.yml              # Variables for every host
│   │   └── jenkins.yml          # Variables for the Jenkins group
│   └── host_vars/
├── playbooks/
│   ├── site.yml                 # Full configuration of the server
│   ├── jenkins.yml              # Only Java and Jenkins
│   └── argocd.yml               # ArgoCD on AKS + the Application that syncs kubernetes/
├── roles/
│   ├── base/                    # Base packages, timezone, chrony, sshd
│   ├── java/                    # Java runtime
│   ├── docker/                  # Docker, Compose plugin, Buildx
│   ├── trivy/                  # Trivy plus a daily image scan timer
│   ├── jenkins/                 # Jenkins controller
│   └── argocd/                  # ArgoCD manifests + Application on the AKS cluster
└── collections/                 # Local collection install target
```

## 2. Setup

```bash
cd ansible
ansible-galaxy collection install -r requirements.yml
```

The `amazon.aws` collection provides the dynamic inventory plugin, `community.general`
provides the timezone module and `community.docker` the container modules.

## 3. Inventory

The dynamic inventory reads the running instances straight from AWS and selects
them with the tags that Terraform sets on the Jenkins instance:

| Tag       | Value                  | Used by the filter    |
| --------- | ---------------------- | --------------------- |
| `Role`    | `jenkins`              | `tag:Role: jenkins`   |
| `Project` | `ivolve`               | `tag:Project: ivolve` |
| `Name`    | `ivolve-jenkins-server`| for the host name     |

Change the region, the project name or the tag filter in
`inventory/aws_ec2.yml`. The file is the only place that has to be edited when
the inventory is reconfigured.

### Check what the inventory returns

```bash
ansible-inventory -i inventory/aws_ec2.yml --list
ansible-inventory -i inventory/aws_ec2.yml --graph
```

The plugin needs AWS credentials, so `~/.aws/credentials` or the
`AWS_ACCESS_KEY_ID` / `AWS_SECRET_ACCESS_KEY` environment variables have to be
in place. Use `aws_profile` in the file for a named profile.

## 4. Running the playbooks

```bash
cd ansible

# Full configuration of the Jenkins server
ansible-playbook playbooks/site.yml

# Only Jenkins and Java
ansible-playbook playbooks/jenkins.yml

# Dry run
ansible-playbook playbooks/site.yml --check --diff

# Limit to one host
ansible-playbook playbooks/site.yml --limit jenkins
```

The playbook installs:

- **Java** - `java-21-amazon-corretto-headless` on Amazon Linux,
  `openjdk-21-jre-headless` on Debian
- **Jenkins** - from the official `pkg.jenkins.io` repository, enabled and
  started, with the initial admin password stored in
  `/home/ec2-user/jenkins-initial-admin-password` (mode `600`)
- **Docker** - Docker CE, the Compose plugin and Buildx, the `ec2-user` added
  to the `docker` group
- **Trivy** - the binary in `/usr/local/bin/trivy`, a scan script in
  `/usr/local/bin/trivy-scan.sh` and a systemd timer that scans the local
  images every day

## 5. SSH access

The instance is created without an SSH key by default, so the Ansible
connection has to be established differently:

| Method | How |
| ------ | --- |
| Key pair | Set `ssh_key_name` in the Terraform variables, then point Ansible at the private key with `ansible_ssh_private_key_file` in `inventory/group_vars/all.yml` |
| SSM | Start an SSM session and use the tunnel, or set `ansible_host` to the instance IP and use the AWS key pair |

The private key path can also be passed without editing any file:

```bash
export ANSIBLE_PRIVATE_KEY_FILE=~/.ssh/ivolve-jenkins.pem
ansible-playbook playbooks/site.yml
```

## 6. ArgoCD on AKS

ArgoCD runs **inside the AKS cluster** and syncs the `kubernetes/` directory of
this repository. The Ansible playbook runs on the **control node** (the machine
with the `ivolve-aks` kubectl context) — the target is the cluster, not the
Jenkins VM.

```bash
cd ansible

# the context has to exist on the control node
az aks get-credentials -g ivolve-dev-rg -n ivolve-aks

ansible-playbook playbooks/argocd.yml --check
ansible-playbook playbooks/argocd.yml
```

What it does:

1. Adds the `argo` chart repository and installs **argo-cd 10.18.1**
   (Argo CD v3.6.1) with Helm into the `argocd` namespace, using
   `roles/argocd/files/argocd-aks-values.yaml`.
2. Waits for `argocd-server`, `argocd-repo-server`, `argocd-redis` and the
   `argocd-application-controller` StatefulSet.
3. Applies `argocd/application.yaml`, which creates the `ivolve` **Application**
   that syncs `kubernetes/` into the `ivolve` namespace with automated prune and
   self-heal.
4. Prints the admin password and the UI command.

The chart installs the CRDs itself, so the raw `install.yaml` is not needed. The
repository is public, so no repository credentials are required.

> Argo CD syncs the **Git revision**, not the working tree. Every change made
> directly with `kubectl` has to be committed and pushed, otherwise the
> Application stays `OutOfSync` and Argo CD tries to revert it.

### Reaching the UI

Argo CD is published through a **Cloudflare Tunnel** running on the Jenkins VM,
so it has a normal `https://` URL that works on any device - no certificate, no
`hosts` entry, and no extra public IP:

```
https://<name>.trycloudflare.com/     -> admin / password printed by the playbook
```

Read the current URL after (re)starting the service:

```bash
journalctl -u cloudflared --no-pager -o cat | grep -o 'https://[a-z0-9-]*\.trycloudflare\.com' | tail -1
```

The tunnel points at the Argo CD HTTP NodePort (`server.insecure: "true"`, so
TLS is terminated by Cloudflare rather than by Argo CD itself). To make it
permanent, create a **named tunnel** in the Cloudflare dashboard, put its token
in the unit file and restart - the URL then stops changing on reboot.

A plain-HTTP fallback also exists on the VM's public IP, by name:

```
http://argocd.ivolve.local/    (add: 9.205.91.181  argocd.ivolve.local)
```

Argo CD 3.x ignores `server.basehref`, so a path prefix (`/argocd/`) is not used:
the page would load but its assets resolve to `/`. Locally:

```bash
kubectl -n argocd port-forward svc/argocd-server 8080:80
# http://localhost:8080
```

### Azure inventory

`inventory/azure_vm.yml` points at `ivolve-jenkins-server` (`9.205.91.181`,
user `azureuser`). The VM is created without a key, so install the control
node's public key once:

```bash
az vm run-command invoke -g ivolve-dev-rg -n ivolve-jenkins-server \
  --command-id RunShellScript \
  --scripts "mkdir -p /home/azureuser/.ssh && chmod 700 /home/azureuser/.ssh \
    && echo '<public key>' >> /home/azureuser/.ssh/authorized_keys \
    && chown -R azureuser:azureuser /home/azureuser/.ssh \
    && chmod 600 /home/azureuser/.ssh/authorized_keys"
```

Then `ansible -i inventory/azure_vm.yml jenkins -m ping` should return `pong`.

## 7. Validation

```bash
ansible-playbook playbooks/site.yml --syntax-check
ansible-lint playbooks/ roles/
```

`ansible-lint` currently passes the `production` profile with no violations.
