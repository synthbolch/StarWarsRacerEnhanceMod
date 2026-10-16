# Optional 8x HD textures

This is an **optional** upgrade over the default 4x AI texture pack. It is not
installed by default — see "Installing" below.

## What it is

The default pack upscales every texture 4x with Real-ESRGAN (`realesrgan-x4plus`).
Because that model only does 4x, this pack reaches 8x by **supersampling**:

```
original  --x4plus-->  4x (default pack)  --x4plus again-->  16x  --Lanczos-->  8x
```

A second AI pass adds genuine detail; downscaling 16x → 8x (instead of a hard 8x)
keeps it from over-sharpening or inventing blobs. Hard (1-bit) alpha is
re-binarized at the end so cutouts (palm fronds, floor grates, leaves) stay crisp.

## Is it too much for my GPU?

The pack is 1633 PNGs. Worst case (every texture resident in VRAM at once),
RGBA8 + mipmaps:

| Pack | Total VRAM (all resident) | Notes |
|------|---------------------------|-------|
| original game | ~24 MB | |
| **4x (default)** | **~376 MB** | |
| **8x (this pack)** | **~1.5 GB** | safe on 8 GB cards |
| 16x (not shipped) | ~6 GB | risky on 8 GB |

These are *upper bounds* — the game loads textures per level/scene, so real usage
is a fraction of the table. On an **RTX 4060 8 GB** (the machine this pack was
built and tested on) 8x is comfortable. If you have **4 GB or less**, stay on the
default 4x pack.

## Installing

An all-in-one install (recommended):

```bash
./install.sh --hd-8x "/path/to/Star Wars Episode I Racer"
```

or on Windows (the Windows scripts are **untested**, see the top-level README):

```bat
install.bat --hd-8x "C:\Program Files (x86)\Steam\steamapps\common\Star Wars Episode I Racer"
```

Or, if the mod is already installed, just overwrite the replacement textures:

```bash
cp -f optional/hd_8x/replacement_textures/*.png \
      "/path/to/Star Wars Episode I Racer/assets/replacement_textures/"
```

Uninstalling works the same either way (`./uninstall.sh`): the installer records
the mod's textures as *added* files, so they are removed/restored regardless of
whether the 4x or 8x version is on disk.

## Rebuilding it yourself

```bash
# from a working dir containing extracted/ (originals) and final/ (4x pack)
export VK_ICD_FILENAMES=/usr/share/vulkan/icd.d/nvidia_icd.json
python3 tools/upscale_8x.py extracted final final_8x
```

The AI textures are derivatives of the game art (see `../../ATTRIBUTION.md`).
