# AGENTS.md — notes for coding agents

Guidance for AI coding agents (OpenCode, Claude Code, Cursor, …) working on the
**SWRacer Enhance Mod**. Human contributors: see [`CONTRIBUTING.md`](CONTRIBUTING.md).

## What this project is

An all-in-one enhancement mod package for **Star Wars Episode I Racer** (Steam/GOG). The
repository *is* the distributable: `SWRacerEnhanceMod/` is copied into the game directory
by the installers, and `optional/` packs are opt-in at install time.

Key facts:

- `SWRacerEnhanceMod/dinput.dll` is the community renderer mod (AGPL-3.0). It hardcodes
  asset paths such as `./assets/replacement_textures` — **do not rename them**.
- The shipped HD pack is 4x Real-ESRGAN at `assets/replacement_textures/` (1633 textures).
- Optional packs: `optional/hd_8x/`, `optional/ai_textures/{realistic,clonewars}/`,
  `optional/ui_hd/`, `optional/reshade/`, `optional/third_party/`.
- Large binary assets are committed **directly with git** (no Git LFS). Keep it that way.

## Hard constraints

- **Do not rename** any shipped folder/file the mod or game references (notably
  `assets/`, `assets/replacement_textures/`, `data/`). Asset paths are hardcoded.
- **Do not prefix** files with `enhance_`.
- **Do not gitignore** the texture packs or `Ani had a hard life/` — they are tracked on
  purpose so the installers work from a plain clone.
- **Do not commit** scratch/output: `dist/`, `release/`, `extracted/`, `final*/`,
  `__pycache__/`, `*.log`, `hook.log`, `crashes/`, `ReShade_Setup_*.exe` (already ignored
  by [`.gitignore`](.gitignore)).
- Don't flip the binary markers in [`.gitattributes`](.gitattributes).

## Commit trailers

Disclose your involvement with a dedicated trailer:

```text
Assisted-by: <agent>:<model>      # e.g. Assisted-by: OpenCode:Big Pickle
```

- Use the real agent and model (e.g. `OpenCode:Big Pickle`), not a prettified name.
- Keep the commit subject imperative and ~50 characters.

Why: `Assisted-by` is the emerging convention (Linux kernel, Fedora, LLVM, OpenSSL) and
doesn't imply authorship. Full conventions: [`CONTRIBUTING.md`](CONTRIBUTING.md).

## Test before you commit

The installers must stay reversible. Use a fake game directory:

```bash
mkdir -p /tmp/fakegame && : > /tmp/fakegame/SWEP1RCR.EXE
./install.sh /tmp/fakegame
./change_textures.sh list /tmp/fakegame
./uninstall.sh /tmp/fakegame
```

`uninstall.sh` must restore the directory to its original state. Run this round-trip for
any change to `install.*` / `uninstall.*` / `change_textures.*`.

## Tools (`tools/`)

| Script | Purpose |
|---|---|
| `extract_textures.py` | Extract TEXID → PNG from `out_modelblock.bin` + `out_textureblock.bin` |
| `upscale_pipeline.py` | Tile-aware Real-ESRGAN x4 upscale (reflect-pad, alpha restore) |
| `upscale_8x.py` | Optional 8x pass (supersample: 4x → x4plus → Lanczos to 8x) |
| `generate_ai_textures.py` | SDXL-Lightning + ControlNet-Tile regeneration |
| `fix_ai_alpha.py` | Re-apply the correct alpha to generated AI textures |
| `validate_ai_textures.py` | Check a generated pack against the original manifest |
| `make_comparisons.py` / `make_ai_comparisons.py` | Build the sheets in `docs/comparisons/` |

Pipeline details: [`docs/HD_TEXTURE_PIPELINE.md`](docs/HD_TEXTURE_PIPELINE.md).

## Keep docs in sync

If you change behaviour, update the affected docs: `README.md`, `docs/README.md`,
`docs/*.md`, and `SWRacerEnhanceMod/README.md` / `ATTRIBUTION.md`.

## Licensing

Your contributions are under **WTFPL v2**; bundled third-party components keep their own
licenses ([`SWRacerEnhanceMod/ATTRIBUTION.md`](SWRacerEnhanceMod/ATTRIBUTION.md)). Don't
introduce files that can't be redistributed.
