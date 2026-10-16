#!/usr/bin/env bash
# Change the texture pack of an ALREADY-INSTALLED SWRacer Enhance Mod, without
# re-running the full installer.
#
# Usage: ./change_textures.sh <pack> [path-to-game-dir]
#   pack: default | 8x | realistic | clonewars | list
#
# Every mode first lays the default 4x pack down, then overlays the requested
# pack, so the result is always consistent (e.g. the 12 logo/UI textures the AI
# packs skip stay at 4x, not at a leftover 8x resolution).
#
# The game's original files are NOT touched: replacement_textures/ is a folder
# the mod adds, and its entries are already recorded in
# .swracer_enhance_backup/manifest.tsv, so uninstall.sh still removes them all.
set -euo pipefail

usage() {
    echo "Usage: $0 <pack> [path-to-game-dir]   (dir containing SWEP1RCR.EXE)" >&2
    echo "  pack:" >&2
    echo "    default      the shipped 4x HD pack (Real-ESRGAN)" >&2
    echo "    8x           the optional 8x pack (optional/hd_8x)" >&2
    echo "    realistic    AI-regenerated, photoreal (optional/ai_textures/realistic)" >&2
    echo "    clonewars    AI-regenerated, Clone Wars style (optional/ai_textures/clonewars)" >&2
    echo "    list         show the packs and which one is currently installed" >&2
    exit 1
}

PACK="${1:-}"
shift || true
if [[ -z "$PACK" || "$PACK" == "-h" || "$PACK" == "--help" ]]; then usage; fi

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

SRC="$(cd "$(dirname "$0")" && pwd)/SWRacerEnhanceMod"
[[ -d "$SRC" ]] || { echo "ERROR: $SRC not found" >&2; exit 1; }

BASE="$SRC/assets/replacement_textures"
DEST="$GAME_DIR/assets/replacement_textures"
declare -A PACK_DIR=(
    [default]="$BASE"
    [8x]="$SRC/optional/hd_8x/replacement_textures"
    [realistic]="$SRC/optional/ai_textures/realistic/replacement_textures"
    [clonewars]="$SRC/optional/ai_textures/clonewars/replacement_textures"
)

[[ -d "$BASE" ]] || { echo "ERROR: $BASE not found (incomplete mod bundle)" >&2; exit 1; }

# --- detect which pack is currently installed (by hashing a few files) -------
detect_pack() {
    [[ -d "$DEST" ]] || { echo "not installed"; return; }
    # sample ids that exist in every candidate pack
    local samples=() d id
    while IFS= read -r id; do
        local all=1
        for d in "${PACK_DIR[@]}"; do
            [[ -f "$d/$id.png" ]] || { all=0; break; }
        done
        (( all )) && samples+=("$id")
        (( ${#samples[@]} >= 12 )) && break
    done < <(find "$BASE" -maxdepth 1 -name '*.png' -printf '%f\n' | sed 's/\.png$//' | sort -n)
    [[ ${#samples[@]} -gt 0 ]] || { echo "unknown (no samples)"; return; }

    local name
    for name in default 8x realistic clonewars; do
        d="${PACK_DIR[$name]}"
        local ok=1
        for id in "${samples[@]}"; do
            if ! cmp -s "$DEST/$id.png" "$d/$id.png"; then ok=0; break; fi
        done
        (( ok )) && { echo "$name"; return; }
    done
    echo "mixed/unknown"
}

if [[ "$PACK" == "list" ]]; then
    cur="$(detect_pack)"
    echo "Texture packs (current: $cur):"
    for name in default 8x realistic clonewars; do
        d="${PACK_DIR[$name]}"
        n=0; [[ -d "$d" ]] && n=$(find "$d" -maxdepth 1 -name '*.png' | wc -l)
        mark="  "; [[ "$name" == "$cur" ]] && mark="* "
        printf '  %s%-10s %4d textures  (%s)\n' "$mark" "$name" "$n" "${d#"$SRC"/}"
    done
    exit 0
fi

case "$PACK" in
    default|8x|realistic|clonewars) ;;
    *) echo "ERROR: unknown pack '$PACK' (use: default | 8x | realistic | clonewars | list)" >&2; exit 1 ;;
esac

[[ -f "$GAME_DIR/dinput.dll" || -d "$DEST" ]] || {
    echo "ERROR: the mod does not look installed in $GAME_DIR" >&2
    echo "       (no dinput.dll and no assets/replacement_textures). Run ./install.sh first." >&2
    exit 1
}

copy_dir() {
    local srcdir="$1" f rel
    [[ -d "$srcdir" ]] || { echo "ERROR: $srcdir not found" >&2; exit 1; }
    while IFS= read -r -d '' f; do
        rel="${f#"$srcdir"/}"
        mkdir -p "$(dirname "$DEST/$rel")"
        cp -f "$f" "$DEST/$rel"
    done < <(find "$srcdir" -type f -print0)
}

echo "Changing textures to '$PACK' in: $GAME_DIR"
mkdir -p "$DEST"

echo "  base:    default 4x pack"
copy_dir "$BASE"
if [[ "$PACK" != "default" ]]; then
    echo "  overlay: $PACK"
    copy_dir "${PACK_DIR[$PACK]}"
fi

n=$(find "$DEST" -maxdepth 1 -name '*.png' | wc -l)
echo "Done. $n textures in assets/replacement_textures/ (current: $(detect_pack))."
