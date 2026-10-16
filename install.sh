#!/usr/bin/env bash
# Install SWRacer Enhance Mod into the game directory.
#
# Every file that would be overwritten is first backed up under
#   <game>/.swracer_enhance_backup/
# together with a manifest recording which files were ADDED vs REPLACED, so
# uninstall.sh can remove the added files and restore the originals.
#
# Usage: ./install.sh [path-to-game-dir]
set -euo pipefail

usage() {
    echo "Usage: $0 [options] [path-to-game-dir]   (dir containing SWEP1RCR.EXE)" >&2
    echo "  --hd-8x          also install the optional 8x HD textures (higher VRAM; see" >&2
    echo "                   SWRacerEnhanceMod/optional/hd_8x/README.md)" >&2
    echo "  --ai-realistic   overlay the AI-regenerated textures on top (see" >&2
    echo "                   SWRacerEnhanceMod/optional/ai_textures/README.md)" >&2
    echo "  --ai-clonewars   overlay the AI 'Clone Wars' stylised textures instead" >&2
    echo "  --ui-hd          overlay the optional 2-4x HD menu/UI .TGAs on" >&2
    echo "                   data/images/ (see optional/ui_hd/README.md)" >&2
    echo "  --reshade        download ReShade (as opengl32.dll) + the SweetFX shaders and" >&2
    echo "                   drop in our SWRacer_Optimized.ini preset (needs curl + unzip;" >&2
    echo "                   ReShade is fetched, never bundled — see optional/reshade/README.md)" >&2
    exit 1
}

HD8X=0
AI_REALISTIC=0
AI_CLONEWARS=0
UI_HD=0
RESHADE=0
RESHADE_DLL=0
RXTMP=""
ARGS=()
for a in "$@"; do
    case "$a" in
        --hd-8x) HD8X=1 ;;
        --ai-realistic) AI_REALISTIC=1 ;;
        --ai-clonewars) AI_CLONEWARS=1 ;;
        --ui-hd) UI_HD=1 ;;
        --reshade) RESHADE=1 ;;
        -h|--help) usage ;;
        *) ARGS+=("$a") ;;
    esac
done

GAME_DIR="${ARGS[0]:-}"
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

BACKUP_DIR="$GAME_DIR/.swracer_enhance_backup"
MANIFEST="$BACKUP_DIR/manifest.tsv"
mkdir -p "$BACKUP_DIR"

# Load any previous manifest so a re-install keeps the ORIGINAL backups
# (and never backs up our own already-installed files).
declare -A PREV
if [[ -f "$MANIFEST" ]]; then
    while IFS=$'\t' read -r type rel; do
        [[ -n "${type:-}" ]] && PREV["$rel"]="$type"
    done < "$MANIFEST"
fi
# Files already handled earlier in THIS run (e.g. a 4x texture later overwritten
# by the optional 8x pass) must not be backed up or re-recorded.
declare -A DONE
MANIFEST_TMP="$(mktemp "$BACKUP_DIR/.manifest.XXXXXX")"
[[ -f "$MANIFEST" ]] && cat "$MANIFEST" > "$MANIFEST_TMP"

echo "Installing into: $GAME_DIR"

install_file() {
    local src="$1" dest="$2"
    local rel="${dest#"$GAME_DIR"/}"
    if [[ -z "${PREV[$rel]:-}" && -z "${DONE[$rel]:-}" ]]; then
        if [[ -e "$dest" ]]; then
            mkdir -p "$(dirname "$BACKUP_DIR/$rel")"
            cp -a "$dest" "$BACKUP_DIR/$rel"
            printf 'REPLACED\t%s\n' "$rel" >> "$MANIFEST_TMP"
            echo "  backup   $rel"
        else
            printf 'ADDED\t%s\n' "$rel" >> "$MANIFEST_TMP"
        fi
    fi
    mkdir -p "$(dirname "$dest")"
    cp -f "$src" "$dest"
    DONE["$rel"]=1
}

install_dir() {
    local srcdir="$1" destdir="$2" f rel
    while IFS= read -r -d '' f; do
        rel="${f#"$srcdir"/}"
        install_file "$f" "$destdir/$rel"
    done < <(find "$srcdir" -type f -print0)
}

# Detect the game's architecture (32-bit unless the PE is clearly 64-bit).
game_arch() {
    if command -v file >/dev/null 2>&1; then
        case "$(file -b "$1" 2>/dev/null)" in
            *x86-64*|*x86_64*|*"PE32+") echo 64; return ;;
        esac
    fi
    echo 32
}

# Download the official ReShade build, extract the OpenGL proxy DLL from the
# (self-extracting) setup executable, fetch the SweetFX + standard-effect shader
# packages, then drop in our preset and a ReShade.ini pointing at them. ReShade
# is fetched at install time, never bundled (per ReShade's redistribution policy).
install_reshade() {
    local preset="$SRC/optional/reshade/SWRacer_Optimized.ini"
    local preset_name
    preset_name="$(basename "$preset")"

    install_preset_only() {
        install_file "$preset" "$GAME_DIR/$preset_name"
    }

    [[ -f "$preset" ]] || { echo "WARNING: --reshade given but $preset not found; skipping." >&2; return 0; }
    if ! command -v curl >/dev/null 2>&1 || ! command -v unzip >/dev/null 2>&1; then
        echo "WARNING: --reshade needs 'curl' and 'unzip' on PATH to fetch ReShade." >&2
        echo "         Installing only the preset ($preset_name)." >&2
        install_preset_only
        return 0
    fi

    RXTMP="$(mktemp -d)"
    trap 'rm -rf "${RXTMP:-}"' EXIT

    local setup_name
    setup_name="$(curl -fsSL https://reshade.me 2>/dev/null \
        | grep -oE 'ReShade_Setup_[0-9.]+_Addon\.exe' | head -n1 || true)"
    if [[ -z "$setup_name" ]] \
       || ! curl -fsSL "https://reshade.me/downloads/$setup_name" -o "$RXTMP/$setup_name"; then
        echo "WARNING: could not fetch ReShade from reshade.me;" >&2
        echo "         installing only the preset ($preset_name). Get ReShade at https://reshade.me." >&2
        install_preset_only
        return 0
    fi
    echo "Fetching ReShade ($setup_name) ..."
    # The setup exe is a zip with a small SFX stub: unzip warns and exits 1 but
    # still extracts, so ignore its status and check for the file afterwards.
    unzip -qo "$RXTMP/$setup_name" 'ReShade32.dll' 'ReShade64.dll' -d "$RXTMP" 2>/dev/null || true

    local arch="$RXTMP/ReShade$(game_arch "$GAME_DIR/SWEP1RCR.EXE").dll"
    if [[ ! -f "$arch" ]]; then
        echo "WARNING: ReShade DLL not found inside $setup_name; installing only the preset." >&2
        install_preset_only
        return 0
    fi
    echo "Installing ReShade as opengl32.dll ..."
    install_file "$arch" "$GAME_DIR/opengl32.dll"
    RESHADE_DLL=1

    echo "Fetching SweetFX + standard-effect shaders ..."
    local sfx="$RXTMP/sweetfx/SweetFX-master"
    if curl -fsSL https://github.com/CeeJayDK/SweetFX/archive/master.zip -o "$RXTMP/sweetfx.zip" \
        && unzip -qo "$RXTMP/sweetfx.zip" -d "$RXTMP/sweetfx" 2>/dev/null \
        && [[ -d "$sfx/Shaders/SweetFX" ]]; then
        install_dir "$sfx/Shaders/SweetFX"  "$GAME_DIR/reshade-shaders/Shaders/SweetFX"
        install_dir "$sfx/Textures/SweetFX" "$GAME_DIR/reshade-shaders/Textures/SweetFX"
    else
        echo "WARNING: could not fetch the SweetFX shader package." >&2
    fi

    local std="$RXTMP/slim/reshade-shaders-slim"
    if curl -fsSL https://github.com/crosire/reshade-shaders/archive/slim.zip -o "$RXTMP/slim.zip" \
        && unzip -qo "$RXTMP/slim.zip" -d "$RXTMP/slim" 2>/dev/null \
        && [[ -d "$std/Shaders" ]]; then
        install_dir "$std/Shaders"  "$GAME_DIR/reshade-shaders/Shaders"
        install_dir "$std/Textures" "$GAME_DIR/reshade-shaders/Textures"
    else
        echo "WARNING: failed to fetch standard-effect shaders (ReShade.fxh etc.)." >&2
    fi

    # A fresh ReShade.ini pointing at our shaders + preset; leave the user's own alone.
    if [[ -e "$GAME_DIR/ReShade.ini" ]]; then
        echo "  note: existing ReShade.ini kept; select SWRacer_Optimized.ini in-game (Home key)."
    else
        cat > "$RXTMP/ReShade.ini" <<'INI'
[GENERAL]
EffectSearchPaths=.\reshade-shaders\Shaders\**
TextureSearchPaths=.\reshade-shaders\Textures\**
PresetPath=.\SWRacer_Optimized.ini
PerformanceMode=0
INI
        install_file "$RXTMP/ReShade.ini" "$GAME_DIR/ReShade.ini"
    fi

    install_preset_only
}

for f in dinput.dll dsound.dll dsoal-aldrv.dll alsoft.ini Smush.cfg \
         ATTRIBUTION.md README.md LICENSE; do
    install_file "$SRC/$f" "$GAME_DIR/$f"
done
install_dir "$SRC/LICENSES" "$GAME_DIR/LICENSES"
install_dir "$SRC/assets"   "$GAME_DIR/assets"
install_dir "$SRC/data"     "$GAME_DIR/data"

if (( HD8X )); then
    if [[ -d "$SRC/optional/hd_8x/replacement_textures" ]]; then
        echo "Applying optional 8x HD textures (overwrites the 4x pack) ..."
        install_dir "$SRC/optional/hd_8x/replacement_textures" \
                   "$GAME_DIR/assets/replacement_textures"
    else
        echo "WARNING: --hd-8x given but $SRC/optional/hd_8x not found; skipping." >&2
    fi
fi

# AI texture packs overlay on top of whatever is in assets/replacement_textures.
# They are mutually-exclusive styles; if both are given, Clone Wars wins.
for pack in realistic clonewars; do
    want=0
    [[ "$pack" == realistic && $AI_REALISTIC -eq 1 ]] && want=1
    [[ "$pack" == clonewars && $AI_CLONEWARS -eq 1 ]] && want=1
    (( want )) || continue
    if [[ -d "$SRC/optional/ai_textures/$pack/replacement_textures" ]]; then
        echo "Overlaying AI '$pack' textures ..."
        install_dir "$SRC/optional/ai_textures/$pack/replacement_textures" \
                   "$GAME_DIR/assets/replacement_textures"
    else
        echo "WARNING: --ai-$pack given but $SRC/optional/ai_textures/$pack not found; skipping." >&2
    fi
done

# Optional HD menu/UI TGAs overlay the game's data/images/ textures.
if (( UI_HD )); then
    if [[ -d "$SRC/optional/ui_hd" ]]; then
        echo "Overlaying optional HD menu/UI textures (data/images) ..."
        while IFS= read -r -d '' f; do
            install_file "$f" "$GAME_DIR/data/images/$(basename "$f")"
        done < <(find "$SRC/optional/ui_hd" -maxdepth 1 -type f -iname '*.tga' -print0)
    else
        echo "WARNING: --ui-hd given but $SRC/optional/ui_hd not found; skipping." >&2
    fi
fi

# Optional ReShade: fetch the build, add the SweetFX shaders and our preset.
if (( RESHADE )); then
    install_reshade
fi

mv -f "$MANIFEST_TMP" "$MANIFEST"

echo
echo "Done. Run the game (SWEP1RCR.EXE); press F5 for the mod menu."
echo "Backups + manifest: $BACKUP_DIR"
echo "To remove the mod and restore originals, run: ./uninstall.sh \"$GAME_DIR\""
echo "Optional extras (dgVoodoo/Xidi/UI HD TGAs + texture packs) are in: $SRC/optional/"
if (( RESHADE )); then
    echo
    if (( RESHADE_DLL )); then
        echo "ReShade + SWRacer_Optimized.ini installed. On Steam/Proton add opengl32 to the"
        echo "DLL override too:   WINEDLLOVERRIDES=\"dinput=n,b;opengl32=n,b\" %command%"
        echo "then press Home in-game and pick the preset."
    else
        echo "ReShade preset installed (SWRacer_Optimized.ini), but ReShade itself was NOT:"
        echo "install it as opengl32.dll, then pick the preset in-game (Home key). See"
        echo "  $SRC/optional/reshade/README.md"
    fi
fi
echo
echo "Linux / Steam Proton: the game ignores dinput.dll unless you add"
echo "    WINEDLLOVERRIDES=\"dinput=n,b\"   (optionally also  ;dsound=n,b  for DSOAL audio)"
echo "to the game's Steam Launch Options, before %command%. If pressing F5 does nothing"
echo "and there is no hook.log in the game folder, this is why. See docs/LINUX_PROTON.md."
