#!/usr/bin/env python3
"""Extract SWE1R textures (TEXID -> PNG) from out_modelblock.bin + out_textureblock.bin.

Metadata (width/height/format) lives in MaterialTexture structs inside the modelblock
(struct layout from OpenSWE1R/blender-swe1r, pixel decoding from OpenSWE1R/swe1r-tools).
"""
import argparse
import json
import os
import struct
import sys

from PIL import Image

# MaterialTexture: '>I2H4x8H6I4xHH4x'  (76 bytes)
MATTEX_FMT = struct.Struct(">I2H4x8H6I4xHH4x")
VALID_FORMATS = {3, 512, 513, 1024, 1025}


def is_pot(n):
    return n > 0 and (n & (n - 1)) == 0


def scan_modelblock(path):
    data = open(path, "rb").read()
    found = {}  # tex_index -> list of (width, height, format)
    for off in range(0, len(data) - MATTEX_FMT.size, 4):
        (unk0, unk1, unk2, fmt, unk4, width, height, unk5, unk6, unk7, unk8,
         p0, p1, p2, p3, p4, p5, unk9, tex_index) = MATTEX_FMT.unpack_from(data, off)
        if fmt not in VALID_FORMATS:
            continue
        if unk9 != 2560:
            continue
        if not (is_pot(width) and is_pot(height)):
            continue
        if width > 512 or height > 512:
            continue
        if not (0 <= tex_index < 1700):
            continue
        rec = (width, height, fmt)
        found.setdefault(tex_index, [])
        if rec not in found[tex_index]:
            found[tex_index].append(rec)
    return found


def decode_rgba5551(color):
    a = (color >> 0) & 0x1
    b = ((color >> 1) & 0x1F) / 0x1F
    g = ((color >> 6) & 0x1F) / 0x1F
    r = ((color >> 11) & 0x1F) / 0x1F
    r8, g8, b8 = int(r * 255), int(g * 255), int(b * 255)
    if (r8 + g8 + b8) > 0 and a == 0:
        a = 1
    return r8, g8, b8, a * 0xFF


def decode_texture(pixels, palette, width, height, fmt):
    im = Image.new("RGBA", (width, height))
    px = im.load()
    if fmt == 3:  # RGBA8888
        for y in range(height):
            for x in range(width):
                i = (y * width + x) * 4
                px[x, y] = (pixels[i], pixels[i + 1], pixels[i + 2], pixels[i + 3])
    elif fmt == 512:  # CI4
        pal = [decode_rgba5551(struct.unpack_from(">H", palette, i * 2)[0]) for i in range(16)]
        i = 0
        for y in range(height):
            for x in range(0, width, 2):
                v = pixels[i]; i += 1
                px[x, y] = pal[(v >> 4) & 0xF]
                if x + 1 < width:
                    px[x + 1, y] = pal[v & 0xF]
    elif fmt == 513:  # CI8
        pal = [decode_rgba5551(struct.unpack_from(">H", palette, i * 2)[0]) for i in range(256)]
        i = 0
        for y in range(height):
            for x in range(width):
                px[x, y] = pal[pixels[i]]; i += 1
    elif fmt == 1024:  # IA4 (stored as duplicated nibble per swe1r-tools)
        i = 0
        for y in range(height):
            for x in range(0, width, 2):
                v = pixels[i]; i += 1
                hi = ((v >> 4) & 0xF) * 0x11
                lo = (v & 0xF) * 0x11
                px[x, y] = (hi, hi, hi, hi)
                if x + 1 < width:
                    px[x + 1, y] = (lo, lo, lo, lo)
    elif fmt == 1025:  # I8
        i = 0
        for y in range(height):
            for x in range(width):
                v = pixels[i]; i += 1
                px[x, y] = (v, v, v, 0xFF)
    return im.transpose(Image.FLIP_TOP_BOTTOM)


def read_textureblock(path):
    blob = open(path, "rb").read()
    count = struct.unpack(">I", blob[:4])[0]
    entries = []  # (pixel_off, palette_off, pixel_end)
    for i in range(count):
        off_a, off_b = struct.unpack_from(">II", blob, 4 + 8 * i)
        entries.append([off_a, off_b, 0])
    eof = struct.unpack_from(">I", blob, 4 + 8 * count)[0]
    for i in range(count):
        entries[i][2] = entries[i + 1][0] if i + 1 < count else eof
    return count, entries, blob


def pixel_size(fmt, width, height):
    n = width * height
    return {3: n * 4, 512: n // 2, 513: n, 1024: n // 2, 1025: n}[fmt]


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--lev", required=True, help="directory with out_modelblock.bin/out_textureblock.bin")
    ap.add_argument("--out", required=True, help="output dir for PNGs")
    ap.add_argument("--manifest", default=None)
    args = ap.parse_args()

    os.makedirs(args.out, exist_ok=True)
    meta = scan_modelblock(os.path.join(args.lev, "out_modelblock.bin"))
    count, entries, blob = read_textureblock(os.path.join(args.lev, "out_textureblock.bin"))
    print(f"textureblock count={count}, modelblock texture records={len(meta)}")

    manifest = {}
    skipped = []
    for i in range(count):
        if i not in meta:
            skipped.append(i)
            continue
        recs = meta[i]
        if len(recs) > 1:
            print(f"tex {i}: conflicting metadata {recs}, using first")
        width, height, fmt = recs[0]
        off_a, off_b, off_c = entries[i]
        need = pixel_size(fmt, width, height)
        pixels = blob[off_a:off_a + need]
        if len(pixels) < need:
            skipped.append(i)
            continue
        palette = b""
        if fmt in (512, 513):
            pal_n = 16 if fmt == 512 else 256
            palette = blob[off_b:off_b + pal_n * 2]
            if len(palette) < pal_n * 2:
                skipped.append(i)
                continue
        try:
            im = decode_texture(pixels, palette, width, height, fmt)
        except Exception as e:
            print(f"tex {i}: decode failed: {e}")
            skipped.append(i)
            continue
        im.save(os.path.join(args.out, f"{i}.png"))
        manifest[str(i)] = {"width": width, "height": height, "format": fmt}

    man_path = args.manifest or os.path.join(args.out, "manifest.json")
    json.dump(manifest, open(man_path, "w"), indent=1, sort_keys=True)
    print(f"extracted {len(manifest)} textures -> {args.out} (skipped {len(skipped)})")
    if skipped:
        print("skipped ids:", skipped[:50], "..." if len(skipped) > 50 else "")


if __name__ == "__main__":
    main()
