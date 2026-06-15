param(
	[string]$Root = (Split-Path $PSScriptRoot -Parent)
)

Write-Host ""
Write-Host "MOVIE FACTORY"
Write-Host "Root: $Root"

if (-not (Test-Path (Join-Path $Root 'ideas'))) { Write-Warning "No ideas folder: $Root\ideas"; exit 0 }

Get-ChildItem -Path (Join-Path $Root 'ideas') -File | ForEach-Object { Write-Host " - $($_.Name)" }

Write-Host ""
Write-Host "IDEAS READY"