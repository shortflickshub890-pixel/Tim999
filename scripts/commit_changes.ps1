param(
    [string]$Message = "Apply improvements to PowerShell scripts",
    [switch]$Push
)

if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    Write-Error "git not found on PATH. Install git to use this script."
    exit 1
}

git add -A
git commit -m "$Message"
if ($Push) { git push }

Write-Host "Committed changes with message: $Message"
