# Install SWRacer Enhance Mod into the game directory (Windows).
#
# Every file that would be overwritten is backed up under
#   <game>\.swracer_enhance_backup\
# together with a manifest so uninstall.ps1 can remove added files and restore
# the originals. Invoked by install.bat.
#
# Usage: powershell -ExecutionPolicy Bypass -File install.ps1 -GameDir "C:\...\Racer"
[CmdletBinding()]
param(
    [Parameter(Position = 0)]
    [string]$GameDir,
    [switch]$Hd8x,
    [switch]$AiRealistic,
    [switch]$AiClonewars,
    [switch]$UiHd,
    [switch]$Reshade
)

$ErrorActionPreference = 'Stop'

Add-Type -AssemblyName System.IO.Compression.FileSystem -ErrorAction SilentlyContinue

# Detect the target exe's architecture (32-bit unless the PE is 64-bit).
function Get-PeArch([string]$exe) {
    try {
        $fs = [System.IO.File]::OpenRead($exe)
        try {
            $br = New-Object System.IO.BinaryReader($fs)
            $fs.Position = 0x3C
            $peOff = $br.ReadInt32()
            $fs.Position = $peOff + 4
            $machine = $br.ReadUInt16()
        }
        finally { $fs.Dispose() }
        if ($machine -eq 0x8664) { return 64 } else { return 32 }
    }
    catch { return 32 }
}

# Extract a zip archive. The ReShade setup exe is a zip with an SFX stub, so
# prefer tar (libarchive tolerates the prepended data), then fall back to .NET.
function Expand-Zip([string]$zip, [string]$dest) {
    $tar = Get-Command tar -ErrorAction SilentlyContinue
    if ($tar) {
        if (Test-Path -LiteralPath $dest) { Remove-Item -Recurse -Force -LiteralPath $dest }
        New-Item -ItemType Directory -Force -Path $dest | Out-Null
        & $tar.Source -xf $zip -C $dest 2>$null
        if ($LASTEXITCODE -eq 0) { return }
    }
    if (Test-Path -LiteralPath $dest) { Remove-Item -Recurse -Force -LiteralPath $dest }
    [System.IO.Compression.ZipFile]::ExtractToDirectory($zip, $dest)
}

# Queue every file under a folder for installation to a destination folder.
function Add-Tree([string]$root, [string]$destRoot) {
    Get-ChildItem -LiteralPath $root -Recurse -File | ForEach-Object {
        $rel = $_.FullName.Substring($root.Length).TrimStart('\', '/')
        $files.Add([pscustomobject]@{ Src = $_.FullName; Dest = (Join-Path $destRoot $rel) })
    }
}

if (-not $GameDir) {
    Write-Host 'Usage: install.bat [--hd-8x] [--ai-realistic | --ai-clonewars] [--ui-hd] [--reshade] "C:\Program Files (x86)\Steam\steamapps\common\Star Wars Episode I Racer"'
    exit 1
}
if (-not (Test-Path -LiteralPath $GameDir -PathType Container)) {
    Write-Host "ERROR: game directory not found: $GameDir"
    exit 1
}
$GameDir = (Resolve-Path -LiteralPath $GameDir).Path
if (-not (Test-Path -LiteralPath (Join-Path $GameDir 'SWEP1RCR.EXE'))) {
    Write-Host "ERROR: SWEP1RCR.EXE not found in $GameDir"
    exit 1
}

$Src = Join-Path $PSScriptRoot 'SWRacerEnhanceMod'
if (-not (Test-Path -LiteralPath $Src)) {
    Write-Host "ERROR: $Src not found"
    exit 1
}

$Backup   = Join-Path $GameDir '.swracer_enhance_backup'
$Manifest = Join-Path $Backup 'manifest.tsv'
New-Item -ItemType Directory -Force -Path $Backup | Out-Null

# Load any previous manifest so a re-install keeps the ORIGINAL backups and
# never backs up our own already-installed files.
$prev = @{}
$entries = New-Object System.Collections.Generic.List[string]
if (Test-Path -LiteralPath $Manifest) {
    foreach ($line in Get-Content -LiteralPath $Manifest) {
        if (-not $line) { continue }
        $entries.Add($line)
        $p = $line -split "`t", 2
        if ($p.Count -eq 2) { $prev[$p[1]] = $p[0] }
    }
}

Write-Host "Installing into: $GameDir"

# Build the list of source -> destination files.
$files = New-Object System.Collections.Generic.List[object]
$topLevel = 'dinput.dll', 'dsound.dll', 'dsoal-aldrv.dll', 'alsoft.ini',
            'Smush.cfg', 'LICENSE', 'ATTRIBUTION.md', 'README.md'
foreach ($f in $topLevel) {
    $files.Add([pscustomobject]@{ Src = (Join-Path $Src $f); Dest = (Join-Path $GameDir $f) })
}
foreach ($d in 'LICENSES', 'assets', 'data') {
    $root = Join-Path $Src $d
    Get-ChildItem -LiteralPath $root -Recurse -File | ForEach-Object {
        $rel = $_.FullName.Substring($root.Length) -replace '^[\\/]+', ''
        $files.Add([pscustomobject]@{ Src = $_.FullName; Dest = (Join-Path (Join-Path $GameDir $d) $rel) })
    }
}

# Optional 8x textures overwrite the 4x replacements; add them after so they win.
if ($Hd8x) {
    $hd8 = Join-Path $Src 'optional\hd_8x\replacement_textures'
    if (Test-Path -LiteralPath $hd8) {
        $destRoot = Join-Path $GameDir 'assets\replacement_textures'
        Get-ChildItem -LiteralPath $hd8 -Recurse -File | ForEach-Object {
            $rel = $_.Name
            $files.Add([pscustomobject]@{ Src = $_.FullName; Dest = (Join-Path $destRoot $rel) })
        }
    }
    else {
        Write-Host "WARNING: -Hd8x given but $hd8 not found; skipping."
    }
}

# AI texture packs overlay on top of assets/replacement_textures (mutually
# exclusive styles; if both are given, Clone Wars wins as it is added last).
foreach ($pack in 'realistic', 'clonewars') {
    $want = ($pack -eq 'realistic' -and $AiRealistic) -or ($pack -eq 'clonewars' -and $AiClonewars)
    if (-not $want) { continue }
    $aiDir = Join-Path $Src "optional\ai_textures\$pack\replacement_textures"
    if (Test-Path -LiteralPath $aiDir) {
        $destRoot = Join-Path $GameDir 'assets\replacement_textures'
        Get-ChildItem -LiteralPath $aiDir -Recurse -File | ForEach-Object {
            $files.Add([pscustomobject]@{ Src = $_.FullName; Dest = (Join-Path $destRoot $_.Name) })
        }
    }
    else {
        Write-Host "WARNING: AI '$pack' pack requested but $aiDir not found; skipping."
    }
}

# Optional HD menu/UI TGAs overlay the game's data\images\ textures.
if ($UiHd) {
    $uiDir = Join-Path $Src 'optional\ui_hd'
    if (Test-Path -LiteralPath $uiDir) {
        $destRoot = Join-Path $GameDir 'data\images'
        Get-ChildItem -LiteralPath $uiDir -File | Where-Object { $_.Extension -in '.TGA', '.tga' } | ForEach-Object {
            $files.Add([pscustomobject]@{ Src = $_.FullName; Dest = (Join-Path $destRoot $_.Name) })
        }
    }
    else {
        Write-Host "WARNING: -UiHd given but $uiDir not found; skipping."
    }
}

# Optional ReShade: download the official build, extract the OpenGL proxy DLL,
# fetch the SweetFX + standard-effect shaders, and drop in our preset and a
# ReShade.ini. ReShade is fetched at install time, never bundled.
$reshadeTmp = $null
$gotReshadeDll = $false
if ($Reshade) {
    $preset = Join-Path $Src 'optional\reshade\SWRacer_Optimized.ini'
    if (-not (Test-Path -LiteralPath $preset)) {
        Write-Host "WARNING: -Reshade given but SWRacer_Optimized.ini not found; skipping."
    }
    else {
        $reshadeTmp = Join-Path ([System.IO.Path]::GetTempPath()) ("swracer_reshade_" + [guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Force -Path $reshadeTmp | Out-Null

        try {
            $html = (Invoke-WebRequest -UseBasicParsing 'https://reshade.me' -ErrorAction Stop).Content
            $m = [regex]::Match($html, 'ReShade_Setup_[0-9.]+_Addon\.exe')
            if (-not $m.Success) { throw 'no download link on reshade.me' }
            $setupName = $m.Value
            $setupPath = Join-Path $reshadeTmp $setupName
            Write-Host "Fetching ReShade ($setupName) ..."
            Invoke-WebRequest -UseBasicParsing "https://reshade.me/downloads/$setupName" -OutFile $setupPath -ErrorAction Stop
            $arch = Get-PeArch (Join-Path $GameDir 'SWEP1RCR.EXE')
            $rxDir = Join-Path $reshadeTmp 'reshade'
            Expand-Zip $setupPath $rxDir
            $dll = Join-Path $rxDir "ReShade$arch.dll"
            if (-not (Test-Path -LiteralPath $dll)) { throw "ReShade$arch.dll missing in $setupName" }
            Write-Host 'Installing ReShade as opengl32.dll ...'
            $files.Add([pscustomobject]@{ Src = $dll; Dest = (Join-Path $GameDir 'opengl32.dll') })
            $gotReshadeDll = $true
        }
        catch {
            Write-Host "WARNING: could not fetch/expand ReShade ($($_.Exception.Message)); installing only the preset."
        }

        Write-Host 'Fetching SweetFX + standard-effect shaders ...'
        try {
            $sfxZip = Join-Path $reshadeTmp 'sweetfx.zip'
            Invoke-WebRequest -UseBasicParsing 'https://github.com/CeeJayDK/SweetFX/archive/master.zip' -OutFile $sfxZip -ErrorAction Stop
            $sfxBase = Join-Path (Join-Path $reshadeTmp 'sweetfx') 'SweetFX-master'
            Expand-Zip $sfxZip (Join-Path $reshadeTmp 'sweetfx')
            Add-Tree (Join-Path $sfxBase 'Shaders\SweetFX')  (Join-Path $GameDir 'reshade-shaders\Shaders\SweetFX')
            Add-Tree (Join-Path $sfxBase 'Textures\SweetFX') (Join-Path $GameDir 'reshade-shaders\Textures\SweetFX')
        }
        catch { Write-Host "WARNING: could not fetch the SweetFX shader package ($($_.Exception.Message))." }

        try {
            $slimZip = Join-Path $reshadeTmp 'slim.zip'
            Invoke-WebRequest -UseBasicParsing 'https://github.com/crosire/reshade-shaders/archive/slim.zip' -OutFile $slimZip -ErrorAction Stop
            $slimRoot = Join-Path $reshadeTmp 'slim'
            Expand-Zip $slimZip $slimRoot
            $slimBase = Join-Path $slimRoot 'reshade-shaders-slim'
            Add-Tree (Join-Path $slimBase 'Shaders')  (Join-Path $GameDir 'reshade-shaders\Shaders')
            Add-Tree (Join-Path $slimBase 'Textures') (Join-Path $GameDir 'reshade-shaders\Textures')
        }
        catch {
            Write-Host "WARNING: failed to fetch standard-effect shaders ($($_.Exception.Message))."
        }

        if (Test-Path -LiteralPath (Join-Path $GameDir 'ReShade.ini')) {
            Write-Host '  note: existing ReShade.ini kept; select SWRacer_Optimized.ini in-game (Home key).'
        }
        else {
            $iniSrc = Join-Path $reshadeTmp 'ReShade.ini'
            @(
                '[GENERAL]',
                'EffectSearchPaths=.\reshade-shaders\Shaders\**',
                'TextureSearchPaths=.\reshade-shaders\Textures\**',
                'PresetPath=.\SWRacer_Optimized.ini',
                'PerformanceMode=0'
            ) | Set-Content -LiteralPath $iniSrc -Encoding ASCII
            $files.Add([pscustomobject]@{ Src = $iniSrc; Dest = (Join-Path $GameDir 'ReShade.ini') })
        }
        $files.Add([pscustomobject]@{ Src = $preset; Dest = (Join-Path $GameDir 'SWRacer_Optimized.ini') })
    }
}

$done = @{}
foreach ($item in $files) {
    $rel = $item.Dest.Substring($GameDir.Length) -replace '^[\\/]+', ''
    if ((-not $prev.ContainsKey($rel)) -and (-not $done.ContainsKey($rel))) {
        if (Test-Path -LiteralPath $item.Dest) {
            $bpath = Join-Path $Backup $rel
            New-Item -ItemType Directory -Force -Path (Split-Path -Parent $bpath) | Out-Null
            Copy-Item -LiteralPath $item.Dest -Destination $bpath -Force
            $entries.Add("REPLACED`t$rel")
            Write-Host "  backup   $rel"
        }
        else {
            $entries.Add("ADDED`t$rel")
        }
    }
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $item.Dest) | Out-Null
    Copy-Item -LiteralPath $item.Src -Destination $item.Dest -Force
    $done[$rel] = $true
}

# The ReShade download is staged in a temp folder that must outlive the copy
# loop (the queued files are read from it), so drop it only now.
if ($reshadeTmp -and (Test-Path -LiteralPath $reshadeTmp)) {
    Remove-Item -Recurse -Force -LiteralPath $reshadeTmp -ErrorAction SilentlyContinue
}

Set-Content -LiteralPath $Manifest -Value $entries -Encoding ASCII

Write-Host ''
Write-Host 'Done. Run the game (SWEP1RCR.EXE); press F5 for the mod menu.'
Write-Host "Backups + manifest: $Backup"
Write-Host "To remove the mod and restore originals, run: uninstall.bat `"$GameDir`""
Write-Host "Optional extras are in: $Src\optional\"
if ($Reshade) {
    Write-Host ''
    if ($gotReshadeDll) {
        Write-Host 'ReShade + SWRacer_Optimized.ini installed. On Steam/Proton add opengl32 to the'
        Write-Host 'DLL override too:   WINEDLLOVERRIDES="dinput=n,b;opengl32=n,b" %command%'
        Write-Host 'then press Home in-game and pick the preset.'
    }
    else {
        Write-Host 'ReShade preset installed (SWRacer_Optimized.ini). ReShade itself is NOT bundled:'
        Write-Host "install it as opengl32.dll, then pick the preset in-game (Home key). See $Src\optional\reshade\README.md"
    }
}
