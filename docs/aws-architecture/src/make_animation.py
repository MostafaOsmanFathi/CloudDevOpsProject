#!/usr/bin/env python3
"""Animate the system overview: packets travel along the real edge paths.

Reads the rendered 01-system-overview.png and overlays moving packets on the
connectors, then writes an animated GIF (web-friendly) and an MP4 (presentations).
Run make_diagrams.py first so the PNG exists.
"""
import math
import os
import shutil
import subprocess
import tempfile

from PIL import Image, ImageDraw

import make_diagrams as md

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.normpath(os.path.join(HERE, ".."))
PNG = os.path.join(OUT, "01-system-overview.png")
GIF = os.path.join(OUT, "01-system-overview-animated.gif")
MP4 = os.path.join(OUT, "01-system-overview-animated.mp4")

FPS = 25
SECONDS = 8
FRAMES = FPS * SECONDS
GIF_WIDTH = 1600

# One colour per flow so the eye can separate the request path from the pipeline.
FLOWS = [
    ("request", (35, 126, 184), 0.00),   # users -> Route 53 -> EC2 -> workloads
    ("ci", (231, 21, 123), 0.34),        # CodeCommit -> CodeBuild -> CodePipeline -> ECR
    ("cd", (140, 79, 255), 0.62),        # CodePipeline -> Argo CD -> cluster
    ("pull", (201, 37, 209), 0.18),      # ECR -> node pool
]


def chain(d, edge_args, pairs):
    pts = []
    for a, b in pairs:
        ex, en = edge_args[(a, b)]
        poly = d.route(a, b, ex, en)
        if pts and math.dist(pts[-1], poly[0]) < 1:
            pts.extend(poly[1:])
        else:
            pts.extend(poly)
    return pts


def cumulative(pts):
    out = [0.0]
    for a, b in zip(pts, pts[1:]):
        out.append(out[-1] + math.dist(a, b))
    return out


def point_at(poly, cum, t):
    target = t * cum[-1]
    for i in range(1, len(cum)):
        if cum[i] >= target:
            span = cum[i] - cum[i - 1] or 1.0
            f = (target - cum[i - 1]) / span
            return (poly[i - 1][0] + (poly[i][0] - poly[i - 1][0]) * f,
                    poly[i - 1][1] + (poly[i][1] - poly[i - 1][1]) * f)
    return poly[-1]


def draw_packet(overlay, pos, colour, radius=11):
    x, y = pos
    for r, alpha in ((radius * 3.4, 38), (radius * 2.1, 78), (radius, 150)):
        overlay.ellipse([x - r, y - r, x + r, y + r], fill=colour + (alpha,))
    overlay.ellipse([x - radius * 0.55, y - radius * 0.55,
                     x + radius * 0.55, y + radius * 0.55], fill=(255, 255, 255, 255))


def main():
    if not os.path.exists(PNG):
        raise SystemExit("render the diagrams first: python3 make_diagrams.py")

    d, nodes = md.overview()
    edge_args = {(s, t): (ex, en) for (s, t, ex, en, _lbl) in d.edges}

    request = [("users", "r53"), ("r53", "ec2"), ("ec2", "wl1")]
    ci = [("repo", "build"), ("build", "pipe"), ("pipe", "ecr")]
    cd = [("pipe", "argo"), ("argo", "vpc")]
    pull = [("ecr", "priv1")]
    segments = {"request": request, "ci": ci, "cd": cd, "pull": pull}

    paths = []
    for name, colour, phase in FLOWS:
        pairs = [(nodes[a], nodes[b]) for a, b in segments[name]]
        poly = chain(d, edge_args, pairs)
        paths.append((poly, cumulative(poly), colour, phase))

    base = Image.open(PNG).convert("RGBA")
    frames = []
    for f in range(FRAMES):
        overlay = Image.new("RGBA", base.size, (0, 0, 0, 0))
        draw = ImageDraw.Draw(overlay)
        for poly, cum, colour, phase in paths:
            t = ((f / FRAMES) + phase) % 1.0
            draw_packet(draw, point_at(poly, cum, t), colour)
        frames.append(Image.alpha_composite(base, overlay).convert("RGB"))

    ratio = GIF_WIDTH / base.size[0]
    gif_frames = [im.resize((GIF_WIDTH, int(im.size[1] * ratio)), Image.Resampling.LANCZOS) for im in frames]
    gif_frames[0].save(GIF, save_all=True, append_images=gif_frames[1:],
                       duration=1000 // FPS, loop=0, optimize=True)
    print("wrote", GIF)

    tmp = tempfile.mkdtemp(prefix="ivolve-anim-")
    try:
        for i, im in enumerate(frames):
            im.save(os.path.join(tmp, f"f{i:04d}.png"))
        subprocess.run(
            ["ffmpeg", "-y", "-loglevel", "error", "-framerate", str(FPS),
             "-i", os.path.join(tmp, "f%04d.png"),
             "-c:v", "libx264", "-pix_fmt", "yuv420p", "-crf", "20",
             "-vf", "scale=trunc(iw/2)*2:trunc(ih/2)*2", MP4],
            check=True,
        )
        print("wrote", MP4)
    finally:
        shutil.rmtree(tmp, ignore_errors=True)


if __name__ == "__main__":
    main()
