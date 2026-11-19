#!/usr/bin/env python3
"""Generate AWS-style architecture diagrams of the iVolve deployment as .drawio.

The deployment runs on Azure, but the brief was written for AWS, so these
diagrams use AWS service names and the official AWS Architecture Icons (draw.io
`mxgraph.aws4` stencils). The Azure equivalent of every AWS name is listed in
../README.md.

Layout follows the aws-architecture-diagram skill: left-to-right flow, 78x78
service icons, orthogonal edges with explicit exit/entry points, group
boundaries with fillColor=none.
"""
import html
import os
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.normpath(os.path.join(HERE, ".."))
CLI = "/usr/sbin/drawio"

AWS_ICONS = "/usr/sbin/drawio"

# ---------------------------------------------------------------- helpers


ENTITIES = {
    "&mdash;": "\u2014",
    "&ndash;": "\u2013",
    "&middot;": "\u00b7",
    "&rarr;": "\u2192",
    "&rArr;": "\u21d2",
    "&amp;": "&",
    "&lt;": "<",
    "&gt;": ">",
    "&shy;": "",
    "&nbsp;": " ",
}


def esc(text: str) -> str:
    """Labels are authored with entities; turn them into real characters first,
    otherwise the escaping below renders them literally."""
    for ent, char in ENTITIES.items():
        text = text.replace(ent, char)
    return html.escape(text, quote=False)


class Diagram:
    def __init__(self, page_w=2400, page_h=1400, bg="#F5F5F5"):
        self.page_w = page_w
        self.page_h = page_h
        self.bg = bg
        self.cells = []
        self.n = 0
        # id -> (x, y, w, h, parent_id, is_group)
        self.shapes = {}
        self.labels = {}
        self.offsets = {"1": (0, 0)}
        self.edges = []

    def _id(self, prefix="c"):
        self.n += 1
        return f"{prefix}{self.n}"

    def _origin(self, parent):
        return self.offsets.get(parent, (0, 0))

    def _abs(self, parent, x, y):
        ox, oy = self._origin(parent)
        return ox + x, oy + y

    def group(self, x, y, w, h, label, stroke, parent="1", fill="none", extra=""):
        cid = self._id("g")
        style = (
            f"container=1;dropTarget=1;fillColor={fill};strokeColor={stroke};"
            f"strokeWidth=2;fontStyle=1;fontSize=19;verticalAlign=top;align=left;"
            f"spacingLeft=16;spacingTop=8;dashed=0;{extra}"
        )
        self.cells.append(
            f'        <mxCell id="{cid}" value="{esc(label)}" style="{style}" vertex="1" parent="{parent}">\n'
            f'          <mxGeometry x="{x}" y="{y}" width="{w}" height="{h}" as="geometry" />\n'
            f"        </mxCell>"
        )
        ax, ay = self._abs(parent, x, y)
        self.shapes[cid] = (x, y, w, h, parent, True)
        self.offsets[cid] = (ax, ay)
        return cid

    def icon(self, x, y, label, res_icon, fill, parent="1", size=92, stroke="#ffffff"):
        cid = self._id("i")
        style = (
            "sketch=0;points=[[0,0,0],[0.25,0,0],[0.5,0,0],[0.75,0,0],[1,0,0],"
            "[0,1,0],[0.25,1,0],[0.5,1,0],[0.75,1,0],[1,1,0],[0,0.25,0],[0,0.5,0],"
            "[0,0.75,0],[1,0.25,0],[1,0.5,0],[1,0.75,0]];outlineConnect=0;"
            f"fontColor=#232F3E;fillColor={fill};strokeColor={stroke};dashed=0;"
            "verticalLabelPosition=bottom;verticalAlign=top;align=center;html=1;"
            f"fontSize=18;fontStyle=1;aspect=fixed;shape=mxgraph.aws4.resourceIcon;"
            f"resIcon=mxgraph.aws4.{res_icon}"
        )
        self.cells.append(
            f'        <mxCell id="{cid}" value="{esc(label)}" style="{style}" vertex="1" parent="{parent}">\n'
            f'          <mxGeometry x="{x}" y="{y}" width="{size}" height="{size}" as="geometry" />\n'
            f"        </mxCell>"
        )
        self.shapes[cid] = (x, y, size, size, parent, False)
        self.labels[cid] = label
        return cid

    def shape(self, x, y, label, shape, fill, parent="1", size=78, stroke="none", font="#232F3E"):
        cid = self._id("s")
        style = (
            f"sketch=0;outlineConnect=0;fontColor={font};fillColor={fill};"
            f"strokeColor={stroke};dashed=0;verticalLabelPosition=bottom;"
            f"verticalAlign=top;align=center;html=1;fontSize=18;fontStyle=1;"
            f"aspect=fixed;shape=mxgraph.aws4.{shape}"
        )
        self.cells.append(
            f'        <mxCell id="{cid}" value="{esc(label)}" style="{style}" vertex="1" parent="{parent}">\n'
            f'          <mxGeometry x="{x}" y="{y}" width="{size}" height="{size}" as="geometry" />\n'
            f"        </mxCell>"
        )
        self.shapes[cid] = (x, y, size, size, parent, False)
        self.labels[cid] = label
        return cid

    def box(self, x, y, w, h, label, parent="1", fill="#ffffff", stroke="#5A6C86",
            font="#232F3E", size=17, bold=True, dashed=0):
        cid = self._id("b")
        weight = 1 if bold else 0
        style = (
            f"rounded=1;whiteSpace=wrap;html=1;fillColor={fill};strokeColor={stroke};"
            f"strokeWidth=1.5;dashed={dashed};fontColor={font};fontSize={size};"
            f"fontStyle={weight};verticalAlign=middle;align=center;spacing=6;"
        )
        self.cells.append(
            f'        <mxCell id="{cid}" value="{esc(label)}" style="{style}" vertex="1" parent="{parent}">\n'
            f'          <mxGeometry x="{x}" y="{y}" width="{w}" height="{h}" as="geometry" />\n'
            f"        </mxCell>"
        )
        self.shapes[cid] = (x, y, w, h, parent, False)
        self.labels[cid] = label
        return cid

    def text(self, x, y, w, h, label, parent="1", size=18, bold=True, align="left"):
        cid = self._id("t")
        weight = 1 if bold else 0
        style = (
            f"text;html=1;align={align};verticalAlign=top;whiteSpace=wrap;"
            f"rounded=0;fontSize={size};spacing=8;fontStyle={weight};"
        )
        self.cells.append(
            f'        <mxCell id="{cid}" value="{esc(label)}" style="{style}" vertex="1" parent="{parent}">\n'
            f'          <mxGeometry x="{x}" y="{y}" width="{w}" height="{h}" as="geometry" />\n'
            f"        </mxCell>"
        )
        return cid

    def edge(self, src, dst, label="", parent="1", dashed=0, color="#232F3E",
             exit=(1, 0.5), entry=(0, 0.5), width=3.5, arrow=True):
        cid = self._id("e")
        ex, ey = exit
        nx, ny = entry
        style = (
            "edgeStyle=orthogonalEdgeStyle;rounded=1;orthogonalLoop=1;jettySize=auto;"
            f"html=1;strokeWidth={width};strokeColor={color};dashed={dashed};"
            f"exitX={ex};exitY={ey};exitDx=0;exitDy=0;entryX={nx};entryY={ny};"
            "entryDx=0;entryDy=0;"
        )
        if arrow:
            style += "endArrow=block;endFill=1;endSize=7;"
        if label:
            style += "labelBackgroundColor=#F5F5F5;fontSize=15;fontStyle=1;"
        self.cells.append(
            f'        <mxCell id="{cid}" value="{esc(label)}" style="{style}" edge="1" '
            f'parent="{parent}" source="{src}" target="{dst}">\n'
            f'          <mxGeometry relative="1" as="geometry" />\n'
            f"        </mxCell>"
        )
        self.edges.append((src, dst, exit, entry, label))
        return cid

    def route(self, src, dst, exit=(1, 0.5), entry=(0, 0.5)):
        """The polyline draw.io will most likely draw, used to animate traffic
        along the visible line. Picks the first variant that avoids other icons."""
        p1 = self._anchor(src, exit)
        p2 = self._anchor(dst, entry)
        mx = (p1[0] + p2[0]) / 2
        my = (p1[1] + p2[1]) / 2
        variants = [
            [p1, (mx, p1[1]), (mx, p2[1]), p2],
            [p1, (p1[0], my), (p2[0], my), p2],
            [p1, p2],
        ]
        for poly in variants:
            pts = self._sample(poly)
            if not any(
                self._hits(r, pts)
                for k, r in self._rects_all().items()
                if k not in (src, dst)
            ):
                return poly
        return variants[0]

    def _rects_all(self):
        return {k: self._rect(k) for k, v in self.shapes.items() if not v[5]}


    # ------------------------------------------------------------ self-check
    def _rect(self, cid):
        x, y, w, h, parent, _ = self.shapes[cid]
        ox, oy = self._origin(parent)
        return (ox + x, oy + y, w, h)

    def _anchor(self, cid, f):
        rx, ry, w, h = self._rect(cid)
        return (rx + f[0] * w, ry + f[1] * h)

    @staticmethod
    def _hits(rect, pts):
        rx, ry, w, h = rect
        for px, py in pts:
            if rx <= px <= rx + w and ry <= py <= ry + h:
                return True
        return False

    def _sample(self, poly, step=6):
        out = []
        for (ax, ay), (bx, by) in zip(poly, poly[1:]):
            length = max(abs(bx - ax), abs(by - ay))
            n = max(2, int(length / step))
            for i in range(n + 1):
                t = i / n
                out.append((ax + (bx - ax) * t, ay + (by - ay) * t))
        return out

    def check(self, name):
        problems = []
        icons = {k: v for k, v in self.shapes.items() if not v[5]}
        rects = {k: self._rect(k) for k in icons}

        # 1. shapes must not overlap each other
        keys = list(rects)
        for i, a in enumerate(keys):
            for b in keys[i + 1:]:
                ax, ay, aw, ah = rects[a]
                bx, by, bw, bh = rects[b]
                if ax < bx + bw and bx < ax + aw and ay < by + bh and by < ay + ah:
                    problems.append(
                        f"overlap: {self.labels.get(a, a)} <-> {self.labels.get(b, b)}"
                    )

        # 2. an edge must not pass through an unrelated icon
        for src, dst, exit, entry, label in self.edges:
            if src not in rects or dst not in rects:
                continue
            p1 = self._anchor(src, exit)
            p2 = self._anchor(dst, entry)
            mx = (p1[0] + p2[0]) / 2
            my = (p1[1] + p2[1]) / 2
            variants = [
                [p1, (mx, p1[1]), (mx, p2[1]), p2],
                [p1, (p1[0], my), (p2[0], my), p2],
                [p1, p2],
            ]
            for va, vb in zip(variants, variants[1:]):
                pass
            worst = None
            for vi, poly in enumerate(variants):
                pts = self._sample(poly)
                for k, r in rects.items():
                    if k in (src, dst):
                        continue
                    if self._hits(r, pts):
                        worst = (vi, k, r)
                        break
                if worst:
                    break
            if worst:
                problems.append(
                    f"edge '{label}' {self.labels.get(src, src)} -> {self.labels.get(dst, dst)} "
                    f"crosses {self.labels.get(worst[1], worst[1])}"
                )

        # 3. icons must stay inside their group
        for cid, (x, y, w, h, parent, _) in self.shapes.items():
            if parent in self.shapes and self.shapes[parent][5]:
                gx, gy, gw, gh, _, _ = self.shapes[parent]
                if x < 0 or y < 0 or x + w > gw or y + h > gh:
                    problems.append(
                        f"{self.labels.get(cid, cid)} escapes {self.labels.get(parent, parent)} "
                        f"({x},{y},{w},{h}) in ({gw},{gh})"
                    )

        if problems:
            print(f"[check] {name}: {len(problems)} issue(s)")
            for p in problems:
                print("   -", p)
        else:
            print(f"[check] {name}: clean")


    def render(self, name):
        self.check(name)
        body = "\n".join(self.cells)
        xml = (
            '<mxfile host="app.diagrams.net" agent="hermes" version="24.0.0">\n'
            f'  <diagram id="{name}" name="{name}">\n'
            f'    <mxGraphModel dx="2800" dy="1600" grid="0" gridSize="10" guides="1" '
            f'tooltips="1" connect="1" arrows="1" fold="1" page="1" pageScale="1" '
            f'pageWidth="{self.page_w}" pageHeight="{self.page_h}" math="0" shadow="0">\n'
            f"      <root>\n"
            f'        <mxCell id="0" />\n'
            f'        <mxCell id="1" parent="0" />\n'
            f'        <mxCell id="bg" value="" style="rounded=0;whiteSpace=wrap;html=1;'
            f'fillColor={self.bg};strokeColor=none;" vertex="1" parent="1">\n'
            f'          <mxGeometry x="0" y="0" width="{self.page_w}" height="{self.page_h}" as="geometry" />\n'
            f"        </mxCell>\n"
            f"{body}\n"
            f"      </root>\n"
            f"    </mxGraphModel>\n"
            f"  </diagram>\n"
            f"</mxfile>\n"
        )
        path = os.path.join(OUT, name + ".drawio")
        with open(path, "w") as fh:
            fh.write(xml)
        env = dict(os.environ)
        env["XDG_RUNTIME_DIR"] = f"/run/user/{os.getuid()}"
        env["WAYLAND_DISPLAY"] = "wayland-0"
        subprocess.run(
            [CLI, "--ozone-platform=wayland", "--disable-gpu", "--no-sandbox",
             "-x", "-f", "png", "-e", "-b", "10", "-o",
             os.path.join(OUT, name + ".png"), path],
            check=True, env=env, timeout=900,
            stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
        )
        print("wrote", path)


def title(d, text, sub=None):
    d.text(40, 20, 1100, 50, text, size=26)
    if sub:
        d.text(40, 68, 1900, 34, sub, size=15, bold=False)


# ---------------------------------------------------------------- 01 overview
def overview():
    d = Diagram(page_h=1700)
    title(
        d,
        "iVolve &mdash; system overview (AWS service names)",
        "This is the deployment that actually runs on Azure (AKS, Azure DNS, Azure Blob, Azure Disk); each AWS "
        "name maps to the Azure service in use &mdash; see README.md.",
    )

    # ---- actors, left
    users = d.shape(100, 260, "Users", "client", "#232F3D", size=78)
    r53 = d.icon(330, 255, "Route 53<br/>(DNS)", "route_53", "#8C4FFF")
    d.edge(users, r53, "HTTPS")

    # ---- cloud
    cloud = d.group(560, 140, 1780, 1100, "AWS Cloud &mdash; region (Azure: denmarkeast)", "#232F3E")
    vpc = d.group(40, 60, 1230, 980, "VPC &mdash; 10.0.0.0/16 (Azure VNet ivolve-vnet)", "#8C4FFF", parent=cloud)

    d.icon(500, 12, "Internet Gateway", "internet_gateway", "#8C4FFF", parent=vpc, stroke="none")

    # public subnet: the bastion host
    pub = d.group(40, 60, 560, 900, "Public subnet &mdash; AZ 1 (Azure public-subnet-1)", "#7AA116", parent=vpc)
    ec2 = d.icon(150, 80, "EC2 (Azure VM)<br/>nginx &middot; Jenkins &middot; Docker &middot; Trivy", "ec2", "#ED7100", parent=pub)
    eip1 = d.icon(150, 240, "Elastic IP<br/>ivolve.denmarkeast.cloudapp.azure.com", "elastic_ip_address", "#ED7100", parent=pub, size=78, stroke="none")
    eip2 = d.icon(150, 390, "Elastic IP<br/>ivolve-argocd.denmarkeast.cloudapp.azure.com", "elastic_ip_address", "#ED7100", parent=pub, size=78, stroke="none")
    sg = d.box(20, 540, 220, 100, "Security Group<br/>(Azure NSG)<br/>22 &middot; 80", parent=pub, fill="#ffffff", stroke="#DD344C")
    nat = d.icon(150, 690, "NAT Gateway<br/>egress only", "nat_gateway", "#8C4FFF", parent=pub, stroke="none")

    # EKS control plane, then the two private node pools below it
    eks = d.icon(850, 90, "EKS control plane<br/>(Azure AKS)", "eks", "#ED7100", parent=vpc)
    priv1 = d.group(640, 230, 550, 330, "Private subnet &mdash; AZ 1 (nodes)", "#147EBA", parent=vpc)
    node1 = d.icon(30, 60, "worker node", "instance2", "#ED7100", parent=priv1, stroke="none")
    wl1 = d.box(160, 50, 370, 230, "frontend &middot; auth &middot; roadmap<br/><br/>"
                                "Deployments + Services<br/>NodePort 30300", parent=priv1,
              fill="#F0F7FF", stroke="#147EBA")
    priv2 = d.group(640, 590, 550, 330, "Private subnet &mdash; AZ 2 (nodes)", "#147EBA", parent=vpc)
    node2 = d.icon(30, 60, "worker node", "instance2", "#ED7100", parent=priv2, stroke="none")
    wl2 = d.box(160, 50, 370, 200, "MySQL StatefulSet<br/>+ headless Service<br/><br/>"
                                "StorageClass &rarr; EBS", parent=priv2, fill="#F0F7FF", stroke="#147EBA")
    ebs = d.icon(30, 230, "EBS", "elastic_block_store", "#C925D1", parent=priv2, stroke="none", size=78)

    # ---- right column of the cloud
    s3 = d.icon(1330, 110, "S3<br/>Terraform state", "s3", "#7AA116", parent=cloud)
    ddb = d.icon(1330, 290, "DynamoDB<br/>state lock", "dynamodb", "#C925D1", parent=cloud)
    ecr = d.icon(1560, 560, "ECR<br/>(Azure ACR)", "ecr", "#ED7100", parent=cloud)
    argo = d.icon(1660, 730, "Argo CD<br/>Application", "codepipeline", "#E7157B", parent=cloud)

    # ---- CI lane under the cloud, right-aligned below ECR / Argo CD
    ci = d.group(1100, 1300, 1240, 340, "Continuous Integration &amp; Delivery &mdash; CodeBuild / CodePipeline "
                                       "(actual: GitHub Actions)", "#E7157B")
    repo = d.icon(40, 120, "CodeCommit<br/>(GitHub repo)", "codecommit", "#E7157B", parent=ci)
    build = d.icon(380, 110, "CodeBuild<br/>build &middot; Trivy scan &middot; push", "codebuild", "#E7157B", parent=ci)
    pipe = d.icon(1020, 110, "CodePipeline<br/>update manifests &middot; push", "codepipeline", "#E7157B", parent=ci)
    d.edge(repo, build, "push", parent=ci)
    d.edge(build, pipe, "image + tag", parent=ci)
    d.edge(pipe, ecr, "", exit=(0.25, 0), entry=(0.25, 1))
    d.edge(pipe, argo, "new tag in Git", exit=(0.75, 0), entry=(0.75, 1))
    d.edge(argo, vpc, "sync (GitOps)", exit=(0, 0.5), entry=(1, 0.5))
    d.edge(ecr, priv1, "pull image", exit=(0, 0.5), entry=(1, 0.5))

    d.edge(r53, ec2, "resolve", parent="1")
    d.edge(ec2, wl1, "NodePort 30300", parent="1", exit=(0.5, 1), entry=(0.5, 0))
    d.edge(eks, priv1, "manages", parent="1")
    d.edge(nat, priv2, "egress", parent="1")

    d.render("01-system-overview")
    return d, {
        "users": users, "r53": r53, "ec2": ec2, "eks": eks, "nat": nat,
        "wl1": wl1, "priv1": priv1, "priv2": priv2, "ecr": ecr, "argo": argo,
        "repo": repo, "build": build, "pipe": pipe, "vpc": vpc,
    }


# ---------------------------------------------------------------- 02 network
def network():
    d = Diagram()
    title(
        d,
        "iVolve &mdash; network topology (AWS service names)",
        "VPC with two availability zones, each with a public and a private subnet. Azure: VNet 10.0.0.0/16 "
        "&mdash; public 10.0.0.0/24 + 10.0.1.0/24, private 10.0.10.0/24 + 10.0.11.0/24.",
    )

    cloud = d.group(60, 130, 2280, 1160, "AWS Cloud &mdash; region (Azure: denmarkeast)", "#232F3E")
    vpc = d.group(40, 60, 2180, 1000, "VPC &mdash; 10.0.0.0/16 (Azure VNet ivolve-vnet)", "#8C4FFF", parent=cloud)
    d.icon(500, 12, "Internet Gateway", "internet_gateway", "#8C4FFF", parent=vpc, stroke="none")

    # public AZ1
    pub1 = d.group(40, 60, 1000, 380, "Public subnet &mdash; AZ 1 (10.0.0.0/24)", "#7AA116", parent=vpc)
    ec2 = d.icon(270, 80, "EC2 (Azure VM)<br/>Jenkins &middot; nginx", "ec2", "#ED7100", parent=pub1)
    d.icon(560, 40, "Elastic IP<br/>ivolve.denmarkeast.cloudapp.azure.com", "elastic_ip_address", "#ED7100", parent=pub1, size=78, stroke="none")
    d.icon(560, 180, "Elastic IP<br/>ivolve-argocd.denmarkeast.cloudapp.azure.com", "elastic_ip_address", "#ED7100", parent=pub1, size=78, stroke="none")
    nat = d.icon(820, 250, "NAT Gateway<br/>egress only", "nat_gateway", "#8C4FFF", parent=pub1, stroke="none")
    d.box(60, 250, 260, 100, "Security Group (Azure NSG)<br/>in: 22 &middot; 80<br/>out: all", parent=pub1,
          fill="#ffffff", stroke="#DD344C")

    # private AZ1
    priv1 = d.group(1080, 60, 900, 380, "Private subnet &mdash; AZ 1 (10.0.10.0/24)", "#147EBA", parent=vpc)
    node1 = d.icon(160, 80, "EKS worker node<br/>10.0.10.4", "instance2", "#ED7100", parent=priv1, stroke="none")
    d.box(60, 230, 380, 120, "frontend &middot; auth &middot; roadmap<br/><br/>ClusterIP Services",
          parent=priv1, fill="#F0F7FF", stroke="#147EBA")

    # public AZ2
    pub2 = d.group(40, 480, 1000, 380, "Public subnet &mdash; AZ 2 (10.0.1.0/24)", "#7AA116", parent=vpc)
    d.box(60, 60, 880, 260, "Standby &mdash; the second public subnet is part of the VPC layout; no instance "
                            "runs here while the regional vCPU quota is full.",
          parent=pub2, fill="#FBFBFB", stroke="#7AA116", dashed=1)

    # private AZ2
    priv2 = d.group(1080, 480, 900, 380, "Private subnet &mdash; AZ 2 (10.0.11.0/24)", "#147EBA", parent=vpc)
    d.icon(160, 80, "EKS worker node", "instance2", "#ED7100", parent=priv2, stroke="none")
    d.box(60, 230, 380, 120, "MySQL StatefulSet<br/>+ headless Service<br/><br/>StorageClass &rarr; EBS",
          parent=priv2, fill="#F0F7FF", stroke="#147EBA")
    d.icon(600, 240, "EBS", "elastic_block_store", "#C925D1", parent=priv2, stroke="none", size=78)

    d.box(1080, 880, 900, 90, "Network ACL (Azure NSG) &mdash; public: 22 from the admin CIDR, 80/443 from "
                             "anywhere; private: VNet only", parent=vpc, fill="#FBFBFB", stroke="#5A6C86", dashed=1)

    d.edge(ec2, node1, "NodePort 30300", parent="1")
    d.edge(nat, priv1, "egress", parent="1")
    d.edge(nat, priv2, "", parent="1", exit=(0.5, 1), entry=(0, 0.5))
    d.render("02-network-topology")


# ---------------------------------------------------------------- 03 ci/cd
def cicd():
    d = Diagram()
    title(
        d,
        "iVolve &mdash; CI / CD pipeline (AWS service names)",
        "Actual tools: GitHub Actions (CI) and Argo CD (CD). Jenkins on EC2 with a shared library is the "
        "brief's alternative path, shown underneath.",
    )

    # CI lane
    ci = d.group(80, 170, 2240, 480, "Continuous Integration &mdash; CodeBuild / CodePipeline (actual: GitHub Actions)", "#E7157B")
    repo = d.icon(60, 120, "CodeCommit<br/>(GitHub repo)", "codecommit", "#E7157B", parent=ci)
    build = d.icon(400, 110, "CodeBuild<br/>Build Image", "codebuild", "#E7157B", parent=ci)
    scan = d.icon(740, 110, "CodeBuild<br/>Scan Image (Trivy)", "codebuild", "#E7157B", parent=ci)
    push = d.icon(1080, 110, "CodeBuild<br/>Push Image + Delete local", "codebuild", "#E7157B", parent=ci)
    ecr = d.icon(1840, 110, "ECR<br/>(Azure ACR / Docker Hub)", "ecr", "#ED7100", parent=ci)
    upd = d.box(1020, 300, 300, 90, "Update Manifests<br/>newTag = sha", parent=ci, fill="#FFF7EC", stroke="#E7157B")
    pm = d.box(1360, 300, 300, 90, "Push Manifests<br/>git push", parent=ci, fill="#FFF7EC", stroke="#E7157B")
    d.edge(repo, build, "push", parent=ci)
    d.edge(build, scan, "", parent=ci)
    d.edge(scan, push, "", parent=ci)
    d.edge(push, ecr, "", parent=ci)
    d.edge(push, upd, "", parent=ci, exit=(0.5, 1), entry=(0.5, 0))
    d.edge(upd, pm, "", parent=ci)

    # CD lane
    cd = d.group(80, 720, 2240, 330, "Continuous Deployment &mdash; Argo CD", "#E7157B")
    app = d.icon(1240, 110, "Argo CD Application<br/>repo &middot; path kubernetes/", "codepipeline", "#E7157B", parent=cd)
    eks = d.icon(1560, 100, "EKS control plane<br/>(Azure AKS)", "eks", "#ED7100", parent=cd)
    roll = d.icon(1840, 100, "rolling update<br/>Deployments", "ecs", "#ED7100", parent=cd)
    svc = d.shape(2100, 100, "Services<br/>ClusterIP + NodePort", "application_load_balancer", "#8C4FFF", parent=cd, size=78)
    d.edge(app, eks, "sync", parent=cd)
    d.edge(eks, roll, "", parent=cd)
    d.edge(roll, svc, "", parent=cd)
    d.edge(pm, app, "new Git revision", parent="1", exit=(0.5, 1), entry=(0.5, 0))

    # Jenkins alternative lane
    jk = d.group(80, 1090, 2240, 240, "Brief's alternative &mdash; Jenkins on EC2, driven by a shared library (vars/)", "#ED7100")
    jec2 = d.icon(60, 70, "EC2<br/>Jenkins controller", "ec2", "#ED7100", parent=jk)
    lib = d.box(380, 60, 340, 130, "vars/ shared library<br/>buildImage &middot; scanImage<br/>pushImage &middot; updateManifests",
                parent=jk, fill="#FFF7EC", stroke="#ED7100")
    jtri = d.box(780, 60, 280, 130, "Trivy<br/>Scan Image", parent=jk, fill="#FFF7EC", stroke="#ED7100")
    jreg = d.box(1120, 60, 320, 130, "Jenkinsfile<br/>one per microservice", parent=jk, fill="#FFF7EC", stroke="#ED7100")
    d.edge(jec2, lib, "", parent=jk)
    d.edge(lib, jtri, "", parent=jk)
    d.edge(jtri, jreg, "", parent=jk)

    d.render("03-cicd-pipeline")


# ---------------------------------------------------------------- 04 request flow
def request_flow():
    d = Diagram()
    title(
        d,
        "iVolve &mdash; request path (AWS service names)",
        "One numbered flow, browser to database. Azure equivalents: public IP + nginx on the Jenkins VM, "
        "AKS NodePort 30300, ClusterIP Services, StatefulSet on Azure Disk (EBS).",
    )

    client = d.shape(80, 560, "Client<br/>browser", "client", "#232F3D", size=78)
    r53 = d.icon(300, 555, "Route 53<br/>DNS", "route_53", "#8C4FFF")
    eip = d.icon(540, 555, "Elastic IP<br/>ivolve.denmarkeast.cloudapp.azure.com", "elastic_ip_address", "#ED7100", size=78, stroke="none")
    nginx = d.box(780, 540, 260, 110, "EC2 &mdash; nginx reverse proxy<br/>port 80 &rarr; NodePort 30300", fill="#FFF7EC", stroke="#ED7100")
    fe = d.icon(1180, 555, "frontend Deployment<br/>Node.js / Express", "ec2", "#ED7100")
    auth = d.icon(1480, 430, "auth-service<br/>Python / Flask", "ecs", "#ED7100")
    road = d.icon(1480, 680, "roadmap-service<br/>Java / Spring Boot", "ecs", "#ED7100")
    db = d.icon(1880, 555, "MySQL StatefulSet<br/>headless Service", "rds_mysql_instance", "#C925D1")
    ebs = d.icon(2140, 555, "EBS<br/>StorageClass gp3", "elastic_block_store", "#C925D1", size=78, stroke="none")

    d.edge(client, r53, "①", exit=(1, 0.5), entry=(0, 0.5))
    d.edge(r53, eip, "②", exit=(1, 0.5), entry=(0, 0.5))
    d.edge(eip, nginx, "③", exit=(1, 0.5), entry=(0, 0.5))
    d.edge(nginx, fe, "④", exit=(1, 0.5), entry=(0, 0.5))
    d.edge(fe, auth, "⑤", exit=(1, 0.35), entry=(0, 0.5))
    d.edge(fe, road, "⑤", exit=(1, 0.65), entry=(0, 0.5))
    d.edge(auth, db, "⑥", exit=(1, 0.5), entry=(0, 0.35))
    d.edge(road, db, "⑥", exit=(1, 0.5), entry=(0, 0.65))
    d.edge(db, ebs, "⑦", exit=(1, 0.5), entry=(0, 0.5))

    d.box(80, 900, 2240, 130, "The frontend calls auth and roadmap server-side, so the browser only ever talks to port 80. "
                              "The same EC2 also serves the Argo CD UI (ivolve-argocd.denmarkeast.cloudapp.azure.com) "
                              "and runs cloudflared for the https tunnel.", fill="#FBFBFB", stroke="#5A6C86", dashed=1)

    d.render("04-request-path")


if __name__ == "__main__":
    overview()
    network()
    cicd()
    request_flow()

