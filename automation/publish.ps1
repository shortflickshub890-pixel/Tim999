param(
    [string]$Source = ".\output",
    [string]$Dest = ".\publish",
    [switch]$Move,
    [switch]$GitHubRelease,
    [string]$GitHubToken = $env:GITHUB_TOKEN,
    [string]$GitHubRepo = "",
    [string]$GitHubTag = "",
    [string]$ReleaseName = "",
    [string]$ReleaseBody = "Auto-published assets from AI Movie Factory.",
    [switch]$PreRelease,
    [string]$S3Bucket = "",
    [string]$S3Prefix = ""
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

function Resolve-GitHubRepo {
    param([string]$Repo)
    if ($Repo) { return $Repo }
    try {
        $originUrl = (& git remote get-url origin) -join ""
        if ($originUrl -match 'github.com[:/](?<repo>[^/]+/[^/]+)(\.git)?$') { return $matches['repo'] }
    } catch {
        return $null
    }
    return $null
}

if ($GitHubRelease) {
    if (-not $GitHubToken) {
        Write-Error "GitHub release requested but no token was provided. Set GITHUB_TOKEN or use -GitHubToken."
        exit 1
    }
    $repoName = Resolve-GitHubRepo -Repo $GitHubRepo
    if (-not $repoName) {
        Write-Error "Unable to determine GitHub repository. Set -GitHubRepo in owner/repo format."
        exit 1
    }
    if (-not $GitHubTag) { $GitHubTag = "release-$(Get-Date -Format 'yyyyMMddHHmmss')" }
    if (-not $ReleaseName) { $ReleaseName = "Auto publish $GitHubTag" }

    $headers = @{ Authorization = "token $GitHubToken"; Accept = 'application/vnd.github+json'; 'User-Agent' = 'AI Movie Factory' }
    $releaseData = @{ tag_name = $GitHubTag; name = $ReleaseName; body = $ReleaseBody; prerelease = $PreRelease.IsPresent }
    Write-Host "Creating GitHub release $GitHubTag for $repoName..."
    $release = Invoke-RestMethod -Uri "https://api.github.com/repos/$repoName/releases" -Method Post -Headers $headers -Body ($releaseData | ConvertTo-Json) -ContentType 'application/json'
    $uploadBase = $release.upload_url -replace '\{\?name,label\}$',''

    foreach ($f in $files) {
        $uploadUrl = "$uploadBase?name=$([uri]::EscapeDataString($f.Name))"
        Write-Host "Uploading $($f.Name) to GitHub release..."
        Invoke-RestMethod -Uri $uploadUrl -Method Post -Headers $headers -InFile $f.FullName -ContentType 'application/octet-stream'
    }
    Write-Host "GitHub release published: $($release.html_url)"
}

if ($S3Bucket) {
    if (-not (Get-Command aws -ErrorAction SilentlyContinue)) {
        Write-Warning "AWS CLI not found; skipping S3 publish."
    } else {
        foreach ($f in $files) {
            $key = if ($S3Prefix) { "$S3Prefix/$($f.Name)" } else { $f.Name }
            Write-Host "Uploading $($f.Name) to s3://$S3Bucket/$key"
            & aws s3 cp $f.FullName "s3://$S3Bucket/$key"
        }
        Write-Host "S3 publish complete."
    }
}

Write-Host "Publish complete. Destination: $Dest"
