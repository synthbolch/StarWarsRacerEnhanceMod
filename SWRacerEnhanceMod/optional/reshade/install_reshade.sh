#!/usr/bin/env bash
# Download and install ReShade for the SWRacer Enhance Mod's OpenGL renderer.
#
# ReShade is NOT bundled with this mod: the ReShade project asks that you don't
# redistribute its binaries or shader files (link to https://reshade.me instead).
# So this script fetches the *official* installer and runs it against the game
# folder; nothing ReShade is shipped here.
#
# Usage: ./install_reshade.sh [--dry-run] [path-to-game-dir]
#
# IMPORTANT: this mod's renderer is OpenGL, so ReShade must be installed as
# `opengl32.dll`, and the game must load it via a Wine/Proton override:
#     WINEDLLOVERRIDES="dinput=n,b;opengl32=n,b" %command%
#
# NOTE: untested, like this project's other helper scripts. If anything looks
# off, use the manual steps in README.md or the maintained
# kevinlekiller/reshade-steam-proton `reshade-linux.sh` instead.
set -euo pipefail

APPID=808910   # STAR WARS Episode I Racer (Steam)

usage() {
    cat >&2 <<EOF
Usage: $0 [--dry-run] [path-to-game-dir]
  path-to-game-dir   folder containing SWEP1RCR.EXE (auto-detected if omitted)
  --dry-run          download the installer and stop (don't run it)

ReShade is installed as opengl32.dll (this game uses an OpenGL renderer) and
needs the Steam launch option:  WINEDLLOVERRIDES="dinput=n,b;opengl32=n,b"
EOF
    exit 1
}

DRY_RUN=0
GAME_DIR=""
for arg in "$@"; do
    case "$arg" in
        --dry-run) DRY_RUN=1 ;;
        -h|--help) usage ;;
        -*) echo "ERROR: unknown option '$arg'" >&2; usage ;;
        *) GAME_DIR="$arg" ;;
    esac
done

if [[ -z "$GAME_DIR" ]]; then
    for d in \
        "$HOME/.steam/steam/steamapps/common/Star Wars Episode I Racer" \
        "$HOME/.local/share/Steam/steamapps/common/Star Wars Episode I Racer" \
        "$HOME/Games/Star Wars Episode I Racer"; do
        [[ -f "$d/SWEP1RCR.EXE" ]] && GAME_DIR="$d" && break
    done
fi
[[ -n "$GAME_DIR" && -f "$GAME_DIR/SWEP1RCR.EXE" ]] || {
    echo "ERROR: game dir not found (must contain SWEP1RCR.EXE)." >&2
    usage
}
GAME_DIR="$(cd "$GAME_DIR" && pwd)"
echo "Game dir: $GAME_DIR"

# --- find + download the official ReShade installer --------------------------
echo "Finding the latest ReShade installer..."
PAGE="$(curl -fsSL https://reshade.me 2>/dev/null || true)"
SETUP_REL="$(printf '%s' "$PAGE" | grep -oE 'downloads/ReShade_Setup_[0-9.]+\.exe' | head -n1 || true)"

if [[ -z "$SETUP_REL" ]]; then
    cat >&2 <<'EOF'
ERROR: could not find the ReShade download link automatically.
Download ReShade by hand from https://reshade.me, run its installer, choose
  SWEP1RCR.EXE  and the  OpenGL  rendering API. See README.md.
EOF
    exit 1
fi
SETUP_URL="https://reshade.me/$SETUP_REL"
echo "  $SETUP_URL"

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
SETUP="$TMP/${SETUP_URL##*/}"
curl -fL --progress-bar -o "$SETUP" "$SETUP_URL"
echo "Downloaded: $SETUP"

if [[ "$DRY_RUN" == "1" ]]; then
    OUT_DIR="${XDG_DOWNLOAD_DIR:-$HOME/Downloads}"
    mkdir -p "$OUT_DIR" 2>/dev/null || OUT_DIR="$PWD"
    cp -f "$SETUP" "$OUT_DIR/${SETUP_URL##*/}"
    echo "Dry run: saved $OUT_DIR/${SETUP_URL##*/} — run it and choose the OpenGL API."
    exit 0
fi

# --- run the installer -------------------------------------------------------
if command -v protontricks >/dev/null 2>&1; then
    RUNNER=protontricks
elif command -v wine >/dev/null 2>&1; then
    RUNNER=wine
else
    cat >&2 <<EOF
ERROR: neither 'protontricks' nor 'wine' was found.
Run the installer yourself, choosing SWEP1RCR.EXE + OpenGL:
    wine "$SETUP"
or follow the manual steps in README.md.
EOF
    exit 1
fi

cat <<EOF

Launching the ReShade installer with '$RUNNER'. In the installer:
  * game:  $GAME_DIR/SWEP1RCR.EXE
  * API:   OpenGL   (NOT Direct3D)
  * accept the standard shader download when asked
EOF
echo

if [[ "$RUNNER" == "protontricks" ]]; then
    protontricks -c "wine \"$SETUP\"" "$APPID"
else
    wine "$SETUP"
fi

# --- post-install guidance ---------------------------------------------------
echo
if [[ -f "$GAME_DIR/opengl32.dll" ]]; then
    echo "ReShade DLL present: $GAME_DIR/opengl32.dll"
else
    echo "WARNING: opengl32.dll not found in the game dir — install may not have finished." >&2
fi
cat <<EOF

Add 'opengl32' to your Steam launch options (before %command%):

    WINEDLLOVERRIDES="dinput=n,b;opengl32=n,b" %command%

Then launch the game and press Home for the ReShade overlay.
Log:       $GAME_DIR/ReShade.log
Uninstall: ./uninstall_reshade.sh "$GAME_DIR"
EOF
