param(
  [string]$Text = "You missed this. Interstellar is not about space. It's about time.",
  [string]$Out = ".\renders\voice.mp3",
  [string]$Voice = "en-US-GuyNeural"
)

$ErrorActionPreference = 'Stop'

$Out = [System.IO.Path]::GetFullPath($Out)
New-Item -ItemType Directory -Path (Split-Path $Out) -Force | Out-Null

Write-Host "Generating TTS -> $Out"

$edgeArgs = @("--text=$Text", "--voice=$Voice", "--write-media=$Out")
$audio = $null
try {
  & py -m edge_tts @edgeArgs
  if (Test-Path $Out) { $audio = $Out }
} catch {
  Write-Warning "edge_tts failed: $_. Falling back to System.Speech"
}

if (-not $audio) {
  $wav = [System.IO.Path]::ChangeExtension($Out, '.wav')
  try {
    Add-Type -AssemblyName System.Speech -ErrorAction Stop
    $synth = New-Object System.Speech.Synthesis.SpeechSynthesizer
    $synth.SetOutputToWaveFile($wav)
    $synth.Speak($Text)
    $synth.Dispose()
    if (Test-Path $wav) {
      if (Get-Command ffmpeg -ErrorAction SilentlyContinue) {
        & ffmpeg -y -i $wav -c:a libmp3lame -b:a 128k $Out
      } else {
        Move-Item -Force $wav $Out
      }
    }
  } catch {
    Write-Error "Fallback TTS failed: $_"
    exit 1
  }
}

Write-Host "TTS written to: $Out"