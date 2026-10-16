# HD menu / UI textures (optional)

92 upscaled **`.TGA`** menu and UI textures (2–4x), e.g. `cursor.TGA`,
`window_strchbars.tga`, `slider_point.TGA`, `splash.TGA`, `episode1.TGA`.

They are drop-in replacements for the game's `data/images/*.TGA`, so they are
**not** part of the main mod bundle (which only adds the `assets/` the community
renderer loads) — they overlay the originals in place.

Install with the top-level installer:

```bash
./install.sh --ui-hd "/path/to/Star Wars Episode I Racer"
```

```bat
install.bat --ui-hd "C:\...\Star Wars Episode I Racer"
```

or copy the `.TGA`s into `<game>/data/images/` by hand. The installer backs up
every original it overwrites (into `.swracer_enhance_backup/`), so
`uninstall.sh` / `uninstall.bat` restores them exactly.

## Caveats

- The menus were laid out for the **original** TGA sizes. The upscaled art keeps
  the same aspect and (ASCII) names, but if any element looks misaligned on your
  resolution, delete that single `.TGA` (or restore it from the backup) — they are
  independent.
- Works with or without the community `dinput.dll` renderer; the game reads
  `data/images/` directly either way.
- These are upscaled **originals**, not AI-regenerated like `optional/ai_textures/`.
