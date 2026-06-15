param(
	[string]$Source = ".\output",
	[string]$Dest = ".\publish",
	[switch]$Move
)

$ErrorActionPreference = 'Stop'

$Source = [System.IO.Path]::GetFullPath($Source)
$Dest = [System.IO.Path]::GetFullPath($Dest)

if (-not (Test-Path $Source)) { Write-Error "Source not found: $Source"; exit 1 }
New-Item -ItemType Directory -Path $Dest -Force | Out-Null

$files = Get-ChildItem -Path $Source -File -Include *.mp4,*.mov,*.mp3 -ErrorAction SilentlyContinue
if ($files.Count -eq 0) { Write-Host "No render files found in $Source"; exit 0 }

foreach ($f in $files) {
	$target = Join-Path $Dest $f.Name
	if ($Move) { Move-Item -Force $f.FullName $target } else { Copy-Item -Force $f.FullName $target }
	Write-Host "Published: $($f.Name) -> $target"
}

Write-Host "Publish complete. Destination: $Dest"
