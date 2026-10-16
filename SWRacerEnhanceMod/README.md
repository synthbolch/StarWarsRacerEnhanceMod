# SWRacer Enhance Mod — install

## Quick install (Windows, Steam/GOG)

1. Close the game completely.
2. Copy **everything inside `SWRacerEnhanceMod/`** (except the `optional/` folder) into your game folder
   (the one that contains `SWEP1RCR.EXE`).
3. Start the game. Press **F5** in-game for the community mod menu.

Or run from this directory:

```bat
install.bat "C:\Program Files (x86)\Steam\steamapps\common\Star Wars Episode I Racer"
```

Linux/Proton:

```bash
./install.sh "/path/to/SteamLibrary/steamapps/common/Star Wars Episode I Racer"
```

> **Linux / Steam Proton (important):** the game loads Wine's builtin `dinput.dll` and ignores the
> modded one unless you add `WINEDLLOVERRIDES="dinput=n,b"` to the game's Steam **Launch Options**
> (put it before `%command%`). Symptom if you don't: the game runs but **F5 does nothing** and there
> is **no `hook.log`** in the game folder. Add `;dsound=n,b` as well to use the bundled DSOAL
> audio. Full instructions: [`../docs/LINUX_PROTON.md`](../docs/LINUX_PROTON.md).

The installers **back up every file they overwrite** into
`<game>/.swracer_enhance_backup/` (with a manifest), so the change is fully reversible.

> **Note:** the Windows helpers (`install.bat`/`uninstall.bat` and `install.ps1`/`uninstall.ps1`)
> are **untested** — they were written but only the Linux `install.sh`/`uninstall.sh` have been
> run. Use the manual copy instructions above if you want to be safe on Windows.

## Uninstall

```bat
uninstall.bat "C:\Program Files (x86)\Steam\steamapps\common\Star Wars Episode I Racer"
```

```bash
./uninstall.sh "/path/to/SteamLibrary/steamapps/common/Star Wars Episode I Racer"
```

`uninstall.sh` / `uninstall.bat` delete the files the mod added and restore the original game
files from the backup, then remove the backup folder. Files the mod did not install are never
touched. (If you installed by hand instead of with the installer, delete `dinput.dll`,
`dsound.dll`, `dsoal-aldrv.dll`, `alsoft.ini`, `Smush.cfg`, `LICENSE`,
`ATTRIBUTION.md`, `README.md`, `LICENSES/` and `assets/` and let Steam verify `data/`.)

---

## What's inside (and where it comes from)

| Component | Source | What it does |
|---|---|---|
| `dinput.dll` + `assets/` | [SW_RACER_RE community improvement mod v0.17](https://github.com/tim-tim707/SW_RACER_RE/releases/tag/v0.17) | New OpenGL renderer, PBR + IBL, MSAA, widescreen/FOV, FPS limiter/counter, windowed/borderless, controller support in menus & races, quick-race menu, audio menu, cheat menu, custom tracks, HD fonts, fog, AI full LOD, weather, lap/timer fixes, texture replacement support... (press F5 in game) |
| `assets/replacement_textures/*.png` (1633 files) | **AI-generated HD textures** (see below) | 4x HD replacements for (almost) every in-race texture, loaded automatically by v0.17 |
| `dsound.dll` + `dsoal-aldrv.dll` + `alsoft.ini` | [Dead Simple 2026 fix guide pack](https://github.com/Rast1234/game_mods/releases/tag/swe1r) (DSOAL/OpenAL) | Real 3D positional audio + HRTF headphone mode |
| `data/config/current/*.cfg` | same fix pack | All graphics/audio settings forced to maximum |
| `data/wavs/22K/*.wav`, `data/Sounds.map` | fix pack — [**Starfighter's Audio Overhaul**](https://www.nexusmods.com/starwarsepisode1racer/mods/5) | Higher quality engine/thruster sounds |
| `Smush.cfg` | fix pack — config for [swe1r_Smush](https://github.com/JeremyAnsel/swe1r_Smush) | Cutscene aspect-ratio config (only takes effect with the modded `Smush.dll`; the community mod renders cutscenes itself) |

### Extras for playing **without** the community mod (`optional/third_party/`)

The community `dinput.dll` + new OpenGL renderer already replace these, and mixing them breaks
things — use them only for a non-mod setup:

| Folder | Use only if... |
|---|---|
| `optional/third_party/dgvoodoo/` | You play without the community mod and need a DirectX→GL wrapper (maxed D3D settings) |
| `optional/third_party/xidi/` | You play without the community mod and need the Xidi DirectInput wrapper for controllers |

### Optional HD menu/UI textures (`optional/ui_hd/`)

92 upscaled menu/UI `.TGA`s (2–4x) that overlay the game's `data/images/` in place. The mod
does not touch `data/images/`, so these work **with** it. Install with `./install.sh --ui-hd`
(or `install.bat --ui-hd`); the originals are backed up and restored by the uninstaller. Menus
were laid out for the original sizes, so verify nothing looks off — remove individual files if
so. See `optional/ui_hd/README.md`.

The optional **texture packs** (`optional/hd_8x/`, `optional/ai_textures/`) are
different — they work *with* the mod and are covered below.

`Smush.dll` is intentionally **not** shipped: the community mod handles cutscene skip/letterbox
itself. (The guide pack's modded `Smush.dll` stays available upstream if you want it.)

The **swe1r-patcher** FOV/fixes executable is **also not shipped**: swe1r-patcher forbids
redistributing its output. Get it from the project and patch your own `SWEP1RCR.EXE`
(https://github.com/JayFoxRox/swe1r-patcher). The community `dinput.dll` already provides
FOV/aspect-ratio controls and needs no patching.

---

## HD textures

`assets/replacement_textures/` holds **1633** HD textures (4x) the mod loads automatically. They
were decoded from the game's `out_textureblock.bin`/`out_modelblock.bin`, reflect-padded and
upscaled 4x with **Real-ESRGAN** (tile-aware, binary-alpha preserved), then quality-reviewed by a
local vision LLM (see `HD_TEXTURES_QA.md`). `CATALOG.csv` maps every TEXID to its game name and
original/HD resolution.

To disable HD textures: delete `assets/replacement_textures/` (or move it out).

Full details (file formats, settings, QA) and before/after sheets live in `../docs/` — see
`../docs/HD_TEXTURE_PIPELINE.md` and `../docs/README.md`.

### Optional 8x pack

`optional/hd_8x/` holds the same textures at **8x** (a second Real-ESRGAN pass supersampled
to 8x). Install with `./install.sh --hd-8x` (or copy over `assets/replacement_textures/`). ~358 MB
on disk; ~1.5 GB VRAM worst-case — fine on 8 GB, too much for 4 GB. See
`optional/hd_8x/README.md`.

### Optional AI-regenerated packs

Unlike the packs above (which **upscale** the originals), `optional/ai_textures/` contains
textures **newly generated** by SDXL-Lightning 8-step + ControlNet-Tile, guided by each original, in
two styles:

- `ai_textures/realistic/` — modern, crisp, photoreal PBR-style materials (`--ai-realistic`).
- `ai_textures/clonewars/` — a stylised *The Clone Wars* (2008) painterly look (`--ai-clonewars`).

Both are 4x and use the same `<TEXID>.png` names as the normal pack, so they overlay
`assets/replacement_textures/`. Each pack = 1621 textures (~100 MB; the 12 logo/UI textures are left
from the normal 4x pack). Install with `./install.sh --ai-realistic` / `./install.sh --ai-clonewars`.
See `optional/ai_textures/README.md` for method, settings and caveats.

### Switching texture pack after install

Once the mod is installed you can switch between packs without re-running the installer:

```bash
../change_textures.sh list                   # show packs + current
../change_textures.sh realistic "GAME_DIR"   # default | 8x | realistic | clonewars
```

(Windows: `..\change_textures.bat realistic "GAME_DIR"`.) It re-lays the default 4x pack then
overlays the chosen one, and leaves the backup/manifest untouched, so `uninstall` still works.

---

## Upscaling & sharpening (optional, external)

The mod's renderer is **OpenGL**, so spatial upscaling works but DLSS / FSR 2/3 / real ray
tracing do not. Two supported routes — **nothing is bundled**:

- **Linux/Proton — gamescope:** add `-F fsr` (or `-F nis` / `-F sgsr`) to the launch options,
  e.g. `gamescope -f -w 1280 -h 720 -W 2560 -H 1440 -F fsr --sharpness 4 -- %command%`.
  Nothing in the game folder changes.
- **Windows + Linux/Proton — ReShade (installed as `opengl32.dll`):** `optional/reshade/` has a
  README, a Linux/Proton install helper, and a tuned preset (`SWRacer_Optimized.ini` — CAS + SMAA +
  Vibrance over the SweetFX pack). `./install.sh --reshade` (`install.bat --reshade`) does the whole
  job: it downloads the official ReShade build, installs it as `opengl32.dll`, fetches the SweetFX
  and standard-effect shaders, and drops in the preset. Nothing ReShade is bundled — it comes
  straight from reshade.me / GitHub at install time, because the ReShade project asks that its
  binaries and shader files not be redistributed. On Steam/Proton add `opengl32` to the DLL
  override too, then press Home in-game and pick the preset.

Details, caveats and "what won't work" (DLSS, vkBasalt, RTX Remix, real RT):
[`../docs/UPSCALING.md`](../docs/UPSCALING.md).

---

## Credits

**Every original project, author, link and license is documented in
[`ATTRIBUTION.md`](ATTRIBUTION.md) (with license texts in [`LICENSES/`](LICENSES/)).**

- [tim-tim707, louriccia & contributors — SW_RACER_RE](https://github.com/tim-tim707/SW_RACER_RE) (AGPL-3.0)
  — the core `dinput.dll` + `assets/` (OpenGL renderer, F5 menu, HD fonts, ...)
- ["Dead Simple 2026" guide](https://steamcommunity.com/sharedfiles/filedetails/?id=3742768078) by **superrast**
  and its fix pack ([Rast1234/game_mods](https://github.com/Rast1234/game_mods/releases/tag/swe1r))
- [Starfighter's Audio Overhaul](https://www.nexusmods.com/starwarsepisode1racer/mods/5) by **Starfighter** — engine sounds
- [DSOAL](https://github.com/kcat/dsoal) (LGPL-2.1) · [Xidi](https://github.com/samuelgr/Xidi) (BSD-3-Clause) · [dgVoodoo2](https://github.com/dege-diosg/dgVoodoo2) (freeware)
- [swe1r_Smush](https://github.com/JeremyAnsel/swe1r_Smush) by Jérémy Ansel (MIT) — cutscene config
- [swe1r-patcher](https://github.com/JayFoxRox/swe1r-patcher) by JayFoxRox — **not redistributed** (see ATTRIBUTION.md)
- Texture formats reverse-engineered with [OpenSWE1R/swe1r-tools](https://github.com/OpenSWE1R/swe1r-tools)
  and [OpenSWE1R/blender-swe1r](https://github.com/OpenSWE1R/blender-swe1r)
- AI textures upscaled with [Real-ESRGAN](https://github.com/xinntao/Real-ESRGAN) by xinntao (BSD-3-Clause)
- Optional AI-regenerated packs use [SDXL-Lightning](https://huggingface.co/ByteDance/SDXL-Lightning) (OpenRAIL++) and [xinsir/controlnet-tile-sdxl-1.0](https://huggingface.co/xinsir/controlnet-tile-sdxl-1.0) (Apache-2.0)
- `install.sh`/`install.bat` and `tools/` in the parent folder reproduce the extraction/upscaling
  pipeline from your own game files
- Optional external upscaling: [gamescope](https://github.com/ValveSoftware/gamescope) and
  [ReShade](https://reshade.me) (BSD-3-Clause, **not bundled**) — see
  [`../docs/UPSCALING.md`](../docs/UPSCALING.md)

## License

This project's own files (`install.*`, `uninstall.*`, `tools/*.py`, the `optional/reshade/`
helper scripts, docs, comparison images) are
released under the **WTFPL v2** (Do What The Fuck You Want To Public License) — see [`LICENSE`](LICENSE).
Use, modify, distribute and sell them with **no attribution and no conditions**.

This does **not** cover the bundled third-party components: the SW_RACER_RE `dinput.dll`/`assets/`
(**AGPL-3.0**), DSOAL (LGPL-2.1), Xidi (BSD-3-Clause) and dgVoodoo2 (freeware, see
`LICENSES/`). The AI textures are derivatives of the game and remain under the game's copyright.
Optional AI-regenerated images derive from SDXL-Lightning (OpenRAIL++) — see ATTRIBUTION.md §2.
Details in [`ATTRIBUTION.md`](ATTRIBUTION.md).
