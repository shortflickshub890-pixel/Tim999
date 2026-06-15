param(
    [string]$SourceVideo = ".\assets\video\movie.mp4",
    [string]$SceneTimingsFile = "",
    [string]$CaptionsFile = "",
    [string]$MusicFile = "",
    [string]$MusicDir = ".\assets\music",
    [string]$OutputDir = ".\output",
    [string]$OutputName = "montage.mp4",
    [int]$Width = 1080,
    [int]$Height = 1920,
    [int]$MaxScenes = 4,
    [int]$MaxClipSeconds = 12,
    [int]$MinTotalSeconds = 30,
    [int]$MaxTotalSeconds = 45,
    [int]$FadeDuration = 0.6
)

$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$OutputDir = [System.IO.Path]::GetFullPath((Join-Path $root $OutputDir))
$SourceVideo = [System.IO.Path]::GetFullPath((Join-Path $root $SourceVideo))
$MusicDir = [System.IO.Path]::GetFullPath((Join-Path $root $MusicDir))
if ($MusicFile) { $MusicFile = [System.IO.Path]::GetFullPath((Join-Path $root $MusicFile)) }
if ($CaptionsFile) { $CaptionsFile = [System.IO.Path]::GetFullPath((Join-Path $root $CaptionsFile)) }
if ($SceneTimingsFile) { $SceneTimingsFile = [System.IO.Path]::GetFullPath((Join-Path $root $SceneTimingsFile)) }

function Get-VideoDuration {
    param([string]$Path)
    $output = & ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 $Path 2>&1
    if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($output)) {
        throw "ffprobe failed or returned invalid duration for $Path"
    }
    return [math]::Round([double]$output, 2)
}

function Get-VideoHasAudio {
    param([string]$Path)
    $output = & ffprobe -v error -select_streams a -show_entries stream=codec_type -of csv=p=0 $Path 2>$null
    return -not [string]::IsNullOrWhiteSpace($output)
}

function Parse-Timecode {
    param([string]$Value)
    $trimmed = $Value.Trim()
    if ($trimmed -match '^(?<h>\d{1,2}):(?<m>\d{1,2}):(?<s>\d{1,2}(?:\.\d+)?)$') {
        return ([int]$matches.h * 3600) + ([int]$matches.m * 60) + [double]$matches.s
    }
    if ($trimmed -match '^(?<m>\d{1,2}):(?<s>\d{1,2}(?:\.\d+)?)$') {
        return ([int]$matches.m * 60) + [double]$matches.s
    }
    if ($trimmed -match '^(?<s>\d+(?:\.\d+)?)$') {
        return [double]$matches.s
    }
    throw "Unable to parse timecode: $Value"
}

function Escape-FfmpegDrawText {
    param([string]$Text)
    $escaped = $Text -replace '\\', '\\\\'
    $escaped = $escaped -replace "'", "\\'"
    $escaped = $escaped -replace ':', '\\:'
    $escaped = $escaped -replace ',', '\\,'
    $escaped = $escaped -replace '%', '%%'
    $escaped = $escaped -replace '\n', '\\n'
    return $escaped
}

function Parse-SceneLines {
    param([string[]]$Lines)

    $scenes = @()
    foreach ($line in $Lines) {
        $raw = $line.Trim()
        if ([string]::IsNullOrWhiteSpace($raw)) { continue }
        if ($raw -match '^(?<start>[^\|\s]+)\s*-\s*(?<end>[^\|\s]+)(?:\|(?<caption>.*))?$') {
            try {
                $start = Parse-Timecode $matches.start
                $end = Parse-Timecode $matches.end
            } catch {
                continue
            }
            if ($end -gt $start) {
                $caption = if ($matches.caption) { $matches.caption.Trim() } else { "Scene clip" }
                $scenes += [PSCustomObject]@{ Start = $start; End = $end; Duration = $end - $start; Caption = $caption }
            }
        }
    }
    return $scenes | Sort-Object Start
}

function Build-SceneList {
    param()
    $scenes = @()
    if ($SceneTimingsFile -and (Test-Path $SceneTimingsFile)) {
        Write-Host "Parsing scene timings from $SceneTimingsFile"
        $scenes = Parse-SceneLines -Lines (Get-Content $SceneTimingsFile)
    } elseif ($CaptionsFile -and (Test-Path $CaptionsFile)) {
        Write-Host "Parsing timecodes from captions file $CaptionsFile"
        $rows = Get-Content $CaptionsFile
        $lines = @()
        foreach ($row in $rows) {
            if ($row -match '\((?<start>[^–\)]+)[–-](?<end>[^\)]+)\)') {
                $caption = $row -replace '\((?<content>.*)\)', ''
                $lines += "$($matches.start)-$($matches.end)|$caption"
            }
        }
        $scenes = Parse-SceneLines -Lines $lines
    }

    if ($scenes.Count -eq 0) {
        $duration = Get-VideoDuration -Path $SourceVideo
        Write-Host "No explicit scene timings provided. Creating $MaxScenes evenly spaced clips from video duration $duration seconds."
        $clipLength = [math]::Min($MaxClipSeconds, [math]::Max(8, [math]::Round($duration / ($MaxScenes * 1.5))))
        $interval = [math]::Max(10, [math]::Round(($duration - $clipLength) / $MaxScenes))
        for ($i = 0; $i -lt $MaxScenes; $i++) {
            $start = [math]::Min($i * $interval + 10, $duration - $clipLength)
            if ($start -lt 0) { $start = 0 }
            $end = [math]::Min($start + $clipLength, $duration)
            $caption = "Highlight scene $($i + 1)"
            $scenes += [PSCustomObject]@{ Start = $start; End = $end; Duration = $end - $start; Caption = $caption }
        }
    }

    $scenes = $scenes | Where-Object { $_.Duration -gt 3 }
    $selected = $scenes | Select-Object -First $MaxScenes
    if ($selected.Count -eq 0) {
        throw "Unable to build montage scenes. Check scene timings or source video duration."
    }
    return $selected
}

function Select-MusicFile {
    if ($MusicFile -and (Test-Path $MusicFile)) { return $MusicFile }
    if (-not (Test-Path $MusicDir)) { return $null }
    $candidates = Get-ChildItem -Path $MusicDir -File | Where-Object { $_.Extension -match '(?i)\.(mp3|wav|m4a|aac)' } | Sort-Object Name
    if ($candidates.Count -gt 0) { return $candidates[0].FullName }
    return $null
}

function Create-Clip {
    param(
        [int]$Index,
        [double]$Start,
        [double]$End,
        [string]$Caption
    )

    $safeCaption = Escape-FfmpegDrawText -Text $Caption
    $clipDuration = [math]::Round($End - $Start, 2)
    if ($clipDuration -gt $MaxClipSeconds) { $clipDuration = $MaxClipSeconds }
    $clipOut = Join-Path $OutputDir ("clip_{0:D2}.mp4" -f $Index)
    $scaleFilter = "scale='if(gt(a,{0}/{1}),{0},-1)':'if(gt(a,{0}/{1}),-1,{1})'" -f $Width,$Height
    $padFilter = "pad={0}:{1}:(ow-iw)/2:(oh-ih)/2:black" -f $Width,$Height
    $drawFilter = "drawtext=font='Arial':text='{0}':fontcolor=white:fontsize=40:borderw=4:bordercolor=black:x=(w-text_w)/2:y=h-140:box=1:boxcolor=black@0.5:boxborderw=10" -f $safeCaption
    $fadeOutStart = [math]::Round($clipDuration - $FadeDuration, 2)

    $vf = "${scaleFilter},${padFilter},${drawFilter},fade=t=in:st=0:d=${FadeDuration},fade=t=out:st=${fadeOutStart}:d=${FadeDuration}"
    $af = "afade=t=in:ss=0:d=${FadeDuration},afade=t=out:st=${fadeOutStart}:d=${FadeDuration}"
    $args = @('-y','-ss',$Start,'-to',$End,'-i',$SourceVideo,'-vf',$vf,'-af',$af,'-c:v','libx264','-preset','medium','-crf','20','-c:a','aac','-b:a','160k','-pix_fmt','yuv420p',$clipOut)

    Write-Host "Creating clip $Index: $Caption [$Start - $End] -> $clipOut"
    & ffmpeg @args | Out-Null
    return $clipOut
}

if (-not (Test-Path $SourceVideo)) { Write-Error "Source video not found: $SourceVideo"; exit 1 }
if (-not (Get-Command ffmpeg -ErrorAction SilentlyContinue)) { Write-Error "ffmpeg not found on PATH."; exit 1 }
if (-not (Get-Command ffprobe -ErrorAction SilentlyContinue)) { Write-Error "ffprobe not found on PATH."; exit 1 }

New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null

$scenes = Build-SceneList
$sceneCount = $scenes.Count
Write-Host "Building montage from $sceneCount scenes."

$clipFiles = @()
$index = 1
foreach ($scene in $scenes) {
    $clipFiles += Create-Clip -Index $index -Start $scene.Start -End $scene.End -Caption $scene.Caption
    $index++
}

$listFile = Join-Path $OutputDir 'montage_clip_list.txt'
Remove-Item -Force -ErrorAction SilentlyContinue $listFile
foreach ($clipPath in $clipFiles) {
    Add-Content -Path $listFile -Value "file '$clipPath'"
}

$montageTemp = Join-Path $OutputDir 'montage_temp.mp4'
$concatArgs = @('-y','-f','concat','-safe','0','-i',$listFile,'-c','copy',$montageTemp)
Write-Host "Concatenating $sceneCount clips into temporary montage file."
& ffmpeg @concatArgs | Out-Null

$finalOut = Join-Path $OutputDir $OutputName
$music = Select-MusicFile
$hasAudio = Get-VideoHasAudio -Path $montageTemp

if ($music) {
    Write-Host "Adding music track: $music"
    if ($hasAudio) {
        $mixArgs = @('-y','-i',$montageTemp,'-stream_loop','-1','-i',$music,'-filter_complex','[0:a]volume=1[a0];[1:a]volume=0.15[a1];[a0][a1]amix=inputs=2:duration=shortest:dropout_transition=2[aout]','-map','0:v','-map','[aout]','-c:v','copy','-c:a','aac','-b:a','192k','-shortest',$finalOut)
    } else {
        $mixArgs = @('-y','-i',$montageTemp,'-stream_loop','-1','-i',$music,'-map','0:v','-map','1:a','-c:v','copy','-c:a','aac','-b:a','192k','-shortest',$finalOut)
    }
    & ffmpeg @mixArgs | Out-Null
} else {
    Write-Host "No music file found in $MusicDir. Finalizing montage without additional music."
    Copy-Item -Force $montageTemp $finalOut
}

if (-not (Test-Path $finalOut)) { Write-Error "Failed to create final montage file."; exit 1 }

Write-Host "Montage created: $finalOut"
if ($music) { Write-Host "Background music used: $music" }
Write-Host "Final duration should be between $MinTotalSeconds and $MaxTotalSeconds seconds."
