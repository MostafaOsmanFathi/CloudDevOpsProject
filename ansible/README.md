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
│   ├── localhost.yml            # Static inventory for a syntax check
│   ├── group_vars/
│   │   ├── all.yml              # Variables for every host
│   │   └── jenkins.yml          # Variables for the Jenkins group
│   └── host_vars/
├── playbooks/
│   ├── site.yml                 # Full configuration of the server
│   └── jenkins.yml              # Only Java and Jenkins
├── roles/
│   ├── base/                    # Base packages, timezone, chrony, sshd
│   ├── java/                    # Java runtime
│   ├── docker/                  # Docker, Compose plugin, Buildx
│   ├── trivy/                   # Trivy plus a daily image scan timer
│   └── jenkins/                 # Jenkins controller
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

## 6. Validation

```bash
ansible-playbook playbooks/site.yml --syntax-check
ansible-lint playbooks/ roles/
```

`ansible-lint` currently passes the `production` profile with no violations.
