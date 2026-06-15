AI_MOVIE_FACTORY - Quick README

Requirements
- PowerShell (Windows)
- Python with `edge-tts` package available as a module (`py -m edge_tts`)
- `ffmpeg` available on PATH

Quick usage

- Generate videos from captions and images:

```powershell
pwsh -NoProfile -ExecutionPolicy Bypass -File .\factory\run_factory.ps1 -CaptionsFile .\assets\images\captions\001_storyboard.txt -ImagesDir .\assets\images\001_interstellar -OutDir .\output -Voice en-US-GuyNeural
```

- Generate a single TTS file:

```powershell
pwsh .\scripts\tts.ps1 -Text "Hello world" -Out .\renders\voice.mp3
```

- Render a single video from an image + voice:

```powershell
pwsh .\scripts\build.ps1 -Image .\assets\images\001_interstellar\bg_001.jpg -Voice .\renders\voice.mp3 -Out .\renders\final_factory.mp4
```

- Publish rendered files (copy or move):

```powershell
pwsh .\automation\publish.ps1 -Source .\output -Dest .\publish    # copies
pwsh .\automation\publish.ps1 -Source .\output -Dest .\publish -Move  # moves
```

Notes
- `run_factory.ps1` will try `edge-tts` first and fall back to System.Speech if needed.
- Backups of modified scripts are in the `backups/` folder.
