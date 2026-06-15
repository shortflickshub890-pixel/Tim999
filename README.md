AI_MOVIE_FACTORY - Quick README

Requirements
- PowerShell (Windows)
- Python with `edge-tts` package available as a module (`py -m edge_tts`)
- `ffmpeg` available on PATH

Quick usage

- Run the full automated pipeline with explicit options (recommended):

```powershell
pwsh -NoProfile -ExecutionPolicy Bypass -File .\automation\run_factory_full.ps1 -CaptionsFile "assets/images/captions/001_storyboard.txt" -ImagesDir "assets/images/001_interstellar" -Voice "en-US-GuyNeural"
```

- Run the full pipeline and publish to GitHub Releases:

```powershell
pwsh -NoProfile -ExecutionPolicy Bypass -File .\automation\run_factory_full.ps1 -GitHubRelease -GitHubRepo "shortflickshub890-pixel/Tim999" -GitHubToken "<token>" -GitHubTag "v1.0.0" -ReleaseName "AI Movie Factory Release"
```

- Run the full pipeline and publish to S3:

```powershell
pwsh -NoProfile -ExecutionPolicy Bypass -File .\automation\run_factory_full.ps1 -S3Bucket "my-bucket" -S3Prefix "movie-factory"
```

- Run the full pipeline, commit and push changes, and create a PR:

```powershell
pwsh -NoProfile -ExecutionPolicy Bypass -File .\automation\run_factory_full.ps1 -GitCommitPush -CreatePr -GitHubToken "<token>" -GitHubRepo "shortflickshub890-pixel/Tim999"
```

- If your repository uses a different default branch name (for example `master`), add:

```powershell
-GitHubBaseBranch "master"
```

- Generate videos from captions and images manually:

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
- `automation/run_factory_full.ps1` runs the full pipeline end-to-end: generation + publish.
- It accepts `-CaptionsFile` and `-Voice` explicitly to minimize manual edits.
- `automation/publish.ps1` can publish locally, to GitHub Releases, or to AWS S3.
- `automation/run_factory_full.ps1` also supports `-GitCommitPush` and `-CreatePr` for auto versioning and PR creation.
- Backups of modified scripts are in the `backups/` folder.
