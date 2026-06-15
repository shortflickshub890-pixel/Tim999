param(
    [string]$Root = (Split-Path $PSScriptRoot -Parent)
)

$ErrorActionPreference = 'Stop'
Write-Host ""
Write-Host "MOVIE FACTORY PIPELINE"
Write-Host "Root: $Root"

Write-Host "Checking folders..."

$folders = @('ideas','scripts','voice','assets','publish')

$missing = @()
foreach ($f in $folders) {
    $p = Join-Path $Root $f
    if (Test-Path $p) { Write-Host "[OK] $f -> $p" } else { Write-Host "[MISSING] $f -> $p"; $missing += $f }
}

if ($missing.Count -eq 0) { Write-Host "PIPELINE READY" } else { Write-Warning "Missing folders: $($missing -join ', ')" }