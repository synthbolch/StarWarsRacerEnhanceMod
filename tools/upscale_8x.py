#!/usr/bin/env python3
"""Optional 8x HD texture pass for SWE1R.

Builds on the existing 4x pack (tools/upscale_pipeline.py, Real-ESRGAN x4plus).
A single 4x model can't reach 8x directly, so we *supersample*:

    4x pack  --(reflect-pad)-->  x4plus pass  -->  16x  --Lanczos-->  8x

The extra pass adds genuine detail and the 16x->8x downsample suppresses the
over-sharpening/hallucination that a single hard 8x would show. Hard (1-bit)
alpha is re-binarized at the end so cutouts stay crisp.

Usage:
    python3 upscale_8x.py <orig4x_src> <pack4x_dir> <outdir>

    orig4x_src  : directory with the ORIGINAL extracted PNGs (for alpha testing)
    pack4x_dir  : directory with the existing 4x PNGs (final/ from upscale_pipeline)
    outdir      : destination for the 8x PNGs
"""
import os
import shutil
import subprocess
import sys

import numpy as np
from PIL import Image

ORIG = sys.argv[1] if len(sys.argv) > 1 else "extracted"
P1 = sys.argv[2] if len(sys.argv) > 2 else "final"
OUT = sys.argv[3] if len(sys.argv) > 3 else "final_8x"

PADDED = os.path.join(".8x_work", "padded")
RAISED = os.path.join(".8x_work", "raised16")
REALESRGAN = "realesrgan/realesrgan-ncnn-vulkan"
MODEL = os.environ.get("ESRGAN_MODEL", "realesrgan-x4plus")
S = 4

os.makedirs(PADDED, exist_ok=True)
os.makedirs(RAISED, exist_ok=True)
os.makedirs(OUT, exist_ok=True)
for d in (os.path.join(".8x_work",),):
    os.makedirs(d, exist_ok=True)

info = {}
for name in os.listdir(P1):
    if not name.endswith(".png"):
        continue
    tid = name[:-4]
    p4 = os.path.join(P1, name)
    im = Image.open(p4).convert("RGBA")
    w4, h4 = im.size
    op = os.path.join(ORIG, name)
    if os.path.exists(op):
        a0 = np.array(Image.open(op).convert("RGBA"))[:, :, 3]
        binary_alpha = bool(np.all((a0 == 0) | (a0 == 255)))
    else:
        a4 = np.array(im)[:, :, 3]
        binary_alpha = bool(np.all((a4 == 0) | (a4 == 255)))
    padx = min(32, max(8, w4 // 2))
    pady = min(32, max(8, h4 // 2))
    padded = np.pad(np.array(im), ((pady, pady), (padx, padx), (0, 0)), mode="reflect")
    Image.fromarray(padded).save(os.path.join(PADDED, name))
    info[tid] = {"w4": w4, "h4": h4, "padx": padx, "pady": pady, "binary_alpha": binary_alpha}

print(f"padded {len(info)} 4x textures, second Real-ESRGAN pass ({MODEL}) -> 16x ...", flush=True)
env = dict(os.environ, VK_ICD_FILENAMES="/usr/share/vulkan/icd.d/nvidia_icd.json")
r = subprocess.run(
    [REALESRGAN, "-i", PADDED + "/", "-o", RAISED + "/", "-n", MODEL, "-s", str(S),
     "-g", "0", "-t", "64", "-j", "1:4:1", "-f", "png"],
    env=env,
)
if r.returncode != 0:
    sys.exit(f"realesrgan failed: {r.returncode}")

done = 0
for tid, m in info.items():
    up = Image.open(os.path.join(RAISED, f"{tid}.png")).convert("RGBA")
    x0, y0 = m["padx"] * S, m["pady"] * S
    crop = up.crop((x0, y0, x0 + m["w4"] * S, y0 + m["h4"] * S))  # 16x of original
    out = crop.resize((m["w4"] * 2, m["h4"] * 2), Image.LANCZOS)  # -> 8x
    arr = np.array(out)
    if m["binary_alpha"]:
        arr[:, :, 3] = np.where(arr[:, :, 3] >= 128, 255, 0)
    Image.fromarray(arr).save(os.path.join(OUT, f"{tid}.png"))
    done += 1
    if done % 200 == 0:
        print(f"  {done}/{len(info)}", flush=True)

print(f"done: {done} 8x textures in {OUT}/")
