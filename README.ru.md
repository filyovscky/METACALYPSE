# METACALYPSE

![METACALYPSE logo](assets/logo.svg)

[English](README.md)

Очистка метаданных Office-документов и медиафайлов перед отправкой. По умолчанию исходник **не меняется**: рядом появляется `имя_clean.ext` либо `имя_partial.ext`, если проверка нашла оставшиеся данные.

## Быстрый старт

**Windows:** скачайте и распакуйте проект в постоянную папку. Для обработки фото, аудио и видео установите [ExifTool](https://exiftool.org/) в `PATH`; без него работают только Office-документы. Дважды щёлкните `install-context-menu.bat`. После этого выделите файлы в Проводнике, нажмите **ПКМ -> METACALYPSE - Clean metadata (copy)**. В Windows 11 сначала может потребоваться **Показать дополнительные параметры**. Для папки пункт называется **METACALYPSE - Clean metadata (copies)**. Несколько выбранных файлов обрабатываются по очереди в одном окне. Удаление пункта меню: `uninstall-context-menu.bat`.

**macOS / Linux / Windows CLI:** нужны PowerShell 7 (`pwsh`) и ExifTool в `PATH` для медиа. Запускайте из папки проекта:

```powershell
pwsh -NoProfile -File ./metacalypse.ps1 -TargetPaths '/path/to/file.docx' '/path/to/photo.jpg'
```

На Windows без `pwsh` можно использовать `metacalypse.bat` или `powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\metacalypse.ps1 -TargetPaths 'C:\path\file.docx'`. Меню Проводника доступно только на Windows. Папку проекта после установки меню не перемещайте без повторной установки.

Поддерживаются современные Office Open XML (`DOCX`, `XLSX`, `PPTX` и шаблоны/макросные варианты), изображения `JPG`, `PNG`, `WebP`, `GIF`, `TIFF`, `HEIC`, `HEIF`, `AVIF`, аудио `MP3`, `WAV`, `M4A` и видео `MP4`, `MOV`, `M4V`. Старые `DOC`/`XLS`/`PPT` и PDF не изменяются. [Форматы и ограничения](docs/SAFETY.ru.md).

Результат: `OK` = проверенная копия, `PARTIAL` = копия требует ручной проверки, `FAIL` = копия не создана, `UNSUPPORTED` = формат пропущен. Существующие результаты не перезаписываются. В отчёте перечисляются имена удалённых полей, но не прежние значения. Лог: `METACALYPSE-last-run.log` во временной папке системы.

**Важно:** это не гарантия анонимности. Текст, комментарии, правки, встроенные файлы и содержимое пикселей не очищаются. Перед отправкой проверьте копию. Исходники в обычном режиме остаются без изменений.

[Проверки и ограничения](docs/SAFETY.ru.md)

Проверка на своей системе: `pwsh -NoProfile -File ./tests/smoke.ps1`.
