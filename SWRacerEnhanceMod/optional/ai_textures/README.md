# AI-regenerated textures (optional)

An **alternative** to the bundled HD texture pack. Instead of upscaling the
originals (Real-ESRGAN), these are **newly generated** by a diffusion model
guided by the original texture, in two styles:

| Pack | Look | Install flag |
|------|------|--------------|
| `realistic/` | Modern, crisp, photoreal PBR-style materials | `--ai-realistic` |
| `clonewars/` | Stylised *The Clone Wars* (2008) painterly look | `--ai-clonewars` |

Both are drop-in replacements: same filenames (`<TEXID>.png`) as the normal HD
pack, so the installer simply overlays them on top of
`assets/replacement_textures/`. The two styles are alternatives to each other —
install one or the other, not both (if both are passed, Clone Wars wins).

Each pack holds **1621 textures** (~100 MB): every in-race texture that the
4x pack covers except 12 whose names are legible logos/UI (kept from the normal
4x pack — see caveats).

## Install

Linux/macOS:

```bash
./install.sh --ai-realistic  "/path/to/Star Wars Episode I Racer"
./install.sh --ai-clonewars  "/path/to/Star Wars Episode I Racer"
```

Windows:

```bat
install.bat --ai-realistic  "C:\...\Star Wars Episode I Racer"
install.bat --ai-clonewars  "C:\...\Star Wars Episode I Racer"
```

They can be combined with `--hd-8x` (the AI pack overlays last), but note the AI
pack is authored at **4x** resolution, so `--hd-8x` has no effect on AI-covered
textures.

If the mod is already installed you can switch without re-running the installer:

```bash
../../../change_textures.sh list              # show packs + current
../../../change_textures.sh realistic GAME_DIR  # default | 8x | realistic | clonewars
```

To go back to the normal HD pack, re-run `./install.sh` (without an AI flag) or
`uninstall.sh` to restore the originals.

## How they were made

- Base model: **SDXL-Lightning** 8-step (OpenRAIL++), guided by
  **xinsir/controlnet-tile-sdxl-1.0** (Apache-2.0) so layout/colour track the
  original.
- img2img from the native-size original, prompted automatically from the
  texture's internal name (`texid_names.json`).
- Rendered at **1024px**, downscaled to the 4x target, then the **original
  alpha** is re-applied (hard cut-out edges preserved).
- `realistic`: strength 0.85, ControlNet 0.3, CFG 3.0.
  `clonewars`: strength 0.80, ControlNet 0.35, CFG 4.5 (+ stylised prompt).
- Reproduce with [`../../../tools/generate_ai_textures.py`](../../../tools/generate_ai_textures.py)
  (see `docs/HD_TEXTURE_PIPELINE.md`).

## Notes / caveats

- A handful of textures whose names are legible UI/logos are **left as the
  normal 4x pack** (AI would redraw text/glyphs badly) — see the skip list in the
  generator.
- Alpha is re-applied from the original: soft alpha (clouds, smoke, gradients) is
  kept, while true binary cut-outs (fences, foliage) are re-binarised so edges
  stay crisp.
- Generated output is not guaranteed to be perfectly seamless where the original
  tiled; tile-heavy surfaces may show faint seams in-game.
- Generated images derive from SDXL-Lightning (OpenRAIL++); see
  `../../ATTRIBUTION.md` §2.

## Samples

Four-panel sheets — **original | Real-ESRGAN 4x | AI realistic | AI Clone Wars** —
for representative textures (terrain, sky, metal, foliage cut-outs, faces) are in
[`../../../docs/comparisons/ai/`](../../../docs/comparisons/ai/).
