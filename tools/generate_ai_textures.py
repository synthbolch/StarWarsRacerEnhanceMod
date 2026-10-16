#!/usr/bin/env python3
"""
Generate AI "modernized" replacement textures for SWE1R via SDXL img2img + ControlNet-Tile.

Regenerates each original texture guided by ControlNet-Tile (keeps composition/colors),
prompted from its TEXID name, then re-applies the original alpha and downscales to the
4x target size. Output PNGs are named <TEXID>.png.

Usage:
  generate_ai_textures.py --models DIR --src DIR --out DIR --strength 0.4 [--limit N]
                          [--ids a,b,c] [--steps 8|20] [--offload model|none] [--seamless]
"""
import argparse, hashlib, json, os, re, sys, time

import torch
import numpy as np
from PIL import Image, ImageFilter

# ---------------------------------------------------------------------------------------

CATEGORY_HINTS = [
    (("sky",), "sky, clouds, atmosphere"),
    (("road", "track", "asphalt", "tarmac"), "asphalt racing track surface"),
    (("wall", "siding", "panel", "plate"), "wall panel"),
    (("floor", "grnd", "ground", "dirt", "mud", "sand"), "ground surface"),
    (("rock", "mtn", "stone", "cliff"), "rocky surface"),
    (("metal", "steel", "crm", "gold"), "metal material"),
    (("ice", "snow"), "icy surface"),
    (("water", "lava"), "liquid surface"),
    (("grass", "foliage", "leaf", "palm", "bush", "tree"), "foliage"),
    (("face", "head"), "alien character face skin"),
    (("cloth", "wrap", "robe"), "fabric"),
    (("engine",), "mechanical engine part"),
    (("pod",), "futuristic vehicle part"),
    (("neon",), "neon light glow"),
]

# Kept as the existing 4x pack (AI redraw would mangle legible logos/UI).
SKIP_KEYWORDS = ("englogo", "pdlogo", "sdlogo", "logo", "hud_knob", "letters", "sign_trn",
                 "rocksign")

# Per-TEXID prompt overrides for textures whose subject must be accurate (the
# name-derived prompt alone is ambiguous). Keyed by TEXID string; the style suffix
# is still appended.
PROMPT_OVERRIDES = {
    # TEXID_ank_face_rgb — Anakin's face. Must read as a ~10-year-old human child,
    # not an alien/adult (the derived prompt said "alien character face skin").
    "39": ("a character face texture of a young human boy about 10 years old, Anakin "
           "Skywalker as a child, pale skin, short blond hair, blue eyes, calm neutral "
           "expression, front-facing head, detailed skin"),
}

_WS = re.compile(r"[^a-z0-9 ]+")


def load_names(path):
    try:
        raw = json.load(open(path))
        return {str(k): v for k, v in raw.items()}
    except Exception:
        return {}


def build_prompt(name, style="realistic", tid=None):
    suffix = STYLES[style]["suffix"]
    if tid is not None and str(tid) in PROMPT_OVERRIDES:
        return PROMPT_OVERRIDES[str(tid)] + ", " + suffix
    n = (name or "").lower().replace("texid_", " ")
    n = _WS.sub(" ", n).replace("_", " ")
    toks = [t for t in n.split() if t and t not in ("rgb", "rgba", "v3", "mip", "lo", "hi")]
    toks = [t for t in toks if len(t) > 2] or toks
    desc = " ".join(toks) or "surface"
    hint = ""
    for keys, h in CATEGORY_HINTS:
        if any(k in n for k in keys):
            hint = ", " + h
            break
    return f"a modern high-fidelity seamless material texture of {desc}{hint}, {suffix}"


NEGATIVE = ("text, watermark, signature, letters, words, logo, caption, blurry, low quality, "
            "jpeg artifacts, noise, frame, border")

STYLES = {
    "realistic": {
        "suffix": ("physically-based rendering albedo, ultra detailed, sharp focus, crisp, "
                   "photorealistic AAA game texture, 4k material scan"),
        "negative": NEGATIVE,
    },
    "clonewars": {
        "suffix": ("Star Wars The Clone Wars 2008 animated series art style, stylized painterly "
                   "game texture, hand-painted matte, simplified clean shapes, bold saturated "
                   "colors, soft cel shading, concept art"),
        "negative": ("photograph, photorealistic, realistic photo, gritty realism, noise, text, "
                     "watermark, signature, letters, logo, blurry, low quality"),
    },
}


def round8(v):
    return max(8, int(round(v / 8.0)) * 8)


def gen_size(tw, th, max_side=1024, min_side=512):
    """Work resolution: min side >= min_side (if it fits) while max side <= max_side."""
    f = 1.0
    while min(tw * f, th * f) < min_side and max(tw * f, th * f) * 2 <= max_side:
        f *= 2
    return round8(tw * f), round8(th * f)


def make_seamless(img):
    """Classic offset+feather blend to hide wrap seams."""
    w, h = img.size
    ox, oy = w // 2, h // 2
    rolled = Image.new("RGB", (w, h))
    rolled.paste(img, (-ox, -oy))
    rolled.paste(img, (w - ox, -oy))
    rolled.paste(img, (-ox, h - oy))
    rolled.paste(img, (w - ox, h - oy))
    # feather mask stronger near the (now central) seam
    mask = Image.new("L", (w, h), 0)
    a = np.zeros((h, w), np.float32)
    yy, xx = np.mgrid[0:h, 0:w]
    cx, cy = w / 2.0, h / 2.0
    d = np.minimum(np.abs(xx - cx) / cx, np.abs(yy - cy) / cy)
    a[:] = np.clip(1.0 - d, 0, 1) ** 2
    mask = Image.fromarray((a * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(max(1, w // 32)))
    return Image.composite(rolled, img, mask)


def is_cutout(alpha_np):
    """True only for (near-)strictly binary alpha. Soft alpha (clouds, smoke,
    gradients) reaches 0 and 255 too, so a min/max test alone is not enough --
    it misclassified ~100 soft-alpha textures as cut-outs and binarised them.
    Require <2% intermediate pixels so only real cut-outs stay crisp."""
    lo, hi = float(alpha_np.min()), float(alpha_np.max())
    if not (lo < 10 and hi > 245):
        return False
    intermediate = float(((alpha_np > 10) & (alpha_np < 245)).mean())
    return intermediate < 0.02


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--models", required=True, help="dir containing sdxl-base, lightning, controlnet-tile-sdxl")
    ap.add_argument("--src", required=True, help="dir of original <TEXID>.png")
    ap.add_argument("--names", default="")
    ap.add_argument("--out", required=True)
    ap.add_argument("--strength", type=float, default=0.4)
    ap.add_argument("--steps", type=int, default=8)
    ap.add_argument("--guidance", type=float, default=0.0)
    ap.add_argument("--control-scale", type=float, default=0.9)
    ap.add_argument("--gen-min", type=int, default=512, help="min working side (gen res)")
    ap.add_argument("--gen-max", type=int, default=1024, help="max working side (gen res)")
    ap.add_argument("--target-scale", type=float, default=4.0)
    ap.add_argument("--limit", type=int, default=0)
    ap.add_argument("--ids", default="")
    ap.add_argument("--offload", choices=["none", "model", "sequential"], default="model")
    ap.add_argument("--style", choices=list(STYLES), default="realistic")
    ap.add_argument("--seamless", action="store_true")
    ap.add_argument("--seamless-keywords", default="road,track,wall,floor,grnd,ground,dirt,mud,sand,rock,metal,ice,snow,grass,plate,panel,pipe,asphalt,tat_")
    ap.add_argument("--no-skip", action="store_true")
    args = ap.parse_args()

    os.makedirs(args.out, exist_ok=True)
    M = args.models
    names = load_names(args.names) if args.names else {}

    print("[load] ControlNet-Tile ...", flush=True)
    from diffusers import (ControlNetModel, StableDiffusionXLControlNetImg2ImgPipeline,
                           EulerDiscreteScheduler, UNet2DConditionModel)
    cn = ControlNetModel.from_pretrained(f"{M}/controlnet-tile-sdxl",
                                         torch_dtype=torch.float16, use_safetensors=True)
    t = time.time()
    from safetensors.torch import load_file as sf_load
    cfg = UNet2DConditionModel.load_config(f"{M}/sdxl-base/unet/config.json")
    unet = UNet2DConditionModel.from_config(cfg)
    unet.load_state_dict(sf_load(f"{M}/lightning/sdxl_lightning_8step_unet.safetensors"),
                         strict=True)
    unet = unet.to(torch.float16)
    print(f"[load] Lightning UNet {time.time()-t:.1f}s", flush=True)
    pipe = StableDiffusionXLControlNetImg2ImgPipeline.from_pretrained(
        f"{M}/sdxl-base", controlnet=cn, unet=unet, torch_dtype=torch.float16,
        variant="fp16", use_safetensors=True)
    pipe.scheduler = EulerDiscreteScheduler.from_config(pipe.scheduler.config,
                                                        timestep_spacing="trailing")
    if args.offload == "model":
        pipe.enable_model_cpu_offload()
    elif args.offload == "sequential":
        pipe.enable_sequential_cpu_offload()
    else:
        pipe.to("cuda")
    pipe.set_progress_bar_config(disable=True)
    try:
        pipe.vae.enable_tiling()
    except Exception:
        pass

    all_ids = sorted([f[:-4] for f in os.listdir(args.src) if f.endswith(".png")],
                     key=lambda x: int(x) if x.isdigit() else 0)
    if args.ids:
        want = set(args.ids.split(","))
        all_ids = [i for i in all_ids if i in want]
    skip = set(kw.lower() for kw in args.seamless_keywords.split(",") if kw)

    done = skipped = 0
    t0 = time.time()
    for tid in all_ids:
        out_path = os.path.join(args.out, f"{tid}.png")
        if os.path.exists(out_path):
            done += 1
            continue
        name = names.get(tid, "")
        if (not args.no_skip) and any(k in name.lower() for k in SKIP_KEYWORDS):
            skipped += 1
            continue

        orig = Image.open(os.path.join(args.src, f"{tid}.png")).convert("RGBA")
        ow, oh = orig.size
        tw, th = round8(ow * args.target_scale), round8(oh * args.target_scale)
        gw, gh = gen_size(tw, th, max_side=args.gen_max, min_side=args.gen_min)

        rgb = orig.convert("RGB")
        init = rgb.resize((gw, gh), Image.LANCZOS)
        alpha = orig.getchannel("A")
        if alpha.getextrema()[0] >= 255:  # opaque
            alpha = None

        prompt = build_prompt(name, args.style, tid)
        seed = int(hashlib.md5(f"{tid}:{args.strength}".encode()).hexdigest()[:8], 16) % (2**31)
        gen = torch.Generator("cuda").manual_seed(seed)

        t = time.time()
        img = pipe(prompt=prompt, negative_prompt=STYLES[args.style]["negative"], image=init,
                   control_image=init,
                   strength=args.strength, num_inference_steps=args.steps,
                   guidance_scale=args.guidance, controlnet_conditioning_scale=args.control_scale,
                   generator=gen, width=gw, height=gh).images[0]
        dt = time.time() - t

        if args.seamless and any(k in name.lower() for k in skip):
            img = make_seamless(img)

        img = img.resize((tw, th), Image.LANCZOS)
        if alpha is not None:
            a = alpha.resize((tw, th), Image.NEAREST)
            if is_cutout(np.array(alpha)):
                a = a.point(lambda p: 255 if p >= 128 else 0)
            out = img.convert("RGBA")
            out.putalpha(a)
        else:
            out = img.convert("RGBA")
        out.save(out_path)
        done += 1
        print(f"[{done:4d}] {tid:>5} {ow}x{oh} -> {tw}x{th} (gen {gw}x{gh}) {dt:5.2f}s  {name or prompt[:40]}",
              flush=True)

        if args.limit and done >= args.limit:
            break

    total = time.time() - t0
    print(f"[done] generated={done} skipped={skipped} in {total/60:.1f} min "
          f"({total/max(1,done):.2f}s/img)", flush=True)


if __name__ == "__main__":
    main()
