# Upscaling, sharpening and "ray tracing"

This page answers the obvious "can we add FSR/DLSS/ray tracing to this?" question.
The short version: **spatial upscaling and sharpening, yes — DLSS and real ray
tracing, no.** Everything hinges on one fact:

> The community mod (`dinput.dll`) **replaces the game's renderer with its own
> OpenGL renderer**. On Windows the original DirectDraw/DirectX 6 path is
> bypassed; on Linux everything runs through Proton's OpenGL.

That rules out anything that hooks a specific Direct3D API, and it means the
things that *do* work are the ones that sit on top of any renderer — a compositor,
a window-capture scaler, or a generic OpenGL overlay.

## TL;DR

| Want | Possible? | How |
|---|---|---|
| FSR 1.0 upscaling | ✅ | **gamescope `-F fsr`** (Linux, no files) · ReShade FSR shader · Magpie (Win) |
| NVIDIA NIS / Snapdragon SGSR | ✅ | gamescope `-F nis` / `-F sgsr` |
| Integer scaling / pixel look | ✅ | gamescope `-S integer` · `Super+N` |
| Sharpening (CAS / RCAS / LumaSharpen) | ✅ | gamescope `--sharpness` · ReShade (`CAS.fx`) · Magpie |
| Anti-aliasing (SMAA) | ✅ | ReShade `SMAA.fx` (mod also has MSAA) |
| HDR look for this SDR game | ⚠️ | **Special K** (Win, incl. OpenGL) · **gamescope `--hdr-itm-enable`** (Linux) · ReShade `FakeHDR.fx` |
| Screen-space "RT" (RTGI/AO/SSR) | ⚠️ | ReShade + paid **RTGI**, or free `MXAO.fx` / SSR — needs depth buffer, may not work |
| Frame generation | ⚠️ Win | **Lossless Scaling** / **Magpie-FG** (window capture, any API); **NVIDIA Smooth Motion** & **lsfg-vk** are DX/Vulkan-only |
| **DLSS** | ❌ | needs engine integration (NGX + motion vectors); no generic injector |
| **FSR 2/3, FSR frame-gen** | ❌ | needs depth/motion vectors + engine integration |
| **vkBasalt / VulkanFX / vkShade** | ❌ | Vulkan-only layers; this renderer is OpenGL (see the Zink note) |
| **NVIDIA RTX HDR / Smooth Motion** | ❌ | driver features support DX/Vulkan, **not OpenGL** |
| **RTX Remix** | ❌ | it replaces D3D8/9 fixed-function; this is D3D6/DirectDraw + OpenGL |
| **True ray/path tracing** | ❌ | would mean rewriting the renderer (see below) |

Everything recommended here is an **optional, external** thing — it is not part
of `install.sh`, it adds no files to the mod bundle (except ReShade's own DLL if
you choose it), and `uninstall.sh` is unaffected.

---

## 1. Linux / Steam Proton — gamescope (recommended)

[gamescope](https://github.com/ValveSoftware/gamescope) is Steam's micro-compositor.
It can upscale **anything** it hosts, at the compositor level, with **zero files in
the game directory** — the cleanest "FSR for a GL game" there is.

Install (Arch/CachyOS: `sudo pacman -S gamescope`; Debian/Ubuntu: `sudo apt install gamescope`),
then put it in the game's Steam **Launch Options**, in front of `%command%`:

```
WINEDLLOVERRIDES="dinput=n,b" gamescope -f -w 1280 -h 720 -W 2560 -H 1440 -F fsr --sharpness 4 -- %command%
```

- Steam runs the game at **`-w`×`-h`** (here 720p) and gamescope presents it at
  **`-W`×`-H`** (here 1440p) using **FSR 1.0** — the same spatial upscaler as
  in-game "FSR", so it's cheap and looks good at ≥720p internal.
- `--sharpness` is **0 (max) … 20 (min)**; the default is 5. Lower = sharper.
- Keep your existing mod override; combine everything into one line (order
  doesn't matter as long as `-- %command%` is last).

Useful flags:

| Flag | Meaning |
|---|---|
| `-f` | fullscreen |
| `-b` | borderless window |
| `-t` | enable adaptive sync (VRR) |
| `-W` / `-H` | **output** width/height (what you see) |
| `-w` / `-h` | **internal** (game) width/height — set this lower than output for FSR to help |
| `-F fsr` | AMD FidelityFX Super Resolution 1.0 |
| `-F nis` | NVIDIA Image Scaling v1.0.3 |
| `-F sgsr` | Snapdragon Game Super Resolution (RCAS sharpening) — newer gamescope |
| `-S integer` | integer scaling (crisp pixels, e.g. `-h 720 -H 1440`) |
| `-S stretch` | stretch to fill (4:3 → 16:9) |
| `--sharpness N` | upscaler sharpness, 0 (max) … 20 (min) |
| `-r N` | cap the game to N FPS |

In-game hotkeys (no relaunch): **Super+U** toggle FSR · **Super+Y** toggle NIS ·
**Super+N** toggle nearest · **Super+I/O** sharpness up/down · **Super+F** fullscreen.

Examples:

```bash
# 720p -> 1440p with FSR
gamescope -f -w 1280 -h 720 -W 2560 -H 1440 -F fsr -- %command%
# run at 1080p, upscale to 4K with NIS
gamescope -f -w 1920 -h 1080 -W 3840 -H 2160 -F nis -- %command%
# crisp integer scaling (720p -> 1440p, no blur)
gamescope -f -h 720 -H 1440 -S integer -- %command%
# SDR -> HDR inverse tone mapping (see §4); needs an HDR display + compositor
gamescope -f -W 2560 -H 1440 --hdr-enabled --hdr-itm-enable --hdr-itm-sdr-nits 300 -- %command%
```

> **Notes.** gamescope is only for Linux. On Wayland you can usually drop
> `SDL_VIDEODRIVER=wayland PROTON_ENABLE_WAYLAND=1` when using gamescope; if the
> game misbehaves, keep them. If you already set a window mode in the mod
> (`SW_RACER_RE.ini`: `window_mode=0/1/2`), let gamescope own the fullscreen and
> leave the mod windowed. The 4:3 2D UI stays pillarboxed either way.

---

## 2. ReShade (Windows **and** Linux/Proton)

[ReShade](https://reshade.me) is a generic post-processing overlay. Because the
renderer is **OpenGL**, ReShade must be installed as **`opengl32.dll`** — *not*
`d3d9.dll`. This is the part people usually get wrong.

ReShade is **not bundled** here: reshade.me asks that you don't redistribute its
binaries or shaders ("link users to this website instead"). Use the official
installer or one of the community Linux scripts below. A tuned preset **is**
shipped (it's just a config, no shader code) — see
[`SWRacerEnhanceMod/optional/reshade/SWRacer_Optimized.ini`](../SWRacerEnhanceMod/optional/reshade/SWRacer_Optimized.ini)
(CAS + SMAA + Vibrance, using the standard "SweetFX by CeeJay.dk" package).

### Windows

1. Close the game. Download `ReShade_Setup_x.y.z.exe` from <https://reshade.me>.
2. Run it, click **"Click here to select a game"**, browse to
   `SWEP1RCR.EXE` in your game folder.
3. When asked for the **rendering API**, choose **OpenGL**. Let it download the
   standard shader collection when prompted.
4. Launch the game; the ReShade banner appears. Press **Home** for the overlay.

### Linux / Steam Proton

The most reliable route is the maintained script
[`kevinlekiller/reshade-steam-proton`](https://github.com/kevinlekiller/reshade-steam-proton)
(`reshade-linux.sh`, GPL-2.0):

```bash
curl -LO https://github.com/kevinlekiller/reshade-steam-proton/raw/main/reshade-linux.sh
chmod +x reshade-linux.sh
./reshade-linux.sh
#   "uses the Vulkan API?" -> n
#   action               -> i   (install)
#   game directory       -> the folder containing SWEP1RCR.EXE
#   API                  -> OpenGL   (answer 'n' to auto-detect, then type "opengl32")
```

or the small helper shipped with this mod:

```bash
SWRacerEnhanceMod/optional/reshade/install_reshade.sh "/path/to/Star Wars Episode I Racer"
```

Either way you end up with `opengl32.dll` + `ReShade.ini` in the game folder, and
you must tell Proton to load it — add `opengl32` to your override:

```
WINEDLLOVERRIDES="dinput=n,b;opengl32=n,b" %command%
```

Verify via `ReShade.log` in the game folder, or the in-game **Home** overlay.

### Suggested effects

Install shaders in-game through ReShade's own package browser (Home → *Settings* →
*Effects*), or point it at the [crosire/reshade-shaders](https://github.com/crosire/reshade-shaders)
collection. Reasonable picks for this game (all spatial — no motion vectors needed):

| Effect | File | License | Purpose |
|---|---|---|---|
| FSR 1 upscale | FSR shader (community ports in `reshade-shaders`) | MIT | AMD FSR1 as post-process |
| NIS | NIS shader port | MIT | NVIDIA Image Scaling |
| CAS | `CAS.fx` | MIT | contrast-adaptive sharpening |
| LumaSharpen | `LumaSharpen.fx` | MIT | lightweight sharpening |
| Clarity | `Clarity.fx` | MIT | local contrast / "punch" |
| SMAA | `SMAA.fx` | MIT | anti-aliasing (the mod also has MSAA) |
| MXAO / SSAO | `MXAO.fx` | MIT | screen-space ambient occlusion |
| SSR | `SSR.fx` / `qUINT_ssr.fx` | MIT | screen-space reflections (fake mirror floors) |
| Bloom / DOF | `MagicBloom.fx`, `DOF.fx` | MIT | glow / depth-of-field |
| FakeHDR | `FakeHDR.fx` | MIT | SDR→"HDR" tonemap (no real HDR output) |
| RTGI | **iMMERSE RTGI** (Pascal Gilcher) | **paid** | screen-space ray-traced GI — the closest thing to "RT" you can drop in |

> Depth-dependent effects (MXAO, SSR, RTGI, DOF) need depth-buffer access. Check
> each shader's own header for its license before redistributing a preset.

### Caveats

- **Depth buffer.** AO/GI-style effects need depth access, which ReShade's
  OpenGL backend may or may not get for this app. If ReShade's *Depth buffer*
  tab shows nothing, skip MXAO/RTGI/SSR. MSAA can interfere with depth access.
- **Cost.** FSR/NIS/CAS are cheap; MXAO/RTGI/SSR are not — but this game is
  GPU-light, so even a 4060 has plenty of headroom at 1440p/4K.
- **Anti-cheat / online.** Irrelevant here (single-player), but ReShade is
  generally a no-go in competitive online games.
- If effects fail to compile, ReShade may need `d3dcompiler_47` in the game
  folder (`protontricks`/`winetricks` can add it).

### Uninstall

Windows: re-run the ReShade installer and choose **Uninstall**, or delete
`opengl32.dll`, `ReShade.ini`, `ReShade.log`, `reshade-shaders/`, `reshade-presets/`
from the game folder. Linux:

```bash
SWRacerEnhanceMod/optional/reshade/uninstall_reshade.sh "/path/to/Star Wars Episode I Racer"
```

…and drop `opengl32=n,b` from Launch Options.

---

## 3. Other overlay upscalers & HDR tools

None of these are bundled; all are optional and external.

### Magpie (Windows, GPL-3.0)

[Magpie](https://github.com/Blinue/Magpie) is a general-purpose **window
upscaler**: it captures a window and re-draws it with a scaling shader — FSR 1,
CAS, Anime4K, CRT/LCD filters and more — so it works with *any* renderer,
including this OpenGL one, with no injection at all. Requirements: Windows 10/11,
a DX11-class GPU, and the game in **windowed** mode. The
[`Magpie-FG`](https://github.com/meokit/Magpie-FG) fork adds frame generation.

Think of it as a free, self-hosted equivalent of Lossless Scaling.

### Special K (Windows) — HDR retrofit + pacing

[Special K](https://wiki.special-k.info/) injects into **OpenGL** games (as
`opengl32.dll`) and is the strongest HDR option on Windows. For OpenGL it
"promotes" the game to **OpenGL-IK** (final presentation goes through a D3D11
interop swapchain), which enables:

- **HDR Retrofit** — SDR→HDR with a configurable tone mapper (works in D3D11/12
  and OpenGL; render-pass "remastering" is limited in OpenGL).
- A high-quality **frame limiter** (good pacing) and **NVIDIA Reflex** injection.
- Forcing window modes, resolution, borderless, always-on-top.
- Loading/injecting other DLLs — including ReShade.

Heavier and more complex than ReShade; Windows-only.

### Lossless Scaling (Windows, paid)

[Lossless Scaling](https://losslessscaling.com) captures the window and offers
both upscaling (LS1/FSR) **and** frame generation, on any API including OpenGL.
Windows-only. Its frame-generation algorithm is the one underpinning `lsfg-vk`
on Linux (below).

### NVIDIA app driver features (Windows)

All of these are driver-side and support **DirectX/Vulkan**, but **not OpenGL**,
so they won't hook this renderer directly (use Magpie/Lossless Scaling, which
capture the window, instead):

- **Image Scaling / DLDSR** — driver scaling, sharpening and supersampling.
- **RTX HDR** — SDR→HDR Freestyle filter for DX9/11/12 + Vulkan (Win11, RTX 20+).
- **Smooth Motion** — driver frame generation for DX11/12 + Vulkan (RTX 40/50).

### dgVoodoo2 (already in `optional/third_party/dgvoodoo/`)

Only relevant for the **un-modded** game (it wraps DirectDraw/D3D). It can do
supersampling/forced filtering for non-mod play, but not with the OpenGL mod.

---

## 4. Linux: HDR and frame generation

- **HDR — gamescope `--hdr-enabled`.** gamescope can present HDR and, with
  **`--hdr-itm-enable --hdr-itm-sdr-nits N`**, *inverse tone-map SDR content to
  HDR* at the compositor level. Because that happens after the game, it works
  regardless of API — so it can give this GL game an HDR-style look on an
  HDR display. Needs a Wayland compositor with color management (KDE 6.x,
  Gamescope session) and a driver that exposes HDR metadata (Mesa 23+ / recent
  NVIDIA). **NVIDIA + gamescope HDR is known to be flaky** (AMD is the
  supported path); treat it as experimental.
- **Frame generation — lsfg-vk.** [lsfg-vk](https://lsfg-vk.dev/) ports Lossless
  Scaling's frame generation to Linux as a **Vulkan layer**. That's Linux's only
  general frame-gen — but it hooks **Vulkan** apps (i.e. DXVK/VKD3D games under
  Proton), not a native OpenGL renderer.
- **Post-processing — vkBasalt / VulkanFX / vkShade.** Vulkan layers doing
  CAS / denoise-sharpen / FXAA / SMAA / LUT / ReShade-FX. Confirmed by their own
  authors: **there is no OpenGL version** ("OpenGL has no layer system like
  Vulkan").
- **The Zink route (advanced, not recommended).** Mesa's
  [Zink](https://docs.mesa3d.org/drivers/zink.html) translates OpenGL → Vulkan.
  *If* the game's GL ran on Zink, every Vulkan layer above (vkBasalt, lsfg-vk,
  and NVIDIA Smooth Motion's Linux implicit layer) would suddenly apply. In
  practice this is fragile: Zink on NVIDIA's proprietary driver is
  unsupported/irregular, and wiring Wine/Proton's GL to Zink is non-trivial.
  Listed for completeness only.

---

## 5. Frame generation (summary)

Frame interpolation needs either engine depth+motion vectors (FSR-FG / DLSS-FG)
or a **frame-capture** interpolator that doesn't need the game's cooperation:

| Option | Where | APIs | Works for this GL game? |
|---|---|---|---|
| Lossless Scaling | Windows (paid) | any (window capture) | ✅ |
| Magpie-FG | Windows (FOSS) | any (window capture) | ✅ |
| NVIDIA Smooth Motion | Windows; Linux (Vulkan layer) | DX11/12, Vulkan | ❌ (no OpenGL) |
| lsfg-vk | Linux (Vulkan layer) | Vulkan | ❌ unless via Zink |
| FSR-FG / DLSS-FG | — | needs game integration | ❌ |

So on **Linux** there is currently **no** frame generation for this game; on
**Windows**, a window-capture tool (Lossless Scaling or Magpie-FG) is the only way.

---

## 6. What won't work, and why

- **DLSS** — requires the game to call NVIDIA's NGX with motion vectors and jitter;
  it is per-engine integration, not an injectable DLL. No generic DLSS injector
  exists. (Tools like **OptiScaler** can *swap* DLSS↔FSR↔XeSS, but only in games
  that already implement one of them — this one implements none.)
- **FSR 2 / FSR 3 (temporal) & FSR frame-gen** — same: needs depth, motion
  vectors and jitter from the renderer. Only FSR **1** (spatial) is usable as an
  external post-process.
- **vkBasalt / VulkanFX / vkShade** — Vulkan-only layers; this renderer is OpenGL
  (see the Zink note in §4).
- **NVIDIA Smooth Motion / RTX HDR** — driver features that support DX and Vulkan
  but **not OpenGL**, so they don't see this renderer.
- **RTX Remix** — it's a Direct3D **8/9** fixed-function *replacement* renderer
  (Windows). This game is DirectDraw/D3D6, and with the mod it's OpenGL, so Remix
  has nothing to hook. The original `D3DImm.dll`/`DDraw.dll` in
  `optional/third_party/dgvoodoo/` are for compatibility, not Remix.
- **Hardware ray tracing** — the scene has no BVH/ray-tracing API; adding real RT
  means rewriting the OpenGL renderer. The only realistic "RT-like" upgrades are
  **screen-space** (ReShade RTGI/MXAO/SSR), which approximate lighting/reflections
  from the depth buffer.
- **Magpie / Special K** are Windows-only, so they don't help on Linux (use
  gamescope / ReShade-linux there).

> **If you really wanted FSR 2/RT**, the renderer is open source: SW_RACER_RE is
> **AGPL-3.0**. Someone could fork it and integrate FSR (or a ray tracer) into
> the actual render pipeline. That's a code project, not an optional add-on, and
> out of scope for this bundle. (And note: the mod already adds **PBR + IBL** —
> physically-based materials and image-based lighting — which is the biggest
> "modern/RT-look" win available and is already in the box.)

---

## 7. Recommendation

- **On Linux/Proton:** use **gamescope** (`-F fsr` or `-F nis`). Nothing to
  install into the game, fully reversible, works today. Add
  `--hdr-enabled --hdr-itm-enable` if you have an HDR display and want to
  experiment.
- **Want sharpening/prettier output:** add **ReShade** as `opengl32.dll` (Windows)
  or via `reshade-linux.sh` (Proton) and enable `CAS.fx` + `SMAA.fx` (plus
  MXAO/SSR if depth works).
- **On Windows:** try **Magpie** (free FSR/CAS/Anime4K window scaler) or
  **Special K** if you want HDR and better frame pacing.
- **Ignore DLSS, vkBasalt, NVIDIA RTX HDR/Smooth Motion, RTX Remix and true ray
  tracing** — they don't fit this game's OpenGL architecture.
