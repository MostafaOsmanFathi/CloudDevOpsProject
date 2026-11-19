#!/usr/bin/env python3
"""Generate the iVolve Azure infrastructure diagrams (SVG -> PNG/GIF).

Run:  python3 make_diagrams.py
Output lands next to this file's parent directory (docs/diagrams).
"""
import html
import os
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.dirname(HERE)

AZURE = "#0078D4"
AZURE_D = "#004E8C"
AWS = "#FF9900"
AWS_D = "#B36B00"
PANEL = "#F4F7FB"
PANEL2 = "#EAF1F9"
BORDER = "#C7D3E0"
TEXT = "#1B2733"
MUTED = "#5A6B7B"
GREEN = "#107C10"
RED = "#D13438"
AMBER = "#E8A33D"
WHITE = "#FFFFFF"


def esc(s):
    return html.escape(str(s), quote=True)


def rect(x, y, w, h, fill=PANEL, stroke=BORDER, rx=10, sw=1.4, dash=None):
    d = f' stroke-dasharray="{dash}"' if dash else ""
    return (
        f'<rect x="{x}" y="{y}" width="{w}" height="{h}" rx="{rx}" fill="{fill}" '
        f'stroke="{stroke}" stroke-width="{sw}"{d}/>'
    )


def text(x, y, lines, anchor="start", gap=None):
    out = []
    cy = y
    for ln in lines:
        if isinstance(ln, str):
            ln = (ln, 14, TEXT, False)
        s, size, fill, bold = (list(ln) + [14, TEXT, False])[:4]
        weight = "bold" if bold else "normal"
        out.append(
            f'<text x="{x}" y="{cy}" font-family="DejaVu Sans" font-size="{size}" '
            f'fill="{fill}" font-weight="{weight}" text-anchor="{anchor}">{esc(s)}</text>'
        )
        cy += gap if gap else int(float(size) * 1.4)
    return "\n".join(out)


def line(x1, y1, x2, y2, color=MUTED, sw=2, dash=None, marker=True):
    d = f' stroke-dasharray="{dash}"' if dash else ""
    m = ' marker-end="url(#arr)"' if marker else ""
    return (
        f'<line x1="{x1}" y1="{y1}" x2="{x2}" y2="{y2}" stroke="{color}" '
        f'stroke-width="{sw}"{d}{m}/>'
    )


def polyline(pts, color=MUTED, sw=2, dash=None, marker=True):
    p = " ".join(f"{x},{y}" for x, y in pts)
    d = f' stroke-dasharray="{dash}"' if dash else ""
    m = ' marker-end="url(#arr)"' if marker else ""
    return (
        f'<polyline points="{p}" fill="none" stroke="{color}" stroke-width="{sw}"'
        f"{d}{m}/>"
    )


def chip(x, y, w, h, label, fill=AZURE, tc=WHITE, size=13, sub=None):
    b = rect(x, y, w, h, fill, fill, rx=7, sw=0)
    lines = [(label, size, tc, True)]
    if sub:
        lines.append((sub, size - 2, tc, False))
    b += text(x + w / 2, y + h / 2 - (2 if sub else -4), lines, anchor="middle")
    return b


def svg(w, h, body, extra_defs=""):
    defs = (
        f'<marker id="arr" viewBox="0 0 10 10" refX="9" refY="5" markerWidth="7" '
        f'markerHeight="7" orient="auto-start-reverse"><path d="M0,0 L10,5 L0,10 z" '
        f'fill="{MUTED}"/></marker>'
        f'<marker id="arrB" viewBox="0 0 10 10" refX="9" refY="5" markerWidth="7" '
        f'markerHeight="7" orient="auto-start-reverse"><path d="M0,0 L10,5 L0,10 z" '
        f'fill="{AZURE}"/></marker>'
        f"{extra_defs}"
    )
    return (
        f'<svg xmlns="http://www.w3.org/2000/svg" width="{w}" height="{h}" '
        f'viewBox="0 0 {w} {h}"><defs>{defs}</defs>{body}</svg>'
    )


def save(name, content):
    path = os.path.join(OUT, name + ".svg")
    with open(path, "w") as f:
        f.write(content)
    subprocess.run(["rsvg-convert", "-o", os.path.join(OUT, name + ".png"), path], check=True)
    print("wrote", name + ".png")


# ---------------------------------------------------------------------------
# 1. Architecture overview
# ---------------------------------------------------------------------------
def diagram_architecture():
    W, H = 1340, 900
    b = []
    b.append(text(40, 44, [("iVolve DevOps Project - Azure infrastructure", 24, TEXT, True)]))
    b.append(
        text(
            40,
            72,
            [
                (
                    "The design was written for AWS; every Azure resource below is labelled with its AWS equivalent. "
                    "Deployed in Denmark East (Azure for Students).",
                    14,
                    MUTED,
                    False,
                )
            ],
        )
    )

    # Internet / users
    b.append(rect(40, 104, 210, 84, PANEL2, BORDER, rx=12))
    b.append(text(145, 140, [("Users / Internet", 16, TEXT, True)], anchor="middle"))
    b.append(
        text(145, 162, [("SSH 22 - Jenkins UI 8080", 11, MUTED, False)], anchor="middle")
    )

    # Developer
    b.append(rect(290, 104, 220, 84, PANEL, BORDER, rx=12))
    b.append(text(400, 138, [("Developer / CI", 15, TEXT, True)], anchor="middle"))
    b.append(text(400, 160, [("git push - kubectl - az", 11, MUTED, False)], anchor="middle"))

    # Git
    b.append(rect(550, 104, 220, 84, PANEL, BORDER, rx=12))
    b.append(text(660, 138, [("Git repository", 15, TEXT, True)], anchor="middle"))
    b.append(text(660, 160, [("AWS: CodeCommit / GitHub", 11, MUTED, False)], anchor="middle"))

    # ArgoCD
    b.append(rect(830, 104, 250, 84, PANEL, BORDER, rx=12))
    b.append(text(955, 138, [("ArgoCD", 15, TEXT, True)], anchor="middle"))
    b.append(
        text(955, 160, [("watches Git, syncs manifests", 11, MUTED, False)], anchor="middle")
    )

    # Jenkins VM
    b.append(rect(40, 262, 330, 200, PANEL, BORDER, rx=12))
    b.append(text(60, 296, [("Jenkins server", 17, AZURE_D, True)]))
    b.append(
        text(
            60,
            322,
            [
                ("Azure Virtual Machine  (AWS EC2)", 13, TEXT, True),
                ("Standard_B2s - 2 vCPU - 4 GiB", 12, TEXT, False),
                ("Ubuntu 22.04 - 10.0.0.4", 12, TEXT, False),
                ("public IP 9.205.91.181", 12, TEXT, False),
                ("user-assigned identity -> AcrPull", 12, TEXT, False),
                ("Ansible installs Java, Jenkins, Docker, Trivy", 11, MUTED, False),
            ],
        )
    )

    # ACR
    b.append(rect(440, 262, 330, 200, PANEL, BORDER, rx=12))
    b.append(text(460, 296, [("Container registry", 17, AZURE_D, True)]))
    b.append(
        text(
            460,
            322,
            [
                ("Azure Container Registry  (AWS ECR)", 13, TEXT, True),
                ("ivolveacrgf7a4e.azurecr.io", 12, TEXT, False),
                ("SKU Standard - retention 7 days", 12, TEXT, False),
                ("pulled by the AKS kubelet identity", 12, TEXT, False),
                ("and by the Jenkins VM identity", 12, TEXT, False),
                ("AWS: ECR repositories per microservice", 11, MUTED, False),
            ],
        )
    )

    # AKS
    b.append(rect(830, 262, 470, 200, PANEL, BORDER, rx=12))
    b.append(text(850, 296, [("Kubernetes cluster", 17, AZURE_D, True)]))
    b.append(
        text(
            850,
            322,
            [
                ("Azure Kubernetes Service  (AWS EKS)", 13, TEXT, True),
                ("ivolve-aks - Kubernetes v1.36 - Azure CNI", 12, TEXT, False),
                ("system pool: Standard_DS3_v2 x 1 node (4 vCPU)", 12, TEXT, False),
                ("user1 / user2 pools: 0 nodes (quota exhausted)", 12, TEXT, False),
                ("egress via the NAT gateway, no extra public IP", 12, TEXT, False),
                ("node resources: MC_ivolve-dev-rg_ivolve-aks_denmarkeast", 11, MUTED, False),
            ],
        )
    )

    # Network panel
    b.append(rect(40, 520, 1260, 330, PANEL2, BORDER, rx=14))
    b.append(
        text(
            64,
            556,
            [
                (
                    "Network - Azure Virtual Network  (AWS VPC)   10.0.0.0/16",
                    17,
                    AZURE_D,
                    True,
                )
            ],
        )
    )
    b.append(
        text(
            64,
            580,
            [
                (
                    "Subnets (AWS subnets) - one pair per availability zone. Network Security Groups are the AWS Security Groups; "
                    "there is no separate NACL, NSGs are stateful.",
                    11,
                    MUTED,
                    False,
                )
            ],
        )
    )

    b.append(chip(64, 610, 250, 60, "public-subnet-1", AZURE, WHITE, 13, "10.0.0.0/24 - Jenkins NIC 10.0.0.4"))
    b.append(chip(334, 610, 250, 60, "public-subnet-2", AZURE, WHITE, 13, "10.0.1.0/24 - spare"))
    b.append(chip(64, 690, 250, 60, "private-subnet-1", AZURE_D, WHITE, 13, "10.0.10.0/24 - AKS system node"))
    b.append(chip(334, 690, 250, 60, "private-subnet-2", AZURE_D, WHITE, 13, "10.0.11.0/24 - AKS user2"))
    b.append(chip(620, 610, 280, 60, "NAT Gateway  (same name in AWS)", "#7B4F00", WHITE, 12, "public IP 9.205.92.29 - egress only"))
    b.append(chip(620, 690, 280, 60, "Network Security Groups  (AWS SGs)", "#444444", WHITE, 12, "stateful inbound rules per subnet"))
    b.append(
        text(
            930,
            622,
            [
                ("Why the region changed", 13, RED, True),
                ("francecentral / uaenorth / switzerlandnorth:", 11, MUTED, False),
                ("every VM family with quota is", 11, MUTED, False),
                ("NotAvailableForSubscription.", 11, MUTED, False),
                ("Denmark East has deployable SKUs.", 11, MUTED, False),
            ],
        )
    )
    b.append(
        text(
            930,
            712,
            [
                ("Budgets", 13, GREEN, True),
                ("vCPU:  Jenkins 2 + AKS system 4 = 6 / 6", 11, MUTED, False),
                ("public IP: Jenkins + NAT + AKS API = 3 / 3", 11, MUTED, False),
            ],
        )
    )

    # arrows
    b.append(line(250, 146, 290, 146))
    b.append(line(510, 146, 550, 146))
    b.append(line(770, 146, 830, 146, AZURE))
    b.append(polyline([(250, 168), (268, 168), (268, 240), (200, 240), (200, 262)], MUTED))
    b.append(polyline([(620, 188), (620, 226), (300, 226), (300, 262)], MUTED))
    b.append(line(370, 362, 440, 362, AZURE))
    b.append(line(955, 188, 955, 262, AZURE))
    b.append(polyline([(1000, 462), (1000, 490), (700, 490), (700, 610)], GREEN))
    b.append(polyline([(620, 640), (30, 640), (30, 146), (40, 146)], MUTED))
    b.append(text(640, 632, [("egress to the internet", 11, MUTED, True)]))
    b.append(text(282, 214, [("SSH / UI", 11, MUTED, True)]))
    b.append(text(470, 352, [("docker push", 11, AZURE_D, True)]))

    save("01-architecture", svg(W, H, "\n".join(b)))


# ---------------------------------------------------------------------------
# 2. Network topology
# ---------------------------------------------------------------------------
def diagram_network():
    W, H = 1300, 800
    b = []
    b.append(text(40, 44, [("Network topology - Azure VNet with the AWS equivalent", 24, TEXT, True)]))
    b.append(
        text(
            40,
            72,
            [
                (
                    "Denmark East - the VM lives in a public subnet, the Kubernetes nodes in private subnets, all egress goes through one NAT gateway.",
                    14,
                    MUTED,
                    False,
                )
            ],
        )
    )

    # VNet
    b.append(rect(40, 100, 940, 640, "#FBFDFF", AZURE, rx=16, sw=2.5))
    b.append(text(70, 140, [("Virtual Network  (AWS VPC)   10.0.0.0/16", 17, AZURE_D, True)]))

    # public subnets
    b.append(rect(70, 170, 400, 220, PANEL, BORDER, rx=12))
    b.append(text(90, 202, [("public-subnet-1   10.0.0.0/24", 14, TEXT, True)]))
    b.append(chip(90, 222, 150, 46, "Jenkins NIC", AZURE, WHITE, 12, "10.0.0.4"))
    b.append(chip(255, 222, 190, 46, "public IP", "#7B4F00", WHITE, 12, "9.205.91.181"))
    b.append(
        text(
            90,
            300,
            [
                ("NSG rules (AWS Security Group)", 11, MUTED, True),
                ("22 TCP from admin CIDR", 10, MUTED, False),
                ("8080 TCP from admin CIDR", 10, MUTED, False),
                ("80 / 443 TCP from anywhere", 10, MUTED, False),
                ("egress * allowed", 10, MUTED, False),
            ],
        )
    )

    b.append(rect(510, 170, 400, 220, PANEL, BORDER, rx=12))
    b.append(text(530, 202, [("public-subnet-2   10.0.1.0/24", 14, TEXT, True)]))
    b.append(
        text(
            530,
            240,
            [
                ("spare - second availability zone", 11, MUTED, False),
                ("no workload placed here yet", 11, MUTED, False),
            ],
        )
    )

    # private subnets
    b.append(rect(70, 420, 400, 290, PANEL2, BORDER, rx=12))
    b.append(text(90, 452, [("private-subnet-1   10.0.10.0/24", 14, TEXT, True)]))
    b.append(chip(90, 472, 250, 46, "AKS system node  10.0.10.4", AZURE_D, WHITE, 12))
    b.append(
        text(
            90,
            552,
            [
                ("NSG rules", 11, MUTED, True),
                ("22 TCP from admin CIDR", 10, MUTED, False),
                ("VNet inbound allowed", 10, MUTED, False),
                ("egress * allowed", 10, MUTED, False),
            ],
        )
    )
    b.append(
        text(
            90,
            640,
            [
                ("NAT gateway associated - this is", 10, GREEN, False),
                ("how the node reaches the internet", 10, GREEN, False),
            ],
        )
    )

    b.append(rect(510, 420, 400, 290, PANEL2, BORDER, rx=12))
    b.append(text(530, 452, [("private-subnet-2   10.0.11.0/24", 14, TEXT, True)]))
    b.append(
        text(
            530,
            486,
            [
                ("AKS user2 pool (0 nodes)", 11, MUTED, False),
                ("NAT gateway associated", 11, MUTED, False),
            ],
        )
    )

    # NAT + internet
    b.append(rect(1010, 170, 250, 130, PANEL, "#7B4F00", rx=12, sw=2))
    b.append(text(1030, 204, [("NAT Gateway", 15, "#7B4F00", True)]))
    b.append(
        text(
            1030,
            230,
            [
                ("AWS: NAT Gateway", 11, MUTED, False),
                ("public IP 9.205.92.29", 11, TEXT, False),
                ("regional SKU, static IP", 11, MUTED, False),
            ],
        )
    )
    b.append(chip(1010, 320, 250, 60, "Internet", "#444444", WHITE, 14))

    # AKS control plane
    b.append(rect(1010, 420, 250, 150, PANEL, BORDER, rx=12))
    b.append(text(1030, 454, [("AKS control plane", 15, AZURE_D, True)]))
    b.append(
        text(
            1030,
            478,
            [
                ("API server FQDN", 10, MUTED, True),
                ("ivolve-aks-ybyvjbfv.hcp.", 9, MUTED, False),
                ("denmarkeast.azmk8s.io", 9, MUTED, False),
                ("public, locked to admin CIDR", 10, MUTED, False),
            ],
        )
    )

    b.append(polyline([(290, 560), (290, 725), (980, 725), (980, 270), (1010, 270)], GREEN))
    b.append(line(1135, 300, 1135, 320, "#7B4F00"))
    b.append(text(600, 715, [("egress: node -> NAT gateway -> internet", 11, GREEN, True)], anchor="middle"))
    b.append(text(1245, 250, [("NAT", 10, MUTED, True)], anchor="end"))

    save("02-network", svg(W, H, "\n".join(b)))


# ---------------------------------------------------------------------------
# 3. CI/CD flow
# ---------------------------------------------------------------------------
def diagram_cicd():
    W, H = 1300, 720
    b = []
    b.append(text(40, 44, [("CI/CD pipeline - Jenkins to AKS, with the AWS equivalents", 24, TEXT, True)]))
    b.append(
        text(
            40,
            72,
            [
                (
                    "Azure: Jenkins VM + ACR + ArgoCD. AWS: CodeBuild/CodePipeline + ECR + ArgoCD/EKS.",
                    14,
                    MUTED,
                    False,
                )
            ],
        )
    )

    stages = [
        ("Checkout", "source from Git", AZURE),
        ("Build image", "docker build per microservice", AZURE),
        ("Scan image", "Trivy vulnerability scan", AMBER),
        ("Push image", "docker push to ACR", AZURE),
        ("Delete local", "remove the local image", MUTED),
        ("Update manifests", "kustomize / helm values", AZURE),
        ("Push manifests", "git commit + push", AZURE),
    ]
    x = 40
    y = 120
    w = 160
    h = 92
    gap = 22
    for i, (title, sub, col) in enumerate(stages):
        b.append(rect(x, y, w, h, PANEL, col, rx=10, sw=2))
        b.append(text(x + w / 2, y + 34, [(f"{i+1}. {title}", 13, TEXT, True)], anchor="middle"))
        b.append(text(x + w / 2, y + 58, [(sub, 10, MUTED, False)], anchor="middle"))
        if i < len(stages) - 1:
            b.append(line(x + w, y + h / 2, x + w + gap, y + h / 2, col, sw=2))
        x += w + gap
    b.append(
        text(
            40,
            240,
            [
                (
                    "Jenkins shared library (vars/) drives every stage; AWS equivalent: a CodePipeline with CodeBuild projects.",
                    11,
                    MUTED,
                    False,
                )
            ],
        )
    )

    # Ansible
    b.append(rect(40, 280, 400, 120, PANEL2, BORDER, rx=12))
    b.append(text(60, 314, [("Ansible (AWS: SSM / user-data + roles)", 14, AZURE_D, True)]))
    b.append(
        text(
            60,
            340,
            [
                ("dynamic inventory from Azure", 11, MUTED, False),
                ("installs Java, Jenkins, Docker, Trivy", 11, MUTED, False),
                ("configures the VM once, outside Terraform", 11, MUTED, False),
            ],
        )
    )

    # ACR
    b.append(rect(480, 280, 380, 120, PANEL, BORDER, rx=12))
    b.append(text(500, 314, [("Azure Container Registry  (AWS ECR)", 14, AZURE_D, True)]))
    b.append(
        text(
            500,
            340,
            [
                ("ivolveacrgf7a4e.azurecr.io", 11, TEXT, False),
                ("one repository per microservice", 11, MUTED, False),
                ("pulled by AKS kubelet + Jenkins identity", 11, MUTED, False),
            ],
        )
    )

    # ArgoCD
    b.append(rect(900, 280, 360, 120, PANEL, BORDER, rx=12))
    b.append(text(920, 314, [("ArgoCD", 14, AZURE_D, True)]))
    b.append(
        text(
            920,
            340,
            [
                ("Application CR committed to Git", 11, MUTED, False),
                ("auto sync + self-heal", 11, MUTED, False),
                ("AWS: same ArgoCD, or Flux / CodeDeploy", 11, MUTED, False),
            ],
        )
    )

    b.append(line(240, 212, 240, 280, AZURE))
    b.append(text(252, 250, [("provisions the VM that runs these stages", 10, MUTED, False)]))
    b.append(line(660, 212, 660, 280, AZURE))
    b.append(text(672, 250, [("push image", 10, MUTED, False)]))
    b.append(line(860, 340, 900, 340, AZURE))
    b.append(text(880, 330, [("images for AKS", 10, MUTED, True)], anchor="middle"))

    # AKS workloads
    b.append(rect(40, 450, 1220, 230, PANEL2, BORDER, rx=14))
    b.append(text(64, 486, [("Workloads running in AKS  (AWS EKS)", 17, AZURE_D, True)]))
    boxes = [
        ("namespace ivolve", "all manifests live here", AZURE),
        ("frontend", "Deployment + Service + Ingress", AZURE),
        ("backend services", "auth / roadmap", AZURE),
        ("mysql", "StatefulSet + headless Service", AZURE_D),
        ("storageclass", "managed-csi disk for the DB", MUTED),
        ("configmap + secret", "env vars, sealed at rest", MUTED),
    ]
    x = 64
    y = 510
    w = 186
    h = 96
    gap = 12
    for title, sub, col in boxes:
        b.append(rect(x, y, w, h, PANEL, col, rx=10, sw=2))
        b.append(text(x + w / 2, y + 38, [(title, 13, TEXT, True)], anchor="middle"))
        b.append(text(x + w / 2, y + 62, [(sub, 10, MUTED, False)], anchor="middle"))
        x += w + gap
    b.append(
        text(
            64,
            640,
            [
                (
                    "Ingress exposes the frontend; the database stays on the cluster disk provisioned by the StorageClass.",
                    11,
                    MUTED,
                    False,
                )
            ],
        )
    )

    save("03-cicd-flow", svg(W, H, "\n".join(b)))


# ---------------------------------------------------------------------------
# 4. Constraints and fixes
# ---------------------------------------------------------------------------
def bar(x, y, w, h, used, total, color, label):
    b = [rect(x, y, w, h, "#E9EEF4", "#E9EEF4", rx=4, sw=0)]
    fw = int(w * used / total)
    b.append(rect(x, y, fw, h, color, color, rx=4, sw=0))
    b.append(
        text(
            x + w / 2,
            y + h / 2 + 5,
            [(f"{used} / {total}", 16, WHITE if used else MUTED, True)],
            anchor="middle",
        )
    )
    b.append(text(x, y - 10, [(label, 13, TEXT, True)]))
    return "".join(b)


def diagram_constraints():
    W, H = 1300, 900
    b = []
    b.append(text(40, 44, [("Why the first applies failed - and the fixes that made it deploy", 24, TEXT, True)]))

    # regions
    b.append(rect(40, 100, 620, 300, PANEL, BORDER, rx=12))
    b.append(text(64, 134, [("1. Region policy + SKU eligibility", 17, AZURE_D, True)]))
    b.append(
        text(
            64,
            162,
            [
                ("Azure Policy sys.regionrestriction allows only:", 12, TEXT, False),
                ("francecentral, uaenorth, switzerlandnorth, denmarkeast, austriaeast", 11, MUTED, False),
            ],
        )
    )
    rows = [
        ("francecentral", "blocked", RED, "B/D families = NotAvailableForSubscription"),
        ("uaenorth", "blocked", RED, "same - no deployable SKU with quota"),
        ("switzerlandnorth", "blocked", RED, "only 20-vCPU SKUs unrestricted"),
        ("denmark east", "works", GREEN, "B2s, DS3_v2, D2_v2 available"),
        ("austria east", "partial", AMBER, "B-series and Dv2 available"),
    ]
    y = 196
    for name, state, col, note in rows:
        b.append(text(64, y, [(name, 13, TEXT, True)]))
        b.append(chip(240, y - 16, 90, 24, state, col, WHITE, 11))
        b.append(text(345, y, [(note, 11, MUTED, False)]))
        y += 34
    b.append(
        text(
            64,
            380,
            [
                ("Fix: moved the whole stack to Denmark East.", 12, GREEN, True),
                ("Verify any SKU with: az vm list-skus --location <region> --all", 10, MUTED, False),
            ],
        )
    )

    # vCPU budget
    b.append(rect(690, 100, 570, 300, PANEL, BORDER, rx=12))
    b.append(text(714, 134, [("2. Regional vCPU budget (6)", 17, AZURE_D, True)]))
    b.append(bar(714, 180, 520, 40, 6, 6, GREEN, "Total Regional vCPUs - 6 of 6 used"))
    b.append(text(714, 250, [("Jenkins VM  Standard_B2s", 13, TEXT, True), ("2 vCPU", 12, MUTED, False)]))
    b.append(text(714, 282, [("AKS system pool  Standard_DS3_v2 x 1", 13, TEXT, True), ("4 vCPU", 12, MUTED, False)]))
    b.append(text(714, 314, [("AKS user pools  user1 / user2", 13, TEXT, True), ("0 vCPU - 0 nodes", 12, MUTED, False)]))
    b.append(
        text(
            714,
            356,
            [
                ("AKS needs a non-B system pool of at least 4 vCPUs, so no worker node fits.", 11, MUTED, False),
                ("Raise the quota, then raise aks_node_count + aks_max_count together.", 11, GREEN, False),
            ],
        )
    )

    # public IP budget
    b.append(rect(40, 430, 620, 300, PANEL, BORDER, rx=12))
    b.append(text(64, 464, [("3. Public IP budget (3) - the hidden blocker", 17, AZURE_D, True)]))
    b.append(bar(64, 510, 570, 40, 3, 3, AMBER, "Public IP Addresses - 3 of 3 after the fix"))
    b.append(text(64, 580, [("ivolve-jenkins-ip", 13, TEXT, True), ("Jenkins SSH + UI", 11, MUTED, False)]))
    b.append(text(64, 612, [("ivolve-nat-ip-1", 13, TEXT, True), ("NAT gateway egress", 11, MUTED, False)]))
    b.append(text(64, 644, [("AKS API server", 13, TEXT, True), ("control plane, 1 IP", 11, MUTED, False)]))
    b.append(
        text(
            64,
            690,
            [
                ("Fix: single_nat_gateway = true (was 2 NAT gateways)", 11, GREEN, False),
                ("+ outbound_type = userAssignedNATGateway on the cluster", 11, GREEN, False),
            ],
        )
    )

    # RBAC + ARM
    b.append(rect(690, 430, 570, 300, PANEL, BORDER, rx=12))
    b.append(text(714, 464, [("4. Permissions and Azure consistency", 17, AZURE_D, True)]))
    b.append(
        text(
            714,
            494,
            [
                ("Service principal needs:", 12, TEXT, True),
                ("  Contributor (subscription)", 11, MUTED, False),
                ("  User Access Administrator on ivolve-dev-rg", 11, MUTED, False),
                ("Deleting the resource group deletes that grant.", 11, AMBER, False),
                ("", 6, MUTED, False),
                ("Azure Resource Manager read flapping:", 12, TEXT, True),
                ("  fresh region + fresh subscription -> GETs can 404 for minutes.", 11, MUTED, False),
                ("  Symptoms: 'SubnetNotFound', 'Root object was present, but now", 11, MUTED, False),
                ("  absent'. The resources exist; re-run terraform apply.", 11, MUTED, False),
            ],
        )
    )

    b.append(
        rect(
            40,
            760,
            1220,
            110,
            "#EAF7EA",
            GREEN,
            rx=12,
            sw=2,
        )
    )
    b.append(
        text(
            64,
            796,
            [
                ("Result: the whole stack deploys in Denmark East", 16, GREEN, True),
                ("Jenkins VM (Standard_B2s) - ACR (ivolveacrgf7a4e) - AKS (Standard_DS3_v2 system pool) - VNet, subnets, NSGs, NAT", 12, TEXT, False),
                ("Budgets: 6 / 6 vCPUs  -  3 / 3 public IPs  -  1 NAT gateway", 12, TEXT, False),
            ],
        )
    )

    save("04-constraints-and-fixes", svg(W, H, "\n".join(b)))


# ---------------------------------------------------------------------------
# 5. Animated egress path (GIF)
# ---------------------------------------------------------------------------
def diagram_egress_gif():
    W, H = 960, 540
    frames = 26

    def bg():
        b = []
        b.append(rect(20, 90, 880, 380, "#FBFDFF", AZURE, rx=16, sw=2.5))
        b.append(text(44, 126, [("VNet 10.0.0.0/16", 15, AZURE_D, True)]))
        # private subnet
        b.append(rect(60, 170, 420, 240, PANEL2, BORDER, rx=12))
        b.append(text(84, 204, [("private-subnet-1  10.0.10.0/24", 14, TEXT, True)]))
        b.append(chip(84, 226, 240, 54, "AKS node  10.0.10.4", AZURE_D, WHITE, 12))
        b.append(text(84, 330, [("pod egress: 10.0.10.4", 12, MUTED, False)]))
        # NAT
        b.append(rect(540, 170, 180, 240, PANEL, "#7B4F00", rx=12, sw=2))
        b.append(text(630, 210, [("NAT Gateway", 14, "#7B4F00", True)], anchor="middle"))
        b.append(text(630, 232, [("9.205.92.29", 12, TEXT, False)], anchor="middle"))
        # internet
        b.append(chip(750, 240, 150, 100, "Internet", "#444444", WHITE, 16))
        b.append(text(825, 380, [("egress only - no inbound", 10, MUTED, False)], anchor="middle"))
        # api path
        b.append(rect(60, 470, 840, 60, PANEL, BORDER, rx=10))
        b.append(
            text(
                480,
                506,
                [
                    (
                        "inbound: user -> Jenkins public IP 9.205.91.181 (SSH 22 / UI 8080) and -> AKS API server",
                        11,
                        MUTED,
                        False,
                    )
                ],
                anchor="middle",
            )
        )
        return "".join(b)

    path = [(204, 300), (470, 300), (540, 300), (710, 300), (750, 290), (825, 290)]
    # simple straight path with a bend at the NAT gateway
    path = [(204, 253), (540, 253), (600, 253), (630, 253), (750, 290), (825, 290)]

    for i in range(frames):
        t = i / (frames - 1)
        # piecewise along path segments
        segs = []
        for a, c in zip(path, path[1:]):
            dx, dy = c[0] - a[0], c[1] - a[1]
            ln = max(1, int((dx ** 2 + dy ** 2) ** 0.5))
            segs.append((a, c, ln))
        total = sum(s[2] for s in segs)
        dist = t * total
        x, y = path[-1]
        for a, c, ln in segs:
            if dist <= ln:
                f = dist / ln
                x = a[0] + (c[0] - a[0]) * f
                y = a[1] + (c[1] - a[1]) * f
                break
            dist -= ln
        b = [bg()]
        # trail
        for k in range(6):
            tt = t - k * 0.02
            if tt < 0:
                continue
            d2 = tt * total
            tx, ty = path[-1]
            for a, c, ln in segs:
                if d2 <= ln:
                    f = d2 / ln
                    tx = a[0] + (c[0] - a[0]) * f
                    ty = a[1] + (c[1] - a[1]) * f
                    break
                d2 -= ln
            b.append(
                f'<circle cx="{tx:.1f}" cy="{ty:.1f}" r="{10-k}" fill="{AZURE}" opacity="{0.12*(6-k):.2f}"/>'
            )
        b.append(f'<circle cx="{x:.1f}" cy="{y:.1f}" r="12" fill="{GREEN}"/>')
        b.append(
            text(
                480,
                60,
                [
                    (
                        "Pod egress: AKS node -> NAT gateway -> internet  (userAssignedNATGateway)",
                        15,
                        TEXT,
                        True,
                    )
                ],
                anchor="middle",
            )
        )
        svgp = os.path.join(OUT, f"_f{i:02d}.svg")
        with open(svgp, "w") as f:
            f.write(svg(W, H, "\n".join(b)))
        subprocess.run(
            ["rsvg-convert", "-o", os.path.join(OUT, f"_f{i:02d}.png"), svgp], check=True
        )
        os.remove(svgp)

    gif = os.path.join(OUT, "05-egress-animation.gif")
    subprocess.run(
        [
            "ffmpeg",
            "-y",
            "-loglevel",
            "error",
            "-framerate",
            "10",
            "-i",
            os.path.join(OUT, "_f%02d.png"),
            "-vf",
            "split[s0][s1];[s0]palettegen=max_colors=128[p];[s1][p]paletteuse=dither=bayer",
            "-loop",
            "0",
            gif,
        ],
        check=True,
    )
    for i in range(frames):
        os.remove(os.path.join(OUT, f"_f{i:02d}.png"))
    print("wrote", gif)


def diagram_public_access():
    W, H = 1360, 1000
    b = []
    b.append(text(40, 46, [("How the application is exposed to the network", 24, TEXT, True)]))
    b.append(
        text(
            40,
            74,
            [
                (
                    "The subscription has only 3 public IPs, so the public address of the Jenkins VM is reused as the entry point. "
                    "AWS names in brackets.",
                    14,
                    MUTED,
                    False,
                )
            ],
        )
    )

    # --- tier 1: internet side -------------------------------------------------
    b.append(rect(40, 120, 200, 100, PANEL, BORDER, rx=12))
    b.append(text(140, 158, [("User / browser", 15, TEXT, True)], anchor="middle"))
    b.append(text(140, 182, [("http://9.205.91.181/", 11, AZURE_D, True)], anchor="middle"))

    b.append(rect(300, 120, 230, 100, PANEL, BORDER, rx=12))
    b.append(text(415, 152, [("Azure Public IP", 15, TEXT, True)], anchor="middle"))
    b.append(text(415, 174, [("(AWS Elastic IP)", 11, MUTED, False)], anchor="middle"))
    b.append(text(415, 196, [("9.205.91.181 - 1 of 3", 11, AMBER, True)], anchor="middle"))

    b.append(rect(590, 110, 250, 120, PANEL, BORDER, rx=12))
    b.append(text(715, 142, [("NSG  (AWS Security Group)", 14, TEXT, True)], anchor="middle"))
    b.append(
        text(
            715,
            168,
            [
                ("JenkinsHttp  :80  from 0.0.0.0/0", 10, MUTED, False),
                ("JenkinsSsh   :22  from 0.0.0.0/0", 10, MUTED, False),
                ("JenkinsUi    :8080", 10, MUTED, False),
            ],
            anchor="middle",
        )
    )

    b.append(rect(900, 100, 400, 160, PANEL, AZURE, rx=12, sw=2))
    b.append(text(920, 134, [("Jenkins VM  (AWS EC2)", 15, AZURE_D, True)]))
    b.append(
        text(
            920,
            160,
            [
                ("10.0.0.4 - public-subnet-1", 11, TEXT, False),
                ("nginx reverse proxy on port 80", 12, GREEN, True),
                ("proxy_pass http://10.0.10.4:30300", 11, TEXT, False),
                ("installed with: az vm run-command invoke", 10, MUTED, False),
            ],
        )
    )

    b.append(line(240, 170, 300, 170))
    b.append(line(530, 170, 590, 170))
    b.append(line(840, 180, 900, 180))

    # --- tier 2: inside the VNet ----------------------------------------------
    b.append(rect(40, 330, 1260, 430, "#FBFDFF", AZURE, rx=16, sw=2.5))
    b.append(text(64, 368, [("Virtual Network  (AWS VPC)   10.0.0.0/16", 17, AZURE_D, True)]))

    b.append(rect(64, 410, 250, 80, PANEL, BORDER, rx=10))
    b.append(text(189, 442, [("public-subnet-1", 13, TEXT, True)], anchor="middle"))
    b.append(text(189, 464, [("10.0.0.0/24", 11, MUTED, False)], anchor="middle"))
    b.append(text(189, 480, [("Jenkins NIC 10.0.0.4", 10, MUTED, False)], anchor="middle"))

    b.append(rect(340, 410, 940, 320, PANEL2, BORDER, rx=12))
    b.append(text(364, 442, [("private-subnet-1   10.0.10.0/24", 14, TEXT, True)]))

    b.append(chip(364, 470, 240, 70, "AKS node  10.0.10.4", AZURE_D, WHITE, 12, "Standard_DS3_v2 - 4 vCPU"))
    b.append(line(604, 505, 648, 505, GREEN))
    b.append(
        chip(
            648,
            470,
            270,
            70,
            "frontend-nodeport",
            GREEN,
            WHITE,
            12,
            "NodePort 30300 -> 3000",
        )
    )
    b.append(line(918, 505, 962, 505, GREEN))
    b.append(chip(962, 470, 296, 70, "frontend pods x2", AZURE, WHITE, 12, "Express on 3000"))

    b.append(polyline([(1110, 540), (1110, 580)], MUTED))

    b.append(rect(364, 580, 900, 130, PANEL, BORDER, rx=10))
    b.append(text(384, 612, [("ClusterIP Services - in-cluster only", 13, AZURE_D, True)]))
    b.append(
        text(
            384,
            640,
            [
                ("auth-service.ivolve.svc.cluster.local:5000", 11, TEXT, False),
                ("roadmap-service.ivolve.svc.cluster.local:8080", 11, TEXT, False),
                ("mysql.ivolve.svc.cluster.local:3306  (headless)", 11, TEXT, False),
                ("The frontend calls these server-side, so the browser only ever talks to port 80.", 10, MUTED, False),
            ],
        )
    )

    b.append(polyline([(1100, 260), (1100, 300), (790, 300), (790, 470)], GREEN))
    b.append(text(950, 292, [("HTTP reverse proxy", 11, GREEN, True)]))
    b.append(text(640, 396, [("the VM reaches the node through the VNet - the pod uses an Azure CNI address", 10, MUTED, False)]))

    # --- bottom: what was not used --------------------------------------------
    b.append(rect(40, 790, 400, 150, "#FDECEA", RED, rx=12, sw=2))
    b.append(text(60, 822, [("Public LoadBalancer for the app", 13, RED, True)]))
    b.append(
        text(
            60,
            848,
            [
                ("Blocked: it needs a 4th public IP and the", 11, MUTED, False),
                ("regional quota is 3 of 3 - Jenkins IP, NAT IP", 11, MUTED, False),
                ("and the AKS API server already use them.", 11, MUTED, False),
            ],
        )
    )

    b.append(rect(470, 790, 400, 150, "#FFF6E5", AMBER, rx=12, sw=2))
    b.append(text(490, 822, [("ingress-nginx (internal LB)", 13, "#B26A00", True)]))
    b.append(
        text(
            490,
            848,
            [
                ("Installed but its address stays pending:", 11, MUTED, False),
                ("the AKS identity had no network rights on the", 11, MUTED, False),
                ("VNet. Redundant now - nginx fronts the app.", 11, MUTED, False),
            ],
        )
    )

    b.append(rect(900, 790, 400, 150, PANEL, BORDER, rx=12))
    b.append(text(920, 822, [("AWS equivalent", 13, TEXT, True)]))
    b.append(
        text(
            920,
            848,
            [
                ("An ALB/NLB with an Elastic IP in front of the", 11, MUTED, False),
                ("service, or kubectl port-forward for a quick", 11, MUTED, False),
                ("look. Security Groups play the NSG role.", 11, MUTED, False),
            ],
        )
    )

    save("06-public-access", svg(W, H, "\n".join(b)))


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    diagram_architecture()
    diagram_network()
    diagram_cicd()
    diagram_constraints()
    diagram_public_access()
    diagram_egress_gif()
    print("done")
