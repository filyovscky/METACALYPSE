# Formats and safety

[Русская версия](SAFETY.ru.md)

METACALYPSE creates a sibling copy. Temporary copies are removed on failure; `_partial` copies are kept for manual review. Originals stay untouched unless `-InPlace` is explicitly supplied. That option replaces an original only after verification and a SHA-256 comparison; use it only with a backup.

| Formats | Cleaning and verification |
| --- | --- |
| DOCX, DOCM, DOTX, DOTM, XLSX, XLSM, XLTX, XLTM, PPTX, PPTM, POTX, POTM | Removes standard `docProps` parts and thumbnails. Other package parts are compared by SHA-256. Embedded images are checked for metadata but not modified. Office applications are not launched. |
| JPG, JPEG, PNG, WebP, GIF, TIF, TIFF, HEIC, HEIF, AVIF, MP3, WAV, MP4, MOV, M4V, M4A | ExifTool removes writable metadata. Tags are read again, and file type, image dimensions, and duration are checked. Image ICC profiles are preserved. |

ExifTool write support varies by format. Required container fields, especially in video, can remain; such files are marked `PARTIAL`. `OK` only means the listed checks passed, not forensic anonymity.

The tool does **not** remove document text, visible content, comments, revision history, hidden sheets or slides, embedded files, metadata inside embedded images, or traces in pixels and frames. Office may write new properties if you save a cleaned file again. Legacy binary Office formats and PDF are unsupported rather than modified without a safe verifier.

Close files in Office before cleaning. A file opened for writing is not copied, to avoid an incomplete snapshot. When processing a folder, existing `_clean` and `_partial` outputs are skipped. Logs include file paths but list removed field names without their old values.

Windows supports PowerShell 5.1/7 and File Explorer integration. The CLI is designed for PowerShell 7 on macOS and Linux, but those systems were not runtime-tested for this release. No file-manager integration is provided there. If ExifTool is not in `PATH`, create a local `config.local.json` beside the script:

```json
{ "exiftoolPath": "/absolute/path/to/exiftool" }
```

On Windows, use an absolute path to `exiftool.exe` with escaped backslashes. The local config is excluded from Git. Windows context-menu launch errors are written to `METACALYPSE-launch-error.log` in the system temporary directory.
