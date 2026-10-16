#!/usr/bin/env bash
# Remove ReShade from a SWRacer game folder.
#
# ReShade is installed as `opengl32.dll` (this game uses an OpenGL renderer),
# plus ReShade.ini and a couple of shader/preset folders.
#
# Usage: ./uninstall_reshade.sh [path-to-game-dir]
set -euo pipefail

usage() {
    echo "Usage: $0 [path-to-game-dir]   (folder containing SWEP1RCR.EXE)" >&2
    exit 1
}

GAME_DIR="${1:-}"
if [[ -z "$GAME_DIR" ]]; then
    for d in \
        "$HOME/.steam/steam/steamapps/common/Star Wars Episode I Racer" \
        "$HOME/.local/share/Steam/steamapps/common/Star Wars Episode I Racer" \
        "$HOME/Games/Star Wars Episode I Racer"; do
        [[ -f "$d/SWEP1RCR.EXE" ]] && GAME_DIR="$d" && break
    done
fi
[[ -n "$GAME_DIR" && -f "$GAME_DIR/SWEP1RCR.EXE" ]] || usage
GAME_DIR="$(cd "$GAME_DIR" && pwd)"
echo "Game dir: $GAME_DIR"

# opengl32.dll — only delete it if it really looks like ReShade (never nuke a
# game's own DLL by mistake).
if [[ -f "$GAME_DIR/opengl32.dll" ]]; then
    if grep -aqi 'reshade' "$GAME_DIR/opengl32.dll"; then
        rm -f "$GAME_DIR/opengl32.dll"
        echo "removed opengl32.dll"
    else
        echo "WARNING: $GAME_DIR/opengl32.dll doesn't look like ReShade — leaving it." >&2
    fi
fi

for f in ReShade.ini ReShade.log ReShade32.log ReShade64.log; do
    if [[ -f "$GAME_DIR/$f" ]]; then
        rm -f "$GAME_DIR/$f"
        echo "removed $f"
    fi
done

for d in reshade-shaders reshade-presets; do
    if [[ -d "$GAME_DIR/$d" ]]; then
        rm -rf "$GAME_DIR/$d"
        echo "removed $d/"
    fi
done

echo "Done."
echo "Remember to remove 'opengl32' from WINEDLLOVERRIDES in the Steam launch options."
