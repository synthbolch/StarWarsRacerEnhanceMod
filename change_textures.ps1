# Change the texture pack of an ALREADY-INSTALLED SWRacer Enhance Mod.
# See change_textures.sh for details. Called by change_textures.bat.
param(
    [Parameter(Position = 0)]
    [string]$Pack,
    [Parameter(Position = 1)]
    [string]$GameDir
)

$ErrorActionPreference = 'Stop'

if (-not $Pack -or @('default', '8x', 'realistic', 'clonewars', 'list') -notcontains $Pack) {
    Write-Host 'Usage: change_textures.bat <pack> "C:\...\Star Wars Episode I Racer"'
    Write-Host '  pack: default | 8x | realistic | clonewars | list'
    exit 1
}

if (-not $GameDir) {
    $candidates = @(
        (Join-Path $env:USERPROFILE 'Games\Star Wars Episode I Racer'),
        'C:\Program Files (x86)\Steam\steamapps\common\Star Wars Episode I Racer',
        'C:\Program Files\Steam\steamapps\common\Star Wars Episode I Racer'
    )
    foreach ($d in $candidates) {
        if (Test-Path (Join-Path $d 'SWEP1RCR.EXE')) { $GameDir = $d; break }
    }
}
if (-not $GameDir -or -not (Test-Path (Join-Path $GameDir 'SWEP1RCR.EXE'))) {
    Write-Host 'ERROR: game dir not given and none auto-detected (need SWEP1RCR.EXE)'
    exit 1
}
$GameDir = (Resolve-Path $GameDir).Path

$Src  = Join-Path $PSScriptRoot 'SWRacerEnhanceMod'
$Base = Join-Path $Src 'assets\replacement_textures'
$Dest = Join-Path $GameDir 'assets\replacement_textures'
if (-not (Test-Path $Base)) { Write-Host "ERROR: $Base not found (incomplete bundle)"; exit 1 }

$PackDir = @{
    'default'   = $Base
    '8x'        = Join-Path $Src 'optional\hd_8x\replacement_textures'
    'realistic' = Join-Path $Src 'optional\ai_textures\realistic\replacement_textures'
    'clonewars' = Join-Path $Src 'optional\ai_textures\clonewars\replacement_textures'
}

function Get-CurrentPack {
    if (-not (Test-Path $Dest)) { return 'not installed' }
    $samples = @()
    foreach ($f in (Get-ChildItem -LiteralPath $Base -Filter *.png | Sort-Object { [int]($_.BaseName) })) {
        $id = $f.BaseName
        $all = $true
        foreach ($d in $PackDir.Values) { if (-not (Test-Path (Join-Path $d "$id.png"))) { $all = $false; break } }
        if ($all) { $samples += $id }
        if ($samples.Count -ge 12) { break }
    }
    if ($samples.Count -eq 0) { return 'unknown' }
    foreach ($name in 'default', '8x', 'realistic', 'clonewars') {
        $d = $PackDir[$name]
        $ok = $true
        foreach ($id in $samples) {
            $h1 = (Get-FileHash -Algorithm MD5 -LiteralPath (Join-Path $Dest "$id.png")).Hash
            $h2 = (Get-FileHash -Algorithm MD5 -LiteralPath (Join-Path $d "$id.png")).Hash
            if ($h1 -ne $h2) { $ok = $false; break }
        }
        if ($ok) { return $name }
    }
    return 'mixed/unknown'
}

if ($Pack -eq 'list') {
    $cur = Get-CurrentPack
    Write-Host "Texture packs (current: $cur):"
    foreach ($name in 'default', '8x', 'realistic', 'clonewars') {
        $d = $PackDir[$name]
        $n = 0
        if (Test-Path $d) { $n = (Get-ChildItem -LiteralPath $d -Filter *.png).Count }
        $rel = $d.Substring($Src.Length).TrimStart('\')
        $mark = if ($name -eq $cur) { '* ' } else { '  ' }
        Write-Host ("{0}{1,-10} {2,4} textures  ({3})" -f $mark, $name, $n, $rel)
    }
    exit 0
}

if (-not (Test-Path (Join-Path $GameDir 'dinput.dll')) -and -not (Test-Path $Dest)) {
    Write-Host "ERROR: the mod does not look installed in $GameDir"
    Write-Host '       (no dinput.dll and no assets/replacement_textures). Run install.bat first.'
    exit 1
}

function Copy-Pack($srcdir) {
    if (-not (Test-Path $srcdir)) { Write-Host "ERROR: $srcdir not found"; exit 1 }
    Get-ChildItem -LiteralPath $srcdir -File -Recurse | ForEach-Object {
        $rel = $_.FullName.Substring($srcdir.Length).TrimStart('\')
        $target = Join-Path $Dest $rel
        New-Item -ItemType Directory -Force -Path (Split-Path -Parent $target) | Out-Null
        Copy-Item -LiteralPath $_.FullName -Destination $target -Force
    }
}

Write-Host "Changing textures to '$Pack' in: $GameDir"
New-Item -ItemType Directory -Force -Path $Dest | Out-Null
Write-Host '  base:    default 4x pack'
Copy-Pack $Base
if ($Pack -ne 'default') {
    Write-Host "  overlay: $Pack"
    Copy-Pack $PackDir[$Pack]
}
$n = (Get-ChildItem -LiteralPath $Dest -Filter *.png).Count
Write-Host "Done. $n textures in assets/replacement_textures/ (current: $(Get-CurrentPack))."
