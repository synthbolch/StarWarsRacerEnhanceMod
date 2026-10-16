# HD texture pipeline — technical details

How the 1633 AI-generated HD textures in `SWRacerEnhanceMod/assets/replacement_textures/` were
built from the user's own game files. The scripts live in `tools/` and are re-runnable.

Tools and credits (Real-ESRGAN, Ollama, OpenSWE1R decode formats) are documented in
[`../SWRacerEnhanceMod/ATTRIBUTION.md`](../SWRacerEnhanceMod/ATTRIBUTION.md).

## 1. Game file formats

All in-race textures live in two big-endian blocks under `data/lev01/`:

### `out_textureblock.bin` — pixel + palette data

```
u32  texture_count
texture_count × { u32 pixel_offset, u32 palette_offset }   // 8-byte entries
u32  eof_offset
… pixel data …
… palette data …
```

Pixel formats observed (index → format):

| Format | Meaning | Pixel layout | Palette |
|---|---|---|---|
| 3 | RGBA8888 | 4 B/px | — |
| 512 | CI4 | 2 px/byte (high nibble first) | 16 × RGBA5551 |
| 513 | CI8 | 1 B/px | 256 × RGBA5551 |
| 1024 | IA4 | 2 px/byte, nibble replicated to (I,I,I,I) | — |
| 1025 | I8 | 1 B/px grayscale, opaque | — |

Palette entries are **RGBA5551**: `AAAAA BBBBB GGGGG RRRRR` (MSB→LSB is R,G,B,A).
Quirk inherited from OpenSWE1R's tools: if RGB > 0 but the alpha bit is 0, alpha is forced to
opaque (the game relies on this).

### `out_modelblock.bin` — texture metadata

The textureblock itself stores **no** width/height/format. That lives in `MaterialTexture`
records scattered through the modelblock (struct `>I2H4x8H6I4xHH4x`, 64 bytes):

```
u32  unk0            // 0/1/65/73
u16  unk1, unk2      // width*4 / height*4 style hints
u32  format          // ← see table above
u32  unk4            // 0/4
u16  width, height   // ← power-of-two, ≤512
u16  unk5..unk8      // width*512 / height*512 style hints
u32  chunk_ptrs[6]   // mipmap chunk pointers
u32  unk9            // always 2560 — used as validity check when scanning
u16  tex_index       // ← TEXID, index into the textureblock table
```

`tools/extract_textures.py` scans the modelblock for records matching those invariants
(`format ∈ {3,512,513,1024,1025}`, POT dimensions, `unk9 == 2560`, `tex_index < 1700`), then
decodes each texture from the textureblock into an upright RGBA PNG named `<texid>.png`.

**Coverage: 1633 / 1648.** The 15 missing IDs have no material record (they are referenced only
by the separate sprite block or not at all). Extraction was cross-checked against
[OpenSWE1R/swe1r-tools](https://github.com/OpenSWE1R/swe1r-tools) and
[blender-swe1r](https://github.com/OpenSWE1R/blender-swe1r) conventions; TEXID names come from
`src/types_enums.h` of [SW_RACER_RE](https://github.com/tim-tim707/SW_RACER_RE).

## 2. AI upscale (tile-aware)

`tools/upscale_pipeline.py`, per texture:

1. **Reflect-pad** by `min(32, max(8, dim/2))` on each axis. Two reasons:
   - most track textures tile in-game — padding lets the network see across the wrap edge so the
     upscaled tile still matches itself at the seam;
   - protects alpha-cutout edges (fences, grilles) from border fading.
2. **Real-ESRGAN x4plus** (`realesrgan-ncnn-vulkan`, 4x, Vulkan on RTX 4060,
   `-t 64 -j 1:4:1` — larger auto-tiles OOM'd the driver).
3. **Crop** back to `orig × 4`.
4. **Re-binarize alpha** (`≥128 → 255`) for textures whose original alpha was strictly
   binary — keeps cutouts crisp instead of the soft gradients ESRGAN produces.

Output: 1633 PNGs (~111 MB) named `<texid>.png`, dropped into
`assets/replacement_textures/`, which the v0.17 mod's `texture_replacement.cpp` loads
automatically (regex `([0-9]+)\.(dds|png)`, PNG flipped vertically on load, mipmaps generated,
anisotropic filtering from in-game settings).

The same pipeline (at 2–4x, capped for file size) produced the optional UI `.TGA`s in
`SWRacerEnhanceMod/optional/ui_hd/`.

### Model choice

Benchmarked `realesrgan-x4plus` vs `realesr-animevideov3` on the RTX 4060 (~0.12 s vs ~0.03 s
per padded tile). x4plus adds more plausible high-frequency detail (grain, rivets, skin texture)
which is the point of an "HD" pack; animevideov3 was used only where the GPU rejected the larger
model (two full-screen UI backdrops).

## 3. AI quality review

The installed Ollama **vision** models cannot generate images, but they *can* critique them.
For 10 textures spanning sand, road, sky, clouds, metal panels, cutout floors, character faces
and flags, a three-panel sheet (original 4x nearest | AI 4x | AI 8x) was built and submitted to
**qwen3.5:9b** with the texture's game name, asking: what does it depict, does the AI version
preserve structure/colors, any artifacts?

All 10 passed — structure and palette preserved, plausible added detail, no smearing, wrong
colors, or broken alpha. The optional **8x** pass was spot-checked the same way (e.g. the spark
texture: "noticeably sharper, more detail in the sparks, no severe noise or broken edges").
Verbatim reviews: [`HD_TEXTURES_QA.md`](../SWRacerEnhanceMod/HD_TEXTURES_QA.md).
Representative visual sheets: [`comparisons/`](README.md#texture-comparisons).

## 4. Regenerating from scratch

From the game's `data/lev01/`:

```bash
# 1. extract (writes <texid>.png + manifest.json)
python3 tools/extract_textures.py --lev "/path/to/game/data/lev01" --out extracted

# 2. AI upscale (needs realesrgan-ncnn-vulkan in PATH or edit REALESRGAN=)
#    pip install pillow numpy
python3 tools/upscale_pipeline.py extracted          # writes final/

# 3. comparison sheets (optional)
python3 tools/make_comparisons.py extracted final docs/comparisons
```

Then copy `final/*.png` over `SWRacerEnhanceMod/assets/replacement_textures/`.

### Optional 8x pass

`tools/upscale_8x.py` produces a higher-detail 8x pack from the 4x `final/` dirs. Since x4plus only
does 4x, it **supersamples**: a second x4plus pass takes the 4x images to 16x, then Lanczos
downscales to 8x (the extra detail survives; the over-sharpening of a hard 8x is suppressed). Hard
alpha is re-binarized at the end.

```bash
# needs: extracted/ (originals, for alpha) and final/ (the 4x pack)
python3 tools/upscale_8x.py extracted final final_8x
```

Output goes to `SWRacerEnhanceMod/optional/hd_8x/replacement_textures/` (installed with
`install.sh --hd-8x`). VRAM/README guidance: `SWRacerEnhanceMod/optional/hd_8x/README.md`.

## 5. AI-regenerated packs (optional)

`tools/generate_ai_textures.py` builds the **optional** packs in
`SWRacerEnhanceMod/optional/ai_textures/`. Unlike the upscalers above, these are **newly
generated** images: an SDXL-Lightning 8-step model does img2img from the original texture while a
ControlNet-Tile model keeps the layout/colour anchored to it. This trades pixel-faithful upscaling
for genuinely new detail (and, for `--style clonewars`, a deliberate art style).

Per texture:

1. **Init + control images** = the original LANCZOS-upscaled to the working resolution.
2. **Prompt** auto-generated from the texture's internal name (`--names texid_names.json`), e.g.
   `TEXID_sandroadlite_rgb` → "seamless material texture of sand road lite, …". `--style
   clonewars` swaps in a painterly *The Clone Wars* prompt suffix.
3. **SDXL-Lightning** 8-step img2img (`--strength`), guided by **xinsir/controlnet-tile-sdxl-1.0**
   (`--control-scale`), rendered at `--gen-min`/`--gen-max` (1024) and downscaled to
   `--target-scale`x (4x).
4. **Alpha re-applied** from the original (NEAREST). Only textures whose original
   alpha is (near-)strictly binary — <2% intermediate pixels — are re-binarised
   (real cut-outs: fences, foliage). Soft alpha (clouds, smoke, gradients) reaches
   0 and 255 as well, so a plain min/max test misclassifies it; the threshold
   check keeps those soft edges intact.
5. **Skip list:** textures whose names are legible UI/logos (`englogo`, `pdlogo`, `sdlogo`, `logo`,
   `hud_knob`, `letters`, `sign_trn`, `rocksign`) are left at 4x (generating them would mangle
   text; `--no-skip` overrides).

Locked settings: `realistic` = strength 0.85 / control 0.3 / CFG 3.0; `clonewars` = strength 0.80 /
control 0.35 / CFG 4.5 (prompt-selected style). Seed = `md5("<texid>:<strength>")` for
reproducibility. The generator is **resumable** — an existing output file is skipped.

```bash
# needs: extracted/ (originals) and models/ (sdxl-base, lightning, controlnet-tile-sdxl)
# models: ByteDance/SDXL-Lightning (OpenRAIL++) + xinsir/controlnet-tile-sdxl-1.0 (Apache-2.0)
# pip install diffusers transformers accelerate  (diffusers>=0.41, torch with CUDA)
export PYTORCH_CUDA_ALLOC_CONF=expandable_segments:True

# realistic (default style)
python3 tools/generate_ai_textures.py \
  --models models --src extracted --names texid_names.json \
  --style realistic --strength 0.85 --control-scale 0.3 --guidance 3.0 \
  --gen-min 1024 --gen-max 1024 --steps 8 --offload sequential \
  --out SWRacerEnhanceMod/optional/ai_textures/realistic/replacement_textures

# Clone Wars style
python3 tools/generate_ai_textures.py \
  --models models --src extracted --names texid_names.json \
  --style clonewars --strength 0.8 --control-scale 0.35 --guidance 4.5 \
  --gen-min 1024 --gen-max 1024 --steps 8 --offload sequential \
  --out SWRacerEnhanceMod/optional/ai_textures/clonewars/replacement_textures
```

On an 8 GB RTX 4060 use `--offload sequential` (with the allocator flag above); `--offload model`
OOMs when other apps hold VRAM (e.g. a local LLM server). ~13 s/texture at 1024 → a full pack takes
~5.5 hours (both packs ≈ 11 h). Each pack = 1621 files / ~100 MB.

Build/validate with `tools/validate_ai_textures.py` (count + 4x dimensions) and
`tools/fix_ai_alpha.py` (re-apply corrected alpha to an existing pack without re-running diffusion).

## Performance/memory notes

- 4x RGBA8888 replacements replace the game's original 16-bit textures at runtime; the mod
  uploads them as `GL_RGBA8` with generated mipmaps. Worst case (all 1633 textures resident) is
  ~376 MB — negligible on any GPU from the last decade.
- The optional **8x** pack is ~1.5 GB if every texture were resident; comfortable on 8 GB cards,
  too much for 4 GB. In practice the game loads textures per level, so real usage is far lower.

- To disable HD textures without removing the rest of the mod: delete (or move out)
  `assets/replacement_textures/`.
- The mod hot-reloads replacement textures when their file hash changes, so you can drop in an
  edited PNG while the game is running (F5 menu → refresh triggers).
