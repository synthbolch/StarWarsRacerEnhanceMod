# ReShade (optional, non-bundled)

Optional post-processing for the mod's **OpenGL** renderer: FSR-1-style
upscaling, sharpening (CAS), SMAA, and — if the depth buffer cooperates —
screen-space "RT" (MXAO / paid RTGI).

ReShade is **not included** in this bundle. The ReShade project asks that you
don't redistribute its binaries or shader files — link to
<https://reshade.me> instead — so this folder ships only docs and a helper
script and downloads ReShade from the official source.

> Full background (what works, what doesn't, and the gamescope alternative):
> [`../../../docs/UPSCALING.md`](../../../docs/UPSCALING.md).

## The one thing to get right: it must be `opengl32.dll`

This mod replaces the game's renderer with **OpenGL** (SW_RACER_RE), so ReShade
has to install as **`opengl32.dll`** — *not* `d3d9.dll`. On Linux/Proton you also
have to tell Wine to load it:

```
WINEDLLOVERRIDES="dinput=n,b;opengl32=n,b" %command%
```

## Install

### Recommended — let the main installer do it

Both main installers take a `--reshade` flag that downloads and sets up ReShade for you:

```bash
./install.sh --reshade "/path/to/Star Wars Episode I Racer"
```

```bat
install.bat --reshade "C:\...\Star Wars Episode I Racer"
```

That fetches the official ReShade build and installs it as `opengl32.dll`, downloads the
SweetFX and standard-effect shaders into `reshade-shaders/`, writes a `ReShade.ini` pointing
at them, and drops in `SWRacer_Optimized.ini`. It needs `curl` and `unzip` on Linux, and
PowerShell on Windows. Everything it adds is recorded in the install manifest, so
`uninstall.sh` / `uninstall.bat` remove it again. Nothing ReShade ships from this repo — it
comes straight from reshade.me and GitHub at install time.

### Windows

1. Close the game. Download `ReShade_Setup_x.y.z.exe` from <https://reshade.me>.
2. Run it → **"Click here to select a game"** → browse to `SWEP1RCR.EXE`.
3. Rendering API: choose **OpenGL**. Let it download the standard shaders.
4. Launch the game; press **Home** for the ReShade overlay.

### Linux / Steam Proton — helper script

```bash
./install_reshade.sh "/path/to/Star Wars Episode I Racer"
```

It downloads the official ReShade installer and runs it in the game's Proton
prefix (via `protontricks` if present, else system `wine`), then prints the
override to add. In the installer's GUI, select `SWEP1RCR.EXE` and pick
**OpenGL**.

Prefer a known-good community script instead? Use
[`reshade-linux.sh`](https://github.com/kevinlekiller/reshade-steam-proton)
(GPL-2.0): answer `n` to "Vulkan?", `i` to install, point it at the game folder,
and answer `opengl32` when it asks for the DLL name.

> The helper script is **untested** (like the Windows installer scripts) — the
> manual/`reshade-linux.sh` route is the safe fallback.

## Bundled preset: `SWRacer_Optimized.ini`

A tuned starting point is included. It needs only the **SweetFX** effect package
(the classic `CAS.fx` / `SMAA.fx` / `Vibrance.fx` — the default ReShade package
browser installs it), so nothing extra to hunt down.

- **Enabled:** `SMAA` (anti-aliasing) → `CAS` (sharpening) → `Vibrance` (subtle
  colour). Strength is deliberately conservative so it sharpens the HD textures
  without haloing.
- **Off by default** (present in the list, tick to try): `LumaSharpen` (an
  alternative sharpener) and `FakeHDR` (cosmetic "HDR" glow — can blow out
  highlights, so leave off unless you like it).
- Only **spatial** effects, so no depth buffer is required.

To use it, copy it next to ReShade and load it:

```bash
cp SWRacer_Optimized.ini "/path/to/Star Wars Episode I Racer/"
```

In the game, press **Home** → the preset dropdown at the top → pick
`SWRacer_Optimized.ini`. To make it the default, set it as the
*Startup preset* in ReShade's Settings tab, or launch with
`ReShade.ini`'s preset path pointing at it.

Tuning knobs (edit in the overlay, it live-updates):

| Want | Change |
|---|---|
| Less / more sharpening | `CAS.fx` → **Sharpening** (0.0–1.0, default here 0.6) |
| Smoother edges | `SMAA.fx` → raise `MaxSearchSteps` (32 → 48/64) |
| Catch more edges | `SMAA.fx` → lower `EdgeDetectionThreshold` (0.10 → 0.08) |
| More colour | `Vibrance.fx` → **Vibrance** (0.10 → 0.2–0.3) |

> The preset assumes the shaders from the **SweetFX by CeeJay.dk** package. If
> ReShade reports it as incomplete, install that package in the
> *Settings → Effects* browser.

## Suggested effects


Add these via ReShade's in-game package browser (Home → Settings → Effects) or
the [crosire/reshade-shaders](https://github.com/crosire/reshade-shaders) pack:

- `CAS.fx` — contrast-adaptive sharpening (cheap, big win)
- `SMAA.fx` — anti-aliasing (the mod also has MSAA)
- `Clarity.fx` / `LumaSharpen.fx` — extra sharpening / punch
- FSR-1 / NIS shader ports — spatial upscaling as a post-process
- `SSR.fx` / `qUINT_ssr.fx` — screen-space reflections (fake mirror floors)
- `MagicBloom.fx` / `DOF.fx` — glow / depth-of-field
- `FakeHDR.fx` — SDR→"HDR" tonemap (cosmetic only; no real HDR output)
- `MXAO.fx` (MIT) or **iMMERSE RTGI** (paid) — screen-space AO/GI; only if the
  *Depth buffer* tab finds depth (MSAA can block it)

See [`../../../docs/UPSCALING.md`](../../../docs/UPSCALING.md#suggested-effects)
for what each does and their licenses.

## Uninstall

```bash
./uninstall_reshade.sh "/path/to/Star Wars Episode I Racer"
```

It removes `opengl32.dll` (only after confirming it is ReShade's), `ReShade.ini`,
`ReShade.log`, `reshade-shaders/` and `reshade-presets/`. Then drop
`opengl32=n,b` from Launch Options. On Windows, re-run the ReShade installer and
choose *uninstall*, or delete those files by hand.

## License

ReShade itself is **BSD-3-Clause** (© Patrick Mours), but is not redistributed
here; the scripts and this README are part of this project (WTFPL — see the
top-level [`LICENSE`](../../../LICENSE)). Individual shaders carry their own
licenses — check each shader's header before sharing a preset.
