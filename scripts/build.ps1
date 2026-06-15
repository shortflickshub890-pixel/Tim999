param(
	[string]$Image = ".\assets\images\001_interstellar\bg_001.jpg",
	[string]$Voice = ".\renders\voice.mp3",
	[string]$Out = ".\renders\final_factory.mp4",
	[int]$Width = 1080,
	[int]$Height = 1920
)

$ErrorActionPreference = 'Stop'

$Image = [System.IO.Path]::GetFullPath($Image)
$Voice = [System.IO.Path]::GetFullPath($Voice)
$Out = [System.IO.Path]::GetFullPath($Out)

if (-not (Test-Path $Image)) { Write-Error "Image not found: $Image"; exit 1 }
if (-not (Test-Path $Voice)) { Write-Error "Voice file not found: $Voice"; exit 1 }

New-Item -ItemType Directory -Path (Split-Path $Out) -Force | Out-Null

$vf = "scale=${Width}:${Height}:force_original_aspect_ratio=increase,crop=${Width}:${Height},format=yuv420p,drawbox=x=0:y=0:w=iw:h=ih:color=black@0.25:t=fill"
$args = @('-y','-loop','1','-framerate','25','-i',$Image,'-i',$Voice,'-vf',$vf,'-c:v','libx264','-pix_fmt','yuv420p','-c:a','aac','-b:a','192k','-shortest',$Out)

Write-Host "Rendering video -> $Out"
try { & ffmpeg @args } catch { Write-Error "ffmpeg failed: $_"; exit 1 }

Write-Host "Video rendered: $Out"