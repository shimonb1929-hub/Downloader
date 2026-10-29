# Video Downloader — overview

Source: the zip you uploaded (app version 12, Chrome button version 1.3).
Copy saved in `youtube-extension/source/`. Not in any GitHub repo yet.

## What it is
Two parts, Windows only:
1. **The app** (`app/downloader.ps1`, PowerShell window). Paste a link, pick a type, click Download.
   It runs **yt-dlp** on your own internet, so NetFree still filters everything.
2. **The Chrome button** (`extension/`). A small blue ↓ tab at the bottom right of YouTube video
   and Shorts pages. Click it → box with 3 buttons → sends the link to the app.

## How the button talks to the app
- Button (`content.js`) → background (`background.js`) grabs your YouTube cookies ("pass") from Chrome.
- Sends link + type + cookies to the app through Chrome "native messaging" (`host.bat` → `host.ps1`).
  Only on this computer, nothing goes online.
- `host.ps1` checks it is a YouTube video link, saves the cookies (YouTube only) to `ext-cookies.txt`,
  drops a job file in `app/jobs/`, and opens the app if it is closed. The app picks up the job.

## Updating
- **Update this app** button (bottom right). The app also checks by itself a few seconds after it opens.
- It downloads the repo's `main` branch as a zip from GitHub (the repo is public, so no password needed),
  compares every file, and copies over only the ones that changed. Then it reopens itself.
- Never touches `app/tools`, settings, cookies or downloads.
- If anything in `extension/` changed, it tells you to restart Chrome (Chrome reloads an unpacked
  extension's files when it starts).
- Code: `app/updater.ps1` (loaded by `downloader.ps1`).
- "Update downloader" (bottom left) still updates only yt-dlp.

## Download options
| Button | What it does |
|---|---|
| **Video** | MP4 (H.264) up to 1080p, plus YouTube's best AAC sound (no DRC), copied in with no re-encode. |
| **MP3** | Best sound (no DRC, highest bitrate), converted to MP3 at 320 kbps, 1.5 dB lower to stop clipping. |
| **Best sound** | YouTube's own best stream kept as is (.opus or .m4a), no re-encode. |

Saves to `Downloads\Video Downloads` (can change in the app).
If YouTube refuses, the app retries with up to 6 different YouTube "clients" by itself.
It spots NetFree blocks (HTTP 418) and says "not approved" in plain words.

## Install and load
1. Extract the zip. Run `Start Video Downloader.bat`. First run downloads tools (~150 MB) into
   `app/tools`: yt-dlp, deno, ffmpeg, ffprobe.
2. Optional: `Make Desktop Shortcut.bat`.
3. Chrome button: run `Add Download Button to Chrome.bat`. It registers the helper in the registry
   (Chrome + Edge, no admin). Then in Chrome: Developer mode ON → Load unpacked → `extension` folder.
   The manifest has a fixed `key`, so the ID is always `bagidnomlmojifgdgmgicinhabkhbahb`.

## Best improvements (most value first)
1. **Fix "Best sound".** It converts YouTube's sound (already compressed Opus/AAC) to WAV. WAV adds
   no quality, only size. Better: keep the original stream as is (Opus `.opus`/`.webm` or AAC `.m4a`),
   no re-encode. **Done** (v13+). v14: MP3 at 320 kbps without clipping, Video skips DRC sound.
2. **Progress and errors in the Chrome box.** Today it only says "Sent". No progress, no fail
   message in the page. (Being done in thread "Add download progress and errors".)
3. **Delete the saved cookies after each download.** `ext-cookies.txt` stays on disk in plain text.
4. **Check downloaded tools.** Setup pulls "latest" yt-dlp/deno/ffmpeg with certificate checks off
   (needed for NetFree), and no checksum. Add a checksum or a pinned version to be safe.
5. **Video quality choice.** Now fixed at max 1080p. Add 720p (smaller) and "best" options.
6. **Faster page detection.** `content.js` checks the page every 1 sec. YouTube's own
   "page changed" event is lighter and instant.
7. **Download queue.** Show a list when you send several videos in a row. **Done** (v15): several
   downloads at the same time (3 by default, setting 1-6), a list with each one's progress, paste
   many links at once. Each Chrome click starts right away and gets its own line in the box.
8. **Put it on GitHub** so changes are saved and tracked.
