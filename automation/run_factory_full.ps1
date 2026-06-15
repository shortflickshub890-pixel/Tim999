param(
    [string]$CaptionsFile = "assets/images/captions/001_storyboard.txt",
    [string]$ImagesDir = "assets/images/001_interstellar",
    [string]$OutDir = "output",
    [string]$PublishDir = "publish",
    [string]$Voice = "en-US-GuyNeural",
    [switch]$Clean,
    [switch]$SkipPublish,
    [switch]$GitHubRelease,
    [string]$GitHubToken = $env:GITHUB_TOKEN,
    [string]$GitHubRepo = "",
    [string]$GitHubTag = "",
    [string]$ReleaseName = "",
    [string]$ReleaseBody = "Auto-published assets from AI Movie Factory.",
    [switch]$PreRelease,
    [string]$S3Bucket = "",
    [string]$S3Prefix = "",
    [switch]$GitCommitPush,
    [string]$CommitMessage = "Auto commit after generation",
    [switch]$CreatePr,
    [string]$GitBranch = "master",
    [string]$GitRemote = "origin",
    [string]$GitHubBaseBranch = "main",
    [switch]$CreateMontage,
    [string]$SourceVideo = "",
    [string]$SceneTimingsFile = "",
    [string]$MusicFile = "",
    [string]$MusicDir = "assets/music",
    [int]$MaxScenes = 4,
    [int]$MaxClipSeconds = 12,
    [int]$MinMontageSeconds = 30,
    [int]$MaxMontageSeconds = 45,
    [string]$MontageOutputName = "montage.mp4"
)

$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent

$CaptionsFile = [System.IO.Path]::GetFullPath((Join-Path $root $CaptionsFile))
$ImagesDir = [System.IO.Path]::GetFullPath((Join-Path $root $ImagesDir))
$OutDir = [System.IO.Path]::GetFullPath((Join-Path $root $OutDir))
$PublishDir = [System.IO.Path]::GetFullPath((Join-Path $root $PublishDir))

function Get-GitHubRepoFromOrigin {
    try {
        $originUrl = (& git -C $root remote get-url $GitRemote) -join ""
        if ($originUrl -match 'github.com[:/](?<repo>[^/]+/[^/]+)(\.git)?$') {
            return $matches['repo']
        }
    } catch {
        return $null
    }
    return $null
}

Write-Host ""
Write-Host "=== AI MOVIE FACTORY - FULL AUTOMATION ==="
Write-Host "CaptionsFile: $CaptionsFile"
Write-Host "ImagesDir:    $ImagesDir"
Write-Host "OutDir:       $OutDir"
Write-Host "PublishDir:   $PublishDir"
Write-Host "Voice:        $Voice"
Write-Host "GitHubRelease: $GitHubRelease"
Write-Host "S3Bucket:     $S3Bucket"
Write-Host "GitCommitPush: $GitCommitPush"
Write-Host "CreatePr:     $CreatePr"
Write-Host "CreateMontage: $CreateMontage"
if ($CreateMontage) {
    Write-Host "  SourceVideo:     $SourceVideo"
    Write-Host "  MaxScenes:       $MaxScenes"
    Write-Host "  ClipDuration:    $MaxClipSeconds sec"
    Write-Host "  MontageLength:   $MinMontageSeconds-$MaxMontageSeconds sec"
}
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
$montageScript = Join-Path $PSScriptRoot 'create_montage.ps1'

Write-Host "Starting video generation..."
& pwsh -NoProfile -ExecutionPolicy Bypass -File $factoryScript -CaptionsFile $CaptionsFile -ImagesDir $ImagesDir -OutDir $OutDir -Voice $Voice

if ($CreateMontage) {
    if (-not $SourceVideo) {
        Write-Error "SourceVideo parameter is required for montage creation. Specify -SourceVideo with path to your video file."
        exit 1
    }
    $SourceVideoPath = [System.IO.Path]::GetFullPath((Join-Path $root $SourceVideo))
    if (-not (Test-Path $SourceVideoPath)) {
        Write-Error "Source video not found: $SourceVideoPath"
        exit 1
    }
    Write-Host ""
    Write-Host "Creating montage from source video..."
    $montageArgs = @(
        '-SourceVideo', $SourceVideoPath,
        '-OutputDir', $OutDir,
        '-OutputName', $MontageOutputName,
        '-MaxScenes', $MaxScenes,
        '-MaxClipSeconds', $MaxClipSeconds,
        '-MinTotalSeconds', $MinMontageSeconds,
        '-MaxTotalSeconds', $MaxMontageSeconds,
        '-MusicDir', $MusicDir
    )
    if ($SceneTimingsFile) { $montageArgs += '-SceneTimingsFile'; $montageArgs += $SceneTimingsFile }
    if ($MusicFile) { $montageArgs += '-MusicFile'; $montageArgs += $MusicFile }
    
    & pwsh -NoProfile -ExecutionPolicy Bypass -File $montageScript @montageArgs
    Write-Host "Montage creation complete."
}

if (-not $SkipPublish) {
    Write-Host "Publishing generated videos..."
    $publishArgs = @('-Source', $OutDir, '-Dest', $PublishDir, '-Move')
    if ($GitHubRelease) { $publishArgs += '-GitHubRelease' }
    if ($GitHubToken) { $publishArgs += '-GitHubToken'; $publishArgs += $GitHubToken }
    if ($GitHubRepo) { $publishArgs += '-GitHubRepo'; $publishArgs += $GitHubRepo }
    if ($GitHubTag) { $publishArgs += '-GitHubTag'; $publishArgs += $GitHubTag }
    if ($ReleaseName) { $publishArgs += '-ReleaseName'; $publishArgs += $ReleaseName }
    if ($ReleaseBody) { $publishArgs += '-ReleaseBody'; $publishArgs += $ReleaseBody }
    if ($PreRelease) { $publishArgs += '-PreRelease' }
    if ($S3Bucket) { $publishArgs += '-S3Bucket'; $publishArgs += $S3Bucket }
    if ($S3Prefix) { $publishArgs += '-S3Prefix'; $publishArgs += $S3Prefix }

    & pwsh -NoProfile -ExecutionPolicy Bypass -File $publishScript @publishArgs
} else {
    Write-Host "SkipPublish enabled, leaving files in $OutDir"
}

if ($GitCommitPush) {
    Write-Host "Committing and pushing changes..."
    try {
        & git -C $root add -A
        $null = & git -C $root diff --cached --quiet
        if ($LASTEXITCODE -eq 0) {
            Write-Host "No tracked changes to commit."
        } else {
            & git -C $root commit -m $CommitMessage
            & git -C $root push $GitRemote $GitBranch
        }
    } catch {
        Write-Warning "Git commit/push failed: $_"
    }
}

if ($CreatePr) {
    if (-not $GitHubToken) {
        Write-Warning "GitHub token is required to create a PR. Set GITHUB_TOKEN or pass -GitHubToken."
    } else {
        $repoName = if ($GitHubRepo) { $GitHubRepo } else { Get-GitHubRepoFromOrigin }
        if (-not $repoName) {
            Write-Warning "Cannot determine GitHub repo from remote. Set -GitHubRepo explicitly."
        } else {
            $prBranch = "autopr/$(Get-Date -Format 'yyyyMMddHHmmss')"
            Write-Host "Creating branch $prBranch and pushing to remote..."
            try {
                & git -C $root checkout -b $prBranch
                & git -C $root push -u $GitRemote $prBranch
                $prData = @{ title = "Auto PR from AI Movie Factory"; head = $prBranch; base = $GitHubBaseBranch; body = "Auto-generated PR for newly published assets." }
                $headers = @{ Authorization = "token $GitHubToken"; Accept = 'application/vnd.github+json'; 'User-Agent' = 'AI Movie Factory' }
                $prResponse = Invoke-RestMethod -Uri "https://api.github.com/repos/$repoName/pulls" -Method Post -Headers $headers -Body ($prData | ConvertTo-Json)
                Write-Host "PR created: $($prResponse.html_url)"
            } catch {
                Write-Warning "Failed to create PR: $_"
            }
        }
    }
}

if ($Clean -and -not $SkipPublish) {
    Write-Host "Cleaning temporary output folder..."
    Remove-Item -Recurse -Force $OutDir
}

Write-Host ""
Write-Host "=== COMPLETE ==="
Write-Host "Published files can be found in: $PublishDir"
if ($Clean -and -not $SkipPublish) { Write-Host "Temporary output folder removed." }
