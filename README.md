# METACALYPSE

![METACALYPSE logo](assets/logo.svg)

[Русская версия](README.ru.md)

Remove metadata from Office documents and media before sharing them. By default, originals stay untouched: METACALYPSE creates a sibling `name_clean.ext` file, or `name_partial.ext` if some metadata may remain.

## Windows: install and use

1. [Download the project ZIP](https://github.com/filyovscky/METACALYPSE/archive/refs/heads/main.zip) and extract it to a permanent folder. Or, if Git is installed, run `git clone https://github.com/filyovscky/METACALYPSE.git`.
2. **For images, audio, and video:** [download ExifTool for Windows](https://exiftool.org/). Extract its ZIP, rename `exiftool(-k).exe` to `exiftool.exe`, and place that file **and** the `exiftool_files` folder beside `metacalypse.ps1`. Office properties can be cleaned without ExifTool, but embedded-image checks may then report `PARTIAL`.
3. Double-click `install-context-menu.bat` in the project folder. Administrator rights are not required.
4. Select files in File Explorer, right-click, and choose **METACALYPSE - Clean metadata (copy)**. On Windows 11, choose **Show more options** first if needed. For a folder, choose **METACALYPSE - Clean metadata (copies)**. Multiple files run sequentially in one PowerShell window; cleaned copies appear beside the originals.

To remove the menu entry, double-click `uninstall-context-menu.bat`. If you move the project folder, run the installer again. To run without the menu, drag files onto `metacalypse.bat` or use:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\metacalypse.ps1 -TargetPaths 'C:\path\file.docx'
```

## macOS / Linux: command line

1. [Download the project ZIP](https://github.com/filyovscky/METACALYPSE/archive/refs/heads/main.zip) and extract it, or run `git clone https://github.com/filyovscky/METACALYPSE.git`.
2. Install [PowerShell 7](https://learn.microsoft.com/en-us/powershell/scripting/install/install-powershell). For media, also install [ExifTool](https://exiftool.org/install.html) so `exiftool` is on `PATH`.
3. Open a terminal in the project folder and run:

```sh
pwsh -NoProfile -File ./metacalypse.ps1 -TargetPaths '/path/to/file.docx' '/path/to/photo.jpg'
```

File-manager context menus are supported on Windows only.

Supported: modern Office Open XML files (`DOCX`, `XLSX`, `PPTX`, including macro-enabled files and templates), `JPG`, `PNG`, `WebP`, `GIF`, `TIFF`, `HEIC`, `HEIF`, `AVIF`, `MP3`, `WAV`, `M4A`, `MP4`, `MOV`, and `M4V`. Legacy Office formats and PDF are skipped. [Formats and limitations](docs/SAFETY.md).

`OK` means a verified copy, `PARTIAL` needs manual review, `FAIL` means no output, and `UNSUPPORTED` means the format was skipped. Existing copies are never overwritten. The report lists removed field **names**, not their previous values. The latest log is `METACALYPSE-last-run.log` in the system temporary directory.

**Not an anonymity guarantee:** document text, comments, revisions, embedded files, and visible image/video content are not cleaned. Inspect the output before sharing it.

Smoke test: `pwsh -NoProfile -File ./tests/smoke.ps1`.
