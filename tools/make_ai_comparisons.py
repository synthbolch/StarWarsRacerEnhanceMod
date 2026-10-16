#!/usr/bin/env python3
"""Build 4-panel AI-regeneration comparison sheets (original | Real-ESRGAN 4x |
SDXL realistic | SDXL Clone Wars).

Usage:
  python3 tools/make_ai_comparisons.py <extracted> <esrgan4x> <realistic> <clonewars> \
      <out_dir> [texid ...]
"""
import json
import os
import sys

from PIL import Image, ImageDraw, ImageFont

PANEL = 420
MARGIN = 48
GAP = 28
LABEL_H = 44
TITLE_H = 96
FOOTER_H = 56
BG = (24, 26, 32)
FG = (235, 238, 245)
ACCENT = (255, 196, 0)
CHECKER_A = (40, 44, 52)
CHECKER_B = (52, 57, 66)

FONT_PATHS = [
    "/usr/share/fonts/truetype/noto/NotoSans-Regular.ttf",
    "/usr/share/fonts/noto/NotoSans-Regular.ttf",
    "/usr/share/fonts/dejavu/DejaVuSans.ttf",
]
FONT_BOLD_PATHS = [
    "/usr/share/fonts/truetype/noto/NotoSans-Bold.ttf",
    "/usr/share/fonts/noto/NotoSans-Bold.ttf",
    "/usr/share/fonts/dejavu/DejaVuSans-Bold.ttf",
]


def find_font(paths, size):
    for p in paths:
        if os.path.exists(p):
            return ImageFont.truetype(p, size)
    return ImageFont.load_default()


def checkerboard(size):
    im = Image.new("RGB", size, CHECKER_A)
    d = ImageDraw.Draw(im)
    c = 16
    for y in range(0, size[1], c):
        for x in range(0, size[0], c):
            if ((x // c) + (y // c)) % 2:
                d.rectangle([x, y, x + c - 1, y + c - 1], fill=CHECKER_B)
    return im


def fit_panel(img, panel=PANEL):
    im = img.convert("RGBA")
    w, h = im.size
    scale = panel / max(w, h)
    nw, nh = max(1, round(w * scale)), max(1, round(h * scale))
    disp = im.resize((nw, nh), Image.NEAREST)
    bg = checkerboard((panel, panel))
    bg.paste(disp, ((panel - nw) // 2, (panel - nh) // 2), disp)
    return bg


def labeled(panel_img, text, draw_font):
    w, h = panel_img.size
    out = Image.new("RGB", (w, h + LABEL_H), BG)
    out.paste(panel_img, (0, 0))
    d = ImageDraw.Draw(out)
    tw = d.textlength(text, font=draw_font)
    d.text(((w - tw) / 2, h + (LABEL_H - draw_font.size) / 2 - 2), text, font=draw_font, fill=FG)
    return out


def build(extracted, esrgan, realistic, clonewars, texid, names, out_path):
    def load(d):
        p = os.path.join(d, f"{texid}.png")
        return Image.open(p).convert("RGBA") if os.path.exists(p) else None

    orig, es, rs, cw = (load(extracted), load(esrgan), load(realistic), load(clonewars))
    ow, oh = orig.size

    title_font = find_font(FONT_BOLD_PATHS, 32)
    label_font = find_font(FONT_PATHS, 24)
    foot_font = find_font(FONT_PATHS, 20)

    name = names.get(str(texid), "")
    title = f"{name}  (TEXID {texid})"

    panels = [
        labeled(fit_panel(orig), "Original — nearest-neighbor", label_font),
        labeled(fit_panel(es), "HD 4x — Real-ESRGAN (upscale)", label_font),
        labeled(fit_panel(rs), "AI realistic — SDXL-Lightning", label_font),
        labeled(fit_panel(cw), "AI Clone Wars — SDXL-Lightning", label_font),
    ]
    hw, hh = es.size
    subtitle = f"{ow}x{oh} original  →  {hw}x{hh} 4x  (all three 4x panels are the same dimensions)"

    n = len(panels)
    sheet_w = MARGIN * 2 + PANEL * n + GAP * (n - 1)
    sheet_h = TITLE_H + panels[0].size[1] + FOOTER_H
    sheet = Image.new("RGB", (sheet_w, sheet_h), BG)
    d = ImageDraw.Draw(sheet)
    d.text((MARGIN, 20), title, font=title_font, fill=ACCENT)
    d.text((MARGIN, 58), subtitle, font=foot_font, fill=FG)
    x = MARGIN
    for panel in panels:
        sheet.paste(panel, (x, TITLE_H))
        x += PANEL + GAP
    note = ("The ESRGAN panel is the shipped default (pixel-faithful upscale); the two SDXL panels are "
            "the optional --ai-realistic / --ai-clonewars packs: newly generated detail, same layout.")
    d.text((MARGIN, sheet_h - FOOTER_H + 16), note, font=foot_font, fill=(160, 168, 180))
    sheet.save(out_path)
    print("wrote", out_path, sheet.size)


def main():
    if len(sys.argv) < 6:
        print(__doc__)
        sys.exit(1)
    extracted, esrgan, realistic, clonewars, outdir = sys.argv[1:6]
    ids = sys.argv[6:] or ["61", "39", "1242", "970", "1304", "118", "382", "750", "1298", "1562"]
    os.makedirs(outdir, exist_ok=True)
    names = json.load(open("texid_names.json"))
    for tid in ids:
        build(extracted, esrgan, realistic, clonewars, tid, names,
              os.path.join(outdir, f"ai_texid_{int(tid):04d}.png"))


if __name__ == "__main__":
    main()
