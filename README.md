# METACALYPSE

![METACALYPSE logo](assets/logo.svg)

[Русская версия](README.ru.md)

Remove metadata from Office documents and media before sharing them. By default, originals stay untouched: METACALYPSE creates a sibling `name_clean.ext` file, or `name_partial.ext` if some metadata may remain.

## Quick start

**Windows:** download and extract the project to a permanent folder. Install [ExifTool](https://exiftool.org/) in `PATH` to process images, audio, and video; Office files work without it. Double-click `install-context-menu.bat`. Then select files in File Explorer and choose **right-click -> METACALYPSE - Clean metadata (copy)**. On Windows 11, first choose **Show more options** if the entry is not visible. For folders, the entry is **METACALYPSE - Clean metadata (copies)**. Multiple selected files run sequentially in one PowerShell window. To remove the menu entry, run `uninstall-context-menu.bat`.

**macOS / Linux / Windows CLI:** install PowerShell 7 (`pwsh`) and ExifTool for media, then run from the project folder:

```powershell
pwsh -NoProfile -File ./metacalypse.ps1 -TargetPaths '/path/to/file.docx' '/path/to/photo.jpg'
```

On Windows without `pwsh`, use `metacalypse.bat` or `powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\metacalypse.ps1 -TargetPaths 'C:\path\file.docx'`. File Explorer integration is Windows-only. If you move the project folder, reinstall the context-menu entry.

Supported: modern Office Open XML files (`DOCX`, `XLSX`, `PPTX`, including macro-enabled files and templates), `JPG`, `PNG`, `WebP`, `GIF`, `TIFF`, `HEIC`, `HEIF`, `AVIF`, `MP3`, `WAV`, `M4A`, `MP4`, `MOV`, and `M4V`. Legacy Office formats and PDF are skipped. [Formats and limitations](docs/SAFETY.md).

`OK` means a verified copy, `PARTIAL` needs manual review, `FAIL` means no output, and `UNSUPPORTED` means the format was skipped. Existing copies are never overwritten. The report lists removed field **names**, not their previous values. The latest log is `METACALYPSE-last-run.log` in the system temporary directory.

**Not an anonymity guarantee:** document text, comments, revisions, embedded files, and visible image/video content are not cleaned. Inspect the output before sharing it.

Smoke test: `pwsh -NoProfile -File ./tests/smoke.ps1`.
