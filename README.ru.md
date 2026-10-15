# METACALYPSE

![METACALYPSE logo](assets/logo.svg)

[English](README.md)

Очистка метаданных Office-документов и медиафайлов перед отправкой. По умолчанию исходник **не меняется**: рядом появляется `имя_clean.ext` либо `имя_partial.ext`, если проверка нашла оставшиеся данные.

## Windows: установка и запуск

1. [Скачайте ZIP проекта](https://github.com/filyovscky/METACALYPSE/archive/refs/heads/main.zip) и распакуйте в постоянную папку. Если установлен Git, можно выполнить `git clone https://github.com/filyovscky/METACALYPSE.git`.
2. **Для фото, аудио и видео:** [скачайте ExifTool для Windows](https://exiftool.org/). Распакуйте архив, переименуйте `exiftool(-k).exe` в `exiftool.exe` и положите этот файл **вместе с папкой** `exiftool_files` рядом с `metacalypse.ps1`. Свойства Office можно очистить без ExifTool, но проверка вложенных изображений тогда может дать статус `PARTIAL`.
3. Дважды щёлкните `install-context-menu.bat` в папке проекта. Права администратора не нужны.
4. Выделите файлы в Проводнике, нажмите ПКМ и выберите **METACALYPSE - Clean metadata (copy)**. В Windows 11 сначала может понадобиться **Показать дополнительные параметры**. Для папки выберите **METACALYPSE - Clean metadata (copies)**. Несколько файлов обрабатываются по очереди в одном окне, очищенные копии появляются рядом с исходниками.

Чтобы убрать пункт меню, запустите `uninstall-context-menu.bat`. Если переместили папку проекта, запустите установщик снова. Без меню можно перетащить файлы на `metacalypse.bat` или выполнить:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\metacalypse.ps1 -TargetPaths 'C:\path\file.docx'
```

## macOS / Linux: командная строка

1. [Скачайте ZIP проекта](https://github.com/filyovscky/METACALYPSE/archive/refs/heads/main.zip) и распакуйте его либо выполните `git clone https://github.com/filyovscky/METACALYPSE.git`.
2. Установите [PowerShell 7](https://learn.microsoft.com/en-us/powershell/scripting/install/install-powershell). Для медиа также установите [ExifTool](https://exiftool.org/install.html), чтобы команда `exiftool` была доступна через `PATH`.
3. Откройте терминал в папке проекта и выполните:

```sh
pwsh -NoProfile -File ./metacalypse.ps1 -TargetPaths '/path/to/file.docx' '/path/to/photo.jpg'
```

Интеграция с меню файлового менеджера есть только в Windows.

Поддерживаются современные Office Open XML (`DOCX`, `XLSX`, `PPTX` и шаблоны/макросные варианты), изображения `JPG`, `PNG`, `WebP`, `GIF`, `TIFF`, `HEIC`, `HEIF`, `AVIF`, аудио `MP3`, `WAV`, `M4A` и видео `MP4`, `MOV`, `M4V`. Старые `DOC`/`XLS`/`PPT` и PDF не изменяются. [Форматы и ограничения](docs/SAFETY.ru.md).

Результат: `OK` = проверенная копия, `PARTIAL` = копия требует ручной проверки, `FAIL` = копия не создана, `UNSUPPORTED` = формат пропущен. Существующие результаты не перезаписываются. В отчёте перечисляются имена удалённых полей, но не прежние значения. Лог: `METACALYPSE-last-run.log` во временной папке системы.

**Важно:** это не гарантия анонимности. Текст, комментарии, правки, встроенные файлы и содержимое пикселей не очищаются. Перед отправкой проверьте копию. Исходники в обычном режиме остаются без изменений.

[Проверки и ограничения](docs/SAFETY.ru.md)

Проверка на своей системе: `pwsh -NoProfile -File ./tests/smoke.ps1`.
