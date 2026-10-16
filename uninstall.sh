#!/usr/bin/env bash
# Uninstall SWRacer Enhance Mod: remove the files it added and restore any
# original game files it overwrote, using the manifest written by install.sh.
#
# Usage: ./uninstall.sh [path-to-game-dir]
set -euo pipefail

usage() {
    echo "Usage: $0 [path-to-game-dir]   (dir containing SWEP1RCR.EXE)" >&2
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
[[ -n "$GAME_DIR" && -d "$GAME_DIR" ]] || usage
GAME_DIR="$(cd "$GAME_DIR" && pwd)"

BACKUP_DIR="$GAME_DIR/.swracer_enhance_backup"
MANIFEST="$BACKUP_DIR/manifest.tsv"

if [[ ! -f "$MANIFEST" ]]; then
    echo "ERROR: no manifest at $MANIFEST" >&2
    echo "This mod was not installed by install.sh (or the backup was removed)." >&2
    exit 1
fi

echo "Uninstalling from: $GAME_DIR"

declare -A DIRS
removed=0
restored=0
while IFS=$'\t' read -r type rel; do
    [[ -n "${type:-}" ]] || continue
    dest="$GAME_DIR/$rel"
    case "$type" in
        ADDED)
            if [[ -e "$dest" ]]; then rm -f "$dest"; echo "  removed   $rel"; removed=$((removed + 1)); fi
            ;;
        REPLACED)
            if [[ -e "$BACKUP_DIR/$rel" ]]; then
                mkdir -p "$(dirname "$dest")"
                cp -a "$BACKUP_DIR/$rel" "$dest"
                echo "  restored  $rel"
                restored=$((restored + 1))
            fi
            ;;
    esac
    d="$(dirname "$rel")"
    while [[ "$d" != "." && "$d" != "/" ]]; do DIRS["$d"]=1; d="$(dirname "$d")"; done
done < "$MANIFEST"

# Remove directories that are now empty (deepest first). Non-empty dirs that
# held pre-existing game files are left untouched.
if (( ${#DIRS[@]} )); then
    while IFS= read -r d; do
        rmdir "$GAME_DIR/$d" 2>/dev/null || true
    done < <(printf '%s\n' "${!DIRS[@]}" | awk -F/ '{print NF"\t"$0}' | sort -rn | cut -f2-)
fi

rm -rf "$BACKUP_DIR"

echo
echo "Done. Removed $removed file(s), restored $restored original(s)."
echo "If a launcher still lists the game, verify files (Steam) to reset any remaining edits."
