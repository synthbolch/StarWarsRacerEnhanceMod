# Running the mod on Linux / Steam Proton

The mod is a **Windows** `dinput.dll` loader. On Linux it runs through Steam
Proton, and Proton needs one extra setting or the loader is silently ignored.

## Symptom

The game launches and plays, but there is **no mod**: pressing **F5** does
nothing, no HD textures, no new renderer. The game folder has **no
`hook.log`** (the file SW_RACER_RE writes when its loader starts).

## Cause

The game's executable imports `DINPUT.dll`. Wine/Proton defaults to its **builtin**
`dinput.dll` and ignores the native one that `install.sh` put in the game folder. You
can see it in a `WINEDEBUG=+loaddll` trace:

```
Loaded L"Z:\...\Star Wars Episode I Racer\DINPUT.dll" ... : builtin   ← mod not loaded
```

## Fix — set a DLL override

In Steam: **Library → right-click *STAR WARS Episode I Racer* → Properties →
Launch Options**, and add `WINEDLLOVERRIDES="dinput=n,b"` in front of
`%command%`. If you already have other options (e.g. Wayland), keep them:

```
WINEDLLOVERRIDES="dinput=n,b" SDL_VIDEODRIVER=wayland PROTON_ENABLE_WAYLAND=1 %command%
```

- `dinput=n,b` = load the **native** (modded) `dinput.dll` first, fall back to
  builtin only if it fails. This makes SW_RACER_RE's loader run.

### Optional: DSOAL 3D audio

The bundle also ships DSOAL's `dsound.dll` (loaded via the game's `Smush.dll`).
For it to be used, add `dsound` to the override too:

```
WINEDLLOVERRIDES="dinput=n,b;dsound=n,b" SDL_VIDEODRIVER=wayland PROTON_ENABLE_WAYLAND=1 %command%
```

Without it the game still has sound — just Wine's builtin `dsound`, not DSOAL's
HRTF 3D audio.

> Do **not** add a `ddraw` override. The game's own `ddraw.dll` is intentionally
> left to Wine's builtin DirectDraw; the mod replaces the renderer itself.

## Verify it worked

Launch the game, then check the game folder for **`hook.log`**:

```bash
ls "$HOME/.steam/steam/steamapps/common/Star Wars Episode I Racer/hook.log"
# or wherever your Steam library is
```

If it exists (its first line is `[stage] DllMain`), the loader ran — press **F5**
in game for the mod menu. (The log is also useful for crashes: it records what the
hook was doing, and crash dumps go to a `crashes/` subfolder.)

## The game runs in a tiny 640×480 window

The mod opens its window at **640×480** and then calls `glfwMaximizeWindow`, which
does **not** take effect under Wayland/Proton — so the game stays in a small window
and your HD textures are hard to see. The fix is to make the window full-size; the
game then renders at that size (its framebuffer-size callback keeps the render
resolution in sync), so textures show at full quality.

Pick either:

- **Press `Alt+Enter` in game.** This toggles exclusive fullscreen at your monitor's
  native resolution and saves the setting automatically.
- **F5 menu → *Graphics Settings* panel → *Window mode*** and choose **Borderless**
  (fills the screen without a mode switch — best for alt-tabbing) or **Fullscreen**.

The choice is saved to `SW_RACER_RE.ini` as `window_mode=1` (borderless) or `2`
(fullscreen); `0` is windowed. You can also edit that file by hand while the game is
closed.

> If borderless/fullscreen misbehaves with the Wayland flags, remove
> `PROTON_ENABLE_WAYLAND=1 SDL_VIDEODRIVER=wayland` from Launch Options to fall back
> to XWayland; the DLL override must stay.

## Alternative without Steam launch options

You can set the override in the Proton prefix directly (useful for non-Steam
launchers or scripts). Using protontricks:

```bash
protontricks 808910 winecfg      # Libraries tab -> add "dinput" -> Edit -> "native, builtin"
```

Or run the game under Proton manually with the variable set in the environment.

## Notes

- AppID for *STAR WARS Episode I Racer* is **808910**.
- This is only needed on Linux/Wine/Proton. On real Windows the game loads the
  app-local `dinput.dll` natively and no override is needed.

## See also

- **Upscaling / sharpening** on Linux — gamescope `-F fsr`/`-F nis`, or ReShade
  installed as `opengl32.dll` (needs the `opengl32=n,b` override):
  [`UPSCALING.md`](UPSCALING.md).
