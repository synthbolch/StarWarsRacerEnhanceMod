#!/usr/bin/env python3
"""Re-apply the correct alpha channel to already-generated AI textures.

The first generation used a too-loose is_cutout() test that binarised ~100
soft-alpha textures (clouds/smoke/gradients) on top of the true binary cut-outs.
The AI RGB output is fine; only the alpha was wrong. This rewrites the alpha
from the original (NEAREST resize; binarised only for real cut-outs), matching
the fixed logic in generate_ai_textures.py. Idempotent and fast (no diffusion).
"""
import argparse, sys
from pathlib import Path
import numpy as np
from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parent))
from generate_ai_textures import is_cutout  # noqa: E402


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--src", required=True, help="dir of original <TEXID>.png")
    ap.add_argument("--ai", required=True, help="dir of generated <TEXID>.png")
    ap.add_argument("--dry-run", action="store_true")
    args = ap.parse_args()

    src, ai = Path(args.src), Path(args.ai)
    fixed = checked = 0
    for out in sorted(ai.glob("*.png")):
        orig_p = src / out.name
        if not orig_p.exists():
            continue
        checked += 1
        orig = Image.open(orig_p).convert("RGBA")
        alpha = orig.getchannel("A")
        if alpha.getextrema()[0] >= 255:      # fully opaque -> nothing to do
            continue

        gen = Image.open(out).convert("RGB")
        W, H = gen.size
        a = alpha.resize((W, H), Image.NEAREST)
        if is_cutout(np.array(alpha)):
            a = a.point(lambda p: 255 if p >= 128 else 0)

        cur = Image.open(out)
        if cur.mode == "RGBA" and np.array_equal(np.array(a), np.array(cur.getchannel("A"))):
            continue

        fixed += 1
        if not args.dry_run:
            result = gen.convert("RGBA")
            result.putalpha(a)
            result.save(out)
        print(f"fix {out.name}", flush=True)

    print(f"[{ai.name}] checked={checked} fixed={fixed}"
          + (" (dry-run)" if args.dry_run else ""))


if __name__ == "__main__":
    main()
