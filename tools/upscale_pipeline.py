#!/usr/bin/env python3
"""Tile-aware AI upscale pipeline for SWE1R textures.

1. reflect-pad each texture (reduces seams on tiling surfaces, protects alpha edges)
2. batch-upscale with Real-ESRGAN ncnn (Vulkan)
3. crop back, restore hard alpha for palette/1-bit-alpha formats
"""
import json
import os
import shutil
import subprocess
import sys

import numpy as np
from PIL import Image

SRC = sys.argv[1] if len(sys.argv) > 1 else "extracted"
PADDED = "padded"
OUTDIR = "upscaled"
FINAL = "final"
REALESRGAN = "realesrgan/realesrgan-ncnn-vulkan"
MODEL = os.environ.get("ESRGAN_MODEL", "realesrgan-x4plus")
SCALE = 4

manifest = json.load(open(os.path.join(SRC, "manifest.json")))

os.makedirs(PADDED, exist_ok=True)
os.makedirs(OUTDIR, exist_ok=True)
os.makedirs(FINAL, exist_ok=True)

info = {}
for name in os.listdir(SRC):
    if not name.endswith(".png"):
        continue
    tid = name[:-4]
    im = Image.open(os.path.join(SRC, name)).convert("RGBA")
    w, h = im.size
    a = np.array(im)[:, :, 3]
    binary_alpha = bool(np.all((a == 0) | (a == 255)))
    padx = min(32, max(8, w // 2))
    pady = min(32, max(8, h // 2))
    arr = np.array(im)
    padded = np.pad(arr, ((pady, pady), (padx, padx), (0, 0)), mode="reflect")
    Image.fromarray(padded).save(os.path.join(PADDED, name))
    info[tid] = {"w": w, "h": h, "padx": padx, "pady": pady, "binary_alpha": binary_alpha}

print(f"padded {len(info)} textures, running Real-ESRGAN ({MODEL})...")
env = dict(os.environ, VK_ICD_FILENAMES="/usr/share/vulkan/icd.d/nvidia_icd.json")
r = subprocess.run(
    [REALESRGAN, "-i", PADDED + "/", "-o", OUTDIR + "/", "-n", MODEL, "-s", str(SCALE),
     "-g", "0", "-t", "64", "-j", "1:4:1", "-f", "png"],
    env=env,
)
if r.returncode != 0:
    sys.exit(f"realesrgan failed: {r.returncode}")

for tid, meta in info.items():
    up = Image.open(os.path.join(OUTDIR, f"{tid}.png")).convert("RGBA")
    w, h, padx, pady = meta["w"], meta["h"], meta["padx"], meta["pady"]
    x0, y0 = padx * SCALE, pady * SCALE
    crop = up.crop((x0, y0, x0 + w * SCALE, y0 + h * SCALE))
    arr = np.array(crop)
    if meta["binary_alpha"]:
        arr[:, :, 3] = np.where(arr[:, :, 3] >= 128, 255, 0)
    Image.fromarray(arr).save(os.path.join(FINAL, f"{tid}.png"))

print(f"done: {len(info)} upscaled textures in {FINAL}/")
