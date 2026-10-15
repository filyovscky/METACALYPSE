[CmdletBinding()]
param([string[]]$TargetPaths, [switch]$QueueMode, [switch]$InPlace, [Parameter(ValueFromRemainingArguments = $true)][string[]]$MorePaths)

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem
$script:tempRoot = [System.IO.Path]::GetTempPath()
$script:queueRoot = Join-Path $script:tempRoot 'METACALYPSE-queue'
$script:logPath = Join-Path $script:tempRoot 'METACALYPSE-last-run.log'
$script:mutexName = 'Local\METACALYPSEQueue'
$script:ok = 0
$script:partial = 0
$script:fail = 0
$script:skip = 0

function Write-Stage([string]$Message) {
    $line = '[{0}] {1}' -f (Get-Date -Format 'HH:mm:ss'), $Message
    Write-Host $line
    Add-Content -LiteralPath $script:logPath -Value $line -Encoding UTF8
}

function Get-ExifTool {
    foreach ($name in @('exiftool', 'exiftool.exe')) {
        $command = Get-Command $name -ErrorAction SilentlyContinue
        if ($command) { return $command.Source }
    }
    foreach ($name in @('exiftool', 'exiftool.exe')) {
        $bundled = Join-Path $PSScriptRoot $name
        if (Test-Path -LiteralPath $bundled -PathType Leaf) { return $bundled }
    }
    $configPath = Join-Path $PSScriptRoot 'config.local.json'
    if (Test-Path -LiteralPath $configPath) {
        $config = Get-Content -LiteralPath $configPath -Raw -Encoding UTF8 | ConvertFrom-Json
        if ($config.exiftoolPath -and (Test-Path -LiteralPath $config.exiftoolPath -PathType Leaf)) {
            return $config.exiftoolPath
        }
    }
    throw 'ExifTool not found. Add exiftool to PATH, place it next to the scripts, or set exiftoolPath in config.local.json.'
}

function Invoke-ExifTool([string[]]$Arguments) {
    $tool = Get-ExifTool
    $ErrorActionPreference = 'Continue'
    $messages = & $tool @Arguments 2>&1
    $code = $LASTEXITCODE
    $output = @($messages | Where-Object { $_ -is [string] })
    $errors = @($messages | Where-Object { $_ -isnot [string] } | ForEach-Object { $_.ToString() })
    return @{ Output = $output; Error = ($errors -join ' '); Code = $code }
}

function Get-ExifTags([string]$Path) {
    $result = Invoke-ExifTool @('-j', '-G1', '-s', '-a', '-u', '--', $Path)
    if ($result.Code -ne 0) { throw ('ExifTool read failed: ' + $result.Error + ' ' + (($result.Output | Out-String).Trim())) }
    $record = ($result.Output -join "`n" | ConvertFrom-Json)
    if ($record -is [array]) { $record = $record[0] }
    $tags = @{}
    foreach ($property in $record.PSObject.Properties) {
        if ($property.Name -eq 'SourceFile' -or $property.Name -match '^(ExifTool|File|Composite|System|ICC_Profile):') { continue }
        $tags[$property.Name] = $property.Value
    }
    return ,$tags
}

function Get-AuditableTags([hashtable]$Tags) {
    $technical = '^(ImageWidth|ImageHeight|ImageSize|BitDepth|BitsPerSample|ColorType|Compression|Filter|Interlace|Palette|Transparency|Duration|MediaDuration|TrackDuration|PreviewDuration|SelectionDuration|TimeScale|MediaTimeScale|MovieHeaderVersion|MediaHeaderVersion|TrackHeaderVersion|MajorBrand|CompatibleBrands|MinorVersion|MatrixStructure|MediaData|MediaDataOffset|MediaDataSize|Free|NextTrackID|CurrentTime|PosterTime|PreviewTime|SelectionTime|PreferredRate|PreferredVolume|AverageBitrate|MaxBitrate|BufferSize|ChunkOffset|CompressorID|GraphicsMode|HandlerType|HandlerVendorID|MediaLanguageCode|OpColor|SampleSizes|SampleToChunk|SourceImageHeight|SourceImageWidth|TrackID|TrackLayer|TrackVolume|VideoFrameRate|XResolution|YResolution|Unknown_edts|Unknown_esds)$'
    $auditable = @{}
    foreach ($name in $Tags.Keys) {
        $group, $tag = $name -split ':', 2
        if ($group -match '^(PNG|QuickTime|Track[0-9]+|RIFF|JFIF)$' -and $tag -match $technical) { continue }
        $auditable[$name] = $Tags[$name]
    }
    return ,$auditable
}

function Get-ZipText($Entry) {
    $reader = New-Object System.IO.StreamReader($Entry.Open(), [System.Text.Encoding]::UTF8)
    try { return $reader.ReadToEnd() } finally { $reader.Dispose() }
}

function Set-ZipText($Zip, [string]$Name, [string]$Text) {
    $existing = $Zip.GetEntry($Name)
    if ($existing) { $existing.Delete() }
    $entry = $Zip.CreateEntry($Name, [System.IO.Compression.CompressionLevel]::Optimal)
    $writer = New-Object System.IO.StreamWriter($entry.Open(), (New-Object System.Text.UTF8Encoding($false)))
    try { $writer.Write($Text) } finally { $writer.Dispose() }
}

function Get-SafeXml([string]$Text) {
    $settings = New-Object System.Xml.XmlReaderSettings
    $settings.DtdProcessing = [System.Xml.DtdProcessing]::Prohibit
    $settings.XmlResolver = $null
    $document = New-Object System.Xml.XmlDocument
    $document.XmlResolver = $null
    $source = New-Object System.IO.StringReader($Text)
    $reader = [System.Xml.XmlReader]::Create($source, $settings)
    try { $document.Load($reader) } finally { $reader.Dispose(); $source.Dispose() }
    return $document
}

function Clean-OpenXml([string]$Path) {
    $parts = @('docProps/core.xml', 'docProps/app.xml', 'docProps/custom.xml', 'docProps/thumbnail.jpeg', 'docProps/thumbnail.png')
    $folder = [System.IO.Path]::GetDirectoryName($Path)
    $temp = Join-Path $folder ('.metacalypse-' + [guid]::NewGuid().ToString('N') + '.tmp')
    $backup = Join-Path $folder ('.metacalypse-' + [guid]::NewGuid().ToString('N') + '.bak')
    $removed = @()
    $changed = $false
    [System.IO.File]::Copy($Path, $temp)
    try {
        $zip = [System.IO.Compression.ZipFile]::Open($temp, [System.IO.Compression.ZipArchiveMode]::Update)
        try {
            if (-not $zip.GetEntry('[Content_Types].xml')) { throw 'Invalid Office package.' }
            foreach ($name in $parts) {
                $entry = $zip.GetEntry($name)
                if (-not $entry) { continue }
                if ($name -like '*thumbnail*') { $removed += 'Thumbnail' }
                else {
                    $xml = Get-SafeXml (Get-ZipText $entry)
                    foreach ($node in $xml.DocumentElement.ChildNodes) {
                        if ($node.NodeType -ne [System.Xml.XmlNodeType]::Element) { continue }
                        $label = $node.LocalName
                        if ($label -eq 'property' -and $node.HasAttribute('name')) { $label = $node.GetAttribute('name') }
                        if (-not [string]::IsNullOrWhiteSpace($node.InnerText)) { $removed += $label }
                    }
                }
                $entry.Delete()
                $changed = $true
            }
            foreach ($name in @('[Content_Types].xml', '_rels/.rels')) {
                $entry = $zip.GetEntry($name)
                if (-not $entry) { continue }
                $xml = Get-SafeXml (Get-ZipText $entry)
                $updated = $false
                foreach ($node in @($xml.DocumentElement.ChildNodes)) {
                    if ($node.NodeType -ne [System.Xml.XmlNodeType]::Element) { continue }
                    $target = if ($name -eq '[Content_Types].xml') { $node.GetAttribute('PartName').TrimStart('/') } else { $node.GetAttribute('Target').TrimStart('/') }
                    if ($parts -contains $target) { [void]$xml.DocumentElement.RemoveChild($node); $updated = $true }
                }
                if ($updated) { Set-ZipText $zip $name $xml.OuterXml; $changed = $true }
            }
        } finally { $zip.Dispose() }
        if ($changed) {
            $check = [System.IO.Compression.ZipFile]::OpenRead($temp)
            try {
                if (-not $check.GetEntry('[Content_Types].xml')) { throw 'Office package verification failed.' }
                foreach ($name in $parts) { if ($check.GetEntry($name)) { throw ('Office property remains: ' + $name) } }
            } finally { $check.Dispose() }
            [System.IO.File]::Replace($temp, $Path, $backup)
        }
        return $removed
    } finally {
        Remove-Item -LiteralPath $temp -Force -ErrorAction SilentlyContinue
        Remove-Item -LiteralPath $backup -Force -ErrorAction SilentlyContinue
    }
}

function Get-ZipEntryHash($Entry) {
    $sha = [System.Security.Cryptography.SHA256]::Create()
    $stream = $Entry.Open()
    try { return [Convert]::ToBase64String($sha.ComputeHash($stream)) }
    finally { $stream.Dispose(); $sha.Dispose() }
}

function Assert-OfficeCopy([string]$Original, [string]$Copy) {
    $removedParts = @('docProps/core.xml', 'docProps/app.xml', 'docProps/custom.xml', 'docProps/thumbnail.jpeg', 'docProps/thumbnail.png')
    $changedParts = @('[Content_Types].xml', '_rels/.rels')
    $sourceZip = [System.IO.Compression.ZipFile]::OpenRead($Original)
    try {
        $cleanZip = [System.IO.Compression.ZipFile]::OpenRead($Copy)
        try {
            if (-not $sourceZip.GetEntry('[Content_Types].xml') -or -not $cleanZip.GetEntry('[Content_Types].xml')) {
                throw 'Office package is missing [Content_Types].xml.'
            }
            foreach ($part in $removedParts) {
                if ($cleanZip.GetEntry($part)) { throw ('Property part remains: ' + $part) }
            }
            foreach ($part in $changedParts) {
                $entry = $cleanZip.GetEntry($part)
                if (-not $entry) { continue }
                $xml = Get-SafeXml (Get-ZipText $entry)
                foreach ($node in $xml.DocumentElement.ChildNodes) {
                    if ($node.NodeType -ne [System.Xml.XmlNodeType]::Element) { continue }
                    $target = if ($part -eq '[Content_Types].xml') { $node.GetAttribute('PartName').TrimStart('/') } else { $node.GetAttribute('Target').TrimStart('/') }
                    if ($removedParts -contains $target) { throw ('Dangling Office relationship: ' + $target) }
                }
            }
            $sourceEntries = @($sourceZip.Entries | Where-Object { $removedParts -notcontains $_.FullName })
            if ($cleanZip.Entries.Count -ne $sourceEntries.Count) { throw 'Office package entry count changed unexpectedly.' }
            foreach ($entry in $sourceEntries) {
                $other = $cleanZip.GetEntry($entry.FullName)
                if (-not $other) { throw ('Office content missing: ' + $entry.FullName) }
                if ($changedParts -contains $entry.FullName) { continue }
                if ((Get-ZipEntryHash $entry) -ne (Get-ZipEntryHash $other)) {
                    throw ('Office content changed: ' + $entry.FullName)
                }
            }
        } finally { $cleanZip.Dispose() }
    } finally { $sourceZip.Dispose() }
}

function Get-EmbeddedMediaWarnings([string]$Path) {
    $warnings = @()
    $zip = [System.IO.Compression.ZipFile]::OpenRead($Path)
    try {
        foreach ($entry in $zip.Entries) {
            if ($entry.FullName -notmatch '^(word|ppt|xl)/media/.+\.(jpe?g|png|webp|gif|tiff?|heic|heif|avif)$') { continue }
            $extension = [System.IO.Path]::GetExtension($entry.FullName)
            $temp = Join-Path $script:tempRoot ('METACALYPSE-media-' + [guid]::NewGuid().ToString('N') + $extension)
            try {
                $source = $entry.Open()
                $destination = [System.IO.File]::Create($temp)
                try { $source.CopyTo($destination) } finally { $destination.Dispose(); $source.Dispose() }
                $tags = Get-AuditableTags (Get-ExifTags $temp)
                if ($tags.Count -gt 0) {
                    $warnings += ($entry.FullName + ': ' + (($tags.Keys | Sort-Object) -join ', '))
                }
            } catch {
                $warnings += ($entry.FullName + ': audit failed (' + $_.Exception.Message + ')')
            } finally { Remove-Item -LiteralPath $temp -Force -ErrorAction SilentlyContinue }
        }
    } finally { $zip.Dispose() }
    return $warnings
}

function New-WorkingCopy([string]$Path) {
    $folder = [System.IO.Path]::GetDirectoryName($Path)
    $extension = [System.IO.Path]::GetExtension($Path)
    $work = Join-Path $folder ('.metacalypse-' + [guid]::NewGuid().ToString('N') + $extension)
    $complete = $false
    try {
        $source = [System.IO.File]::Open($Path, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, [System.IO.FileShare]::Read)
        try {
            $destination = [System.IO.File]::Open($work, [System.IO.FileMode]::CreateNew, [System.IO.FileAccess]::Write, [System.IO.FileShare]::None)
            try { $source.CopyTo($destination) } finally { $destination.Dispose() }
        } finally { $source.Dispose() }
        $complete = $true
        return $work
    } finally {
        if (-not $complete) { Remove-Item -LiteralPath $work -Force -ErrorAction SilentlyContinue }
    }
}

function Publish-Copy([string]$WorkingCopy, [string]$Original, [string]$Suffix) {
    if ($InPlace -and $Suffix -eq '_clean') {
        $currentHash = (Get-FileHash -LiteralPath $Original -Algorithm SHA256).Hash
        if ($currentHash -ne $script:sourceHash) {
            throw 'Original changed during cleaning. Replacement cancelled.'
        }
        [System.IO.File]::Replace($WorkingCopy, $Original, [System.Management.Automation.Language.NullString]::Value)
        return $Original
    }
    $folder = [System.IO.Path]::GetDirectoryName($Original)
    $stem = [System.IO.Path]::GetFileNameWithoutExtension($Original)
    $extension = [System.IO.Path]::GetExtension($Original)
    for ($number = 0; $number -lt 10000; $number++) {
        $postfix = if ($number -eq 0) { '' } else { '-' + ($number + 1) }
        $target = Join-Path $folder ($stem + $Suffix + $postfix + $extension)
        try {
            [System.IO.File]::Move($WorkingCopy, $target)
            return $target
        } catch [System.IO.IOException] {
            if (Test-Path -LiteralPath $target) { continue }
            throw
        }
    }
    throw 'Could not find an available output filename.'
}

function Get-MediaShape([string]$Path) {
    $result = Invoke-ExifTool @('-j', '-n', '-s', '-FileType', '-ImageWidth', '-ImageHeight', '-Duration', '--', $Path)
    if ($result.Code -ne 0) { throw ('Media verification failed: ' + $result.Error) }
    $record = ($result.Output -join "`n" | ConvertFrom-Json)
    if ($record -is [array]) { $record = $record[0] }
    if (-not $record.FileType) { throw 'Media verification failed: unknown file type.' }
    return $record
}

function Assert-MediaCopy([string]$Original, [string]$Copy) {
    if ((Get-Item -LiteralPath $Copy).Length -eq 0) { throw 'Media verification failed: empty output file.' }
    $before = Get-MediaShape $Original
    $after = Get-MediaShape $Copy
    foreach ($property in @('FileType', 'ImageWidth', 'ImageHeight')) {
        if ($before.$property -ne $after.$property) {
            throw ('Media verification failed: ' + $property + ' changed.')
        }
    }
    if ($before.Duration -is [ValueType] -and $after.Duration -is [ValueType]) {
        $difference = [math]::Abs([double]$before.Duration - [double]$after.Duration)
        if ($difference -gt [math]::Max(1.0, [double]$before.Duration * 0.01)) {
            throw 'Media verification failed: duration changed.'
        }
    }
}

function Show-Removed([string[]]$Names) {
    if ($Names.Count -eq 0) { Write-Stage '  Removed fields: none detected.' }
    else { Write-Stage ('  Removed fields: ' + (($Names | Sort-Object -Unique) -join ', ')) }
}

function Process-File([string]$Path) {
    Write-Stage ('Processing: ' + $Path)
    if ([System.IO.Path]::GetFileName($Path).StartsWith('~$')) { Write-Stage '[SKIP] Office lock file.'; $script:skip++; return }
    $ext = [System.IO.Path]::GetExtension($Path).ToLowerInvariant()
    $office = @('.docx', '.docm', '.dotx', '.dotm', '.xlsx', '.xlsm', '.xltx', '.xltm', '.pptx', '.pptm', '.potx', '.potm')
    $media = @('.jpg', '.jpeg', '.png', '.webp', '.gif', '.tif', '.tiff', '.heic', '.heif', '.avif', '.mp3', '.wav', '.mp4', '.mov', '.m4v', '.m4a')
    if ($office -notcontains $ext -and $media -notcontains $ext) {
        Write-Stage ('[UNSUPPORTED] No safe cleaner for ' + $ext + '. File unchanged.')
        $script:skip++
        return
    }
    $workingCopy = $null
    try {
        $workingCopy = New-WorkingCopy $Path
        if ($InPlace) { $script:sourceHash = (Get-FileHash -LiteralPath $workingCopy -Algorithm SHA256).Hash }
        if ($office -contains $ext) {
            Write-Stage '  Cleaning Office package properties.'
            $removed = @(Clean-OpenXml $workingCopy)
            Write-Stage '  Verifying Office content.'
            Assert-OfficeCopy $Path $workingCopy
            $embeddedWarnings = @(Get-EmbeddedMediaWarnings $workingCopy)
            Show-Removed $removed
            if ($embeddedWarnings.Count -gt 0) {
                foreach ($warning in $embeddedWarnings) { Write-Stage ('  Embedded media: ' + $warning) }
                $output = Publish-Copy $workingCopy $Path '_partial'
                Write-Stage ('[PARTIAL] Embedded media may contain metadata. Copy: ' + $output)
                $script:partial++
            } else {
                $output = Publish-Copy $workingCopy $Path '_clean'
                Write-Stage ('[OK] Office content verified. Cleaned file: ' + $output)
                $script:ok++
            }
        } elseif ($media -contains $ext) {
            Write-Stage '  Reading media metadata.'
            $beforeAll = Get-ExifTags $workingCopy
            $before = Get-AuditableTags $beforeAll
            Write-Stage ('  Technical/structural fields excluded from identity check: ' + ($beforeAll.Count - $before.Count))
            if ($before.Count -gt 0) {
                $arguments = @('-all=', '-overwrite_original')
                if ($ext -in @('.jpg', '.jpeg', '.png', '.tif', '.tiff', '.webp', '.heic', '.heif', '.avif')) {
                    $arguments += '--icc_profile:all'
                }
                $arguments += @('--', $workingCopy)
                $result = Invoke-ExifTool $arguments
                if ($result.Code -ne 0) { throw ('ExifTool write failed: ' + $result.Error + ' ' + (($result.Output | Out-String).Trim())) }
            }
            $after = Get-AuditableTags (Get-ExifTags $workingCopy)
            $removed = @($before.Keys | Where-Object { -not $after.ContainsKey($_) })
            Show-Removed $removed
            Write-Stage '  Verifying media format and dimensions.'
            Assert-MediaCopy $Path $workingCopy
            if ($after.Count -gt 0) {
                Write-Stage ('  Remaining fields: ' + (($after.Keys | Sort-Object) -join ', '))
                $output = Publish-Copy $workingCopy $Path '_partial'
                Write-Stage ('[PARTIAL] Copy needs review: ' + $output)
                $script:partial++
            } else {
                $output = Publish-Copy $workingCopy $Path '_clean'
                Write-Stage ('[OK] Media verified. Cleaned file: ' + $output)
                $script:ok++
            }
        }
    } catch { Write-Stage ('[FAIL] ' + $_.Exception.Message); $script:fail++ }
    finally {
        if ($workingCopy -and (Test-Path -LiteralPath $workingCopy)) {
            Remove-Item -LiteralPath $workingCopy -Force -ErrorAction SilentlyContinue
        }
    }
}

function Process-Target([string]$Path) {
    if (-not (Test-Path -LiteralPath $Path)) { Write-Stage ('[FAIL] Not found: ' + $Path); $script:fail++; return }
    $item = Get-Item -LiteralPath $Path
    if ($item.PSIsContainer) {
        Write-Stage ('Folder: ' + $item.FullName)
        try {
            $files = @(Get-ChildItem -LiteralPath $item.FullName -Recurse -File -ErrorAction Stop | Where-Object {
                $_.Name -notmatch '_(clean|partial)(-[0-9]+)?\.[^.]+$' -and $_.Name -notlike '.metacalypse-*' -and $_.Name -notlike '.killmetadata-*'
            })
        } catch {
            Write-Stage ('[FAIL] Could not enumerate folder: ' + $_.Exception.Message)
            $script:fail++
            return
        }
        Write-Stage ('  Source files: ' + $files.Count)
        foreach ($file in $files) { Process-File $file.FullName }
    } else { Process-File $item.FullName }
}

function Process-Queue {
    $quietSince = Get-Date
    while ($true) {
        $entries = @(Get-ChildItem -LiteralPath $script:queueRoot -Filter '*.path' -File -ErrorAction SilentlyContinue | Sort-Object CreationTimeUtc, Name)
        if ($entries.Count -gt 0) {
            foreach ($entry in $entries) {
                try { Process-Target ([System.IO.File]::ReadAllText($entry.FullName, [System.Text.Encoding]::UTF8)) }
                catch { Write-Stage ('[FAIL] ' + $_.Exception.Message); $script:fail++ }
                finally { Remove-Item -LiteralPath $entry.FullName -Force -ErrorAction SilentlyContinue }
            }
            $quietSince = Get-Date
            continue
        }
        if (((Get-Date) - $quietSince).TotalMilliseconds -lt 1500) { Start-Sleep -Milliseconds 200; continue }
        $mutex = New-Object System.Threading.Mutex($false, $script:mutexName)
        try {
            try { [void]$mutex.WaitOne() } catch [System.Threading.AbandonedMutexException] { }
            if (@(Get-ChildItem -LiteralPath $script:queueRoot -Filter '*.path' -File -ErrorAction SilentlyContinue).Count -gt 0) {
                $quietSince = Get-Date
                continue
            }
            Remove-Item -LiteralPath (Join-Path $script:queueRoot 'worker.pid') -Force -ErrorAction SilentlyContinue
            break
        } finally { $mutex.ReleaseMutex(); $mutex.Dispose() }
    }
}

'' | Set-Content -LiteralPath $script:logPath -Encoding UTF8
Write-Stage 'METACALYPSE started.'
if ($InPlace) { Write-Stage 'Overwrite mode: originals replaced only after successful verification; partial results saved separately.' }
try {
    if ($QueueMode) { Write-Stage 'Collecting selected files into one run.'; Process-Queue }
    elseif ($TargetPaths -or $MorePaths) { foreach ($path in @($TargetPaths) + @($MorePaths)) { if ($path) { Process-Target $path } } }
    else { throw 'No files or folders were supplied.' }
} catch { Write-Stage ('[FAIL] ' + $_.Exception.Message); $script:fail++ }
finally {
    if ($QueueMode) {
        $mutex = New-Object System.Threading.Mutex($false, $script:mutexName)
        try {
            try { [void]$mutex.WaitOne() } catch [System.Threading.AbandonedMutexException] { }
            $pidFile = Join-Path $script:queueRoot 'worker.pid'
            if ((Test-Path -LiteralPath $pidFile) -and [System.IO.File]::ReadAllText($pidFile) -eq [string]$PID) {
                Remove-Item -LiteralPath $pidFile -Force -ErrorAction SilentlyContinue
            }
        } finally { $mutex.ReleaseMutex(); $mutex.Dispose() }
    }
}
Write-Stage ('Done. Clean: {0}; Partial: {1}; Failed: {2}; Unsupported/skipped: {3}' -f $script:ok, $script:partial, $script:fail, $script:skip)
Write-Stage ('Log: ' + $script:logPath)
if (-not $QueueMode -and ($script:fail -gt 0 -or $script:partial -gt 0)) { exit 1 }
