#!/usr/bin/env python3
"""Build labeled before/after comparison sheets for AI HD textures.

Usage: python3 tools/make_comparisons.py <extracted_dir> <upscaled_dir> <out_dir> [<8x_dir>]

If the 5th argument (or a `final_8x` dir) exists, a third panel with the optional
8x AI texture is added. Requires: texid_names.json in the same directory as the
extracted manifest (or cwd).
"""
import json
import os
import sys

from PIL import Image, ImageDraw, ImageFont

PANEL = 512
MARGIN = 48
GAP = 32
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


def fit_panel(img, panel=512):
    """Fit an RGBA image into a `panel` box, preserving aspect ratio (nearest-neighbor),
    centered on a checkerboard so alpha/cutouts are visible."""
    im = img.convert("RGBA")
    w, h = im.size
    scale = panel / max(w, h)
    nw, nh = max(1, round(w * scale)), max(1, round(h * scale))
    disp = im.resize((nw, nh), Image.NEAREST)
    bg = checkerboard((panel, panel))
    bg.paste(disp, ((panel - nw) // 2, (panel - nh) // 2), disp)
    return bg


def labeled(panel_img, text, font, draw_font):
    w, h = panel_img.size
    out = Image.new("RGB", (w, h + LABEL_H), BG)
    out.paste(panel_img, (0, 0))
    d = ImageDraw.Draw(out)
    tw = d.textlength(text, font=draw_font)
    d.text(((w - tw) / 2, h + (LABEL_H - draw_font.size) / 2 - 2), text, font=draw_font, fill=FG)
    return out


def build(extracted_dir, upscaled_dir, texid, names, out_path, source_note, up8_dir=None):
    orig = Image.open(os.path.join(extracted_dir, f"{texid}.png")).convert("RGBA")
    ai = Image.open(os.path.join(upscaled_dir, f"{texid}.png")).convert("RGBA")
    ai8 = None
    if up8_dir:
        p8 = os.path.join(up8_dir, f"{texid}.png")
        if os.path.exists(p8):
            ai8 = Image.open(p8).convert("RGBA")
    ow, oh = orig.size
    hw, hh = ai.size

    title_font = find_font(FONT_BOLD_PATHS, 34)
    label_font = find_font(FONT_PATHS, 26)
    foot_font = find_font(FONT_PATHS, 20)

    name = names.get(str(texid), "")
    title = f"{name}  (TEXID {texid})"

    panels = [
        labeled(fit_panel(orig), "Original — 4x nearest-neighbor", label_font, label_font),
        labeled(fit_panel(ai), "AI 4x — Real-ESRGAN x4plus", label_font, label_font),
    ]
    if ai8 is not None:
        w8, h8 = ai8.size
        subtitle = f"{ow}x{oh} original  →  {hw}x{hh} AI 4x  →  {w8}x{h8} AI 8x"
        panels.append(labeled(fit_panel(ai8), "AI 8x — 2nd pass", label_font, label_font))
    else:
        subtitle = f"{ow}x{oh} original  →  {hw}x{hh} AI 4x upscale"

    n = len(panels)
    sheet_w = MARGIN * 2 + PANEL * n + GAP * (n - 1)
    sheet_h = TITLE_H + panels[0].size[1] + FOOTER_H
    sheet = Image.new("RGB", (sheet_w, sheet_h), BG)
    d = ImageDraw.Draw(sheet)

    d.text((MARGIN, 20), title, font=title_font, fill=ACCENT)
    d.text((MARGIN, 58), subtitle, font=foot_font, fill=FG)

    y = TITLE_H
    x = MARGIN
    for panel in panels:
        sheet.paste(panel, (x, y))
        x += PANEL + GAP

    note = source_note
    d.text((MARGIN, sheet_h - FOOTER_H + 16), note, font=foot_font, fill=(160, 168, 180))

    sheet.save(out_path)
    print("wrote", out_path, sheet.size)


def main():
    extracted = sys.argv[1] if len(sys.argv) > 1 else "extracted"
    upscaled = sys.argv[2] if len(sys.argv) > 2 else "final"
    outdir = sys.argv[3] if len(sys.argv) > 3 else "docs/comparisons"
    up8 = sys.argv[4] if len(sys.argv) > 4 else "final_8x"
    if not os.path.isdir(up8):
        up8 = None
    os.makedirs(outdir, exist_ok=True)
    names = json.load(open("texid_names.json"))

    note = ("Pipeline: extracted from out_textureblock.bin · reflect-padded · Real-ESRGAN "
            "(realesrgan-x4plus, 4x, RTX 4060) · cropped · alpha re-binarized  ·  "
            "8x = 2nd x4plus pass → 16x → Lanczos down to 8x")
    build(extracted, upscaled, 61, names, os.path.join(outdir, "texid_061_sandroadlite.png"), note, up8)
    build(extracted, upscaled, 39, names, os.path.join(outdir, "texid_039_ank_face.png"), note, up8)
    build(extracted, upscaled, 1242, names, os.path.join(outdir, "texid_1242_sky.png"), note, up8)
    build(extracted, upscaled, 970, names, os.path.join(outdir, "texid_970_plate_metal.png"), note, up8)
    build(extracted, upscaled, 1304, names, os.path.join(outdir, "texid_1304_palmleaf.png"), note, up8)
    build(extracted, upscaled, 118, names, os.path.join(outdir, "texid_118_clouds.png"), note, up8)
    build(extracted, upscaled, 382, names, os.path.join(outdir, "texid_382_engine_metal.png"), note, up8)
    build(extracted, upscaled, 750, names, os.path.join(outdir, "texid_750_wall_panel.png"), note, up8)
    build(extracted, upscaled, 1298, names, os.path.join(outdir, "texid_1298_face.png"), note, up8)
    build(extracted, upscaled, 1562, names, os.path.join(outdir, "texid_1562_city_floor.png"), note, up8)


if __name__ == "__main__":
    main()
