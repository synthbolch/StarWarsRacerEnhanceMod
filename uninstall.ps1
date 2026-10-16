# Uninstall SWRacer Enhance Mod (Windows): remove added files and restore the
# originals overwritten at install time, using the manifest from install.ps1.
# Invoked by uninstall.bat.
#
# Usage: powershell -ExecutionPolicy Bypass -File uninstall.ps1 -GameDir "C:\...\Racer"
[CmdletBinding()]
param(
    [Parameter(Position = 0)]
    [string]$GameDir
)

$ErrorActionPreference = 'Stop'

if (-not $GameDir) {
    Write-Host 'Usage: uninstall.bat "C:\Program Files (x86)\Steam\steamapps\common\Star Wars Episode I Racer"'
    exit 1
}
if (-not (Test-Path -LiteralPath $GameDir -PathType Container)) {
    Write-Host "ERROR: game directory not found: $GameDir"
    exit 1
}
$GameDir = (Resolve-Path -LiteralPath $GameDir).Path

$Backup   = Join-Path $GameDir '.swracer_enhance_backup'
$Manifest = Join-Path $Backup 'manifest.tsv'
if (-not (Test-Path -LiteralPath $Manifest)) {
    Write-Host "ERROR: no manifest at $Manifest"
    Write-Host 'This mod was not installed by install.ps1 (or the backup was removed).'
    exit 1
}

Write-Host "Uninstalling from: $GameDir"
$dirs = @{}
$removed = 0
$restored = 0

foreach ($line in Get-Content -LiteralPath $Manifest) {
    if (-not $line) { continue }
    $p = $line -split "`t", 2
    if ($p.Count -ne 2) { continue }
    $type = $p[0]
    $rel  = $p[1]
    $dest = Join-Path $GameDir $rel

    switch ($type) {
        'ADDED' {
            if (Test-Path -LiteralPath $dest) {
                Remove-Item -LiteralPath $dest -Force
                Write-Host "  removed   $rel"
                $removed++
            }
        }
        'REPLACED' {
            $b = Join-Path $Backup $rel
            if (Test-Path -LiteralPath $b) {
                New-Item -ItemType Directory -Force -Path (Split-Path -Parent $dest) | Out-Null
                Copy-Item -LiteralPath $b -Destination $dest -Force
                Write-Host "  restored  $rel"
                $restored++
            }
        }
    }

    $d = Split-Path $rel -Parent
    while ($d -and $d -ne '.' -and $d -ne '\' -and $d -ne '/') {
        $dirs[$d] = $true
        $d = Split-Path $d -Parent
    }
}

# Remove directories that are now empty, deepest first. Non-empty dirs that
# held pre-existing game files are left untouched.
$dirs.Keys | Sort-Object { ($_ -split '[\\/]').Count } -Descending | ForEach-Object {
    $full = Join-Path $GameDir $_
    if ((Test-Path -LiteralPath $full) -and -not (Get-ChildItem -LiteralPath $full -Force)) {
        Remove-Item -LiteralPath $full -Force
    }
}

Remove-Item -LiteralPath $Backup -Recurse -Force

Write-Host ''
Write-Host "Done. Removed $removed file(s), restored $restored original(s)."
Write-Host 'If a launcher still lists the game, verify files (Steam) to reset any remaining edits.'
