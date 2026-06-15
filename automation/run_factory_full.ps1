param(
    [string]$CaptionsFile = "assets/images/captions/001_storyboard.txt",
    [string]$ImagesDir = "assets/images/001_interstellar",
    [string]$OutDir = "output",
    [string]$PublishDir = "publish",
    [string]$Voice = "en-US-GuyNeural",
    [switch]$Clean,
    [switch]$SkipPublish
)

$ErrorActionPreference = 'Stop'

$root = Split-Path $PSScriptRoot -Parent

$CaptionsFile = [System.IO.Path]::GetFullPath((Join-Path $root $CaptionsFile))
$ImagesDir = [System.IO.Path]::GetFullPath((Join-Path $root $ImagesDir))
$OutDir = [System.IO.Path]::GetFullPath((Join-Path $root $OutDir))
$PublishDir = [System.IO.Path]::GetFullPath((Join-Path $root $PublishDir))

Write-Host ""
Write-Host "=== AI MOVIE FACTORY - FULL AUTOMATION ==="
Write-Host "Captions: $CaptionsFile"
Write-Host "Images:   $ImagesDir"
Write-Host "Output:   $OutDir"
Write-Host "Publish:  $PublishDir"
Write-Host "Voice:    $Voice"
Write-Host ""

if (-not (Test-Path $CaptionsFile)) {
    Write-Error "Captions file not found: $CaptionsFile"
    exit 1
}

if (-not (Test-Path $ImagesDir)) {
    Write-Error "Images directory not found: $ImagesDir"
    exit 1
}

New-Item -ItemType Directory -Path $OutDir -Force | Out-Null
New-Item -ItemType Directory -Path $PublishDir -Force | Out-Null

$factoryScript = Join-Path $root 'factory\run_factory.ps1'
$publishScript = Join-Path $PSScriptRoot 'publish.ps1'

Write-Host "Starting video generation..."
& pwsh -NoProfile -ExecutionPolicy Bypass -File $factoryScript -CaptionsFile $CaptionsFile -ImagesDir $ImagesDir -OutDir $OutDir -Voice $Voice

if (-not $SkipPublish) {
    Write-Host "Publishing generated videos..."
    & pwsh -NoProfile -ExecutionPolicy Bypass -File $publishScript -Source $OutDir -Dest $PublishDir -Move
} else {
    Write-Host "SkipPublish enabled, leaving files in $OutDir"
}

if ($Clean -and -not $SkipPublish) {
    Write-Host "Cleaning temporary output folder..."
    Remove-Item -Recurse -Force $OutDir
}

Write-Host ""
Write-Host "=== COMPLETE ==="
Write-Host "Published files can be found in: $PublishDir"
if ($Clean -and -not $SkipPublish) { Write-Host "Temporary output folder removed." }
