# Contributing

Thanks for helping improve the **SWRacer Enhance Mod**. This is a *distribution / repack*
project: it merges existing community fixes with AI-generated HD textures into one
reversible installer. The most useful contributions are:

- **Bug reports / fixes** in the installers and scripts (`install.*`, `uninstall.*`,
  `change_textures.*`, `tools/*.py`).
- **Install/uninstall edge cases** — missing files, leftovers, wrong backups.
- **Texture work** — better upscales, fixed alpha, new optional packs.
- **Docs** — corrections and clarifications (see [`docs/README.md`](docs/README.md)).

## Ground rules (please don't break these)

1. **Never rename the shipped folders/files.** The community `dinput.dll` and the game
   hardcode paths such as `./assets/replacement_textures`; renaming them silently disables
   the mod. Folder names stay unprefixed.
2. **Keep the full package committed.** The optional packs (`optional/hd_8x`,
   `optional/ai_textures`, `optional/ui_hd`) are
   tracked on purpose, so `install.sh --hd-8x/--ai-*/--ui-hd` works from a plain clone.
   Don't add them to `.gitignore`.
3. **Binaries stay binary.** Keep the `*.dll` / `*.png` / `*.TGA` / … markers in
   [`.gitattributes`](.gitattributes) so git doesn't try to text-diff or merge assets.

## Testing

The installers are designed to be **reversible** and can be tested without the game:

```bash
mkdir -p /tmp/fakegame && : > /tmp/fakegame/SWEP1RCR.EXE
./install.sh /tmp/fakegame
./change_textures.sh list /tmp/fakegame
./uninstall.sh /tmp/fakegame
```

After `uninstall.sh`, `/tmp/fakegame` should be back to only `SWEP1RCR.EXE` (plus whatever
it originally contained). Please run this round-trip for any installer change.

> The Windows scripts (`install.bat`/`.ps1`, `uninstall.*`, `change_textures.*`) are
> **untested** — there is no Windows runtime to verify them. If you fix or verify them,
> say so in your pull request.

The Python texture tools need `realesrgan-ncnn-vulkan` (plus the downloaded models) and,
for the AI packs, PyTorch `diffusers`. See [`docs/HD_TEXTURE_PIPELINE.md`](docs/HD_TEXTURE_PIPELINE.md).

## Commit messages

- Subject line: imperative mood, ~50 characters (e.g. `Fix uninstall leaving empty dirs`).
- Disclose AI assistance with a dedicated trailer — **not** `Co-authored-by:`:

  ```text
  Assisted-by: <agent>:<model>      # e.g. Assisted-by: OpenCode:Big Pickle
  ```

  Use the real agent and model (e.g. `OpenCode:Big Pickle`) and don't imply authorship.
  If you used an agent, use the `Assisted-by:` form; if you used none, no trailer is needed.

## Licensing

Your contributions are accepted under **WTFPL v2**, the project license (see
[`LICENSE`](LICENSE)). Bundled third-party components keep their upstream licenses — see
[`SWRacerEnhanceMod/ATTRIBUTION.md`](SWRacerEnhanceMod/ATTRIBUTION.md). Don't add files you
can't redistribute.

## Working with AI agents

If you drive a coding agent on this repo, have it read [`AGENTS.md`](AGENTS.md) first.
