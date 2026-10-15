$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem

$root = Join-Path ([System.IO.Path]::GetTempPath()) ('METACALYPSE-smoke-' + [guid]::NewGuid().ToString('N'))
[void][System.IO.Directory]::CreateDirectory($root)
$source = Join-Path $root 'sample.docx'
$clean = Join-Path $root 'sample_clean.docx'
$second = Join-Path $root 'sample_clean-2.docx'

function Add-Part($Archive, [string]$Name, [string]$Content) {
    $entry = $Archive.CreateEntry($Name)
    $writer = [System.IO.StreamWriter]::new($entry.Open(), [System.Text.UTF8Encoding]::new($false))
    try { $writer.Write($Content) } finally { $writer.Dispose() }
}

try {
    $archive = [System.IO.Compression.ZipFile]::Open($source, [System.IO.Compression.ZipArchiveMode]::Create)
    try {
        Add-Part $archive '[Content_Types].xml' '<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types"><Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/><Default Extension="xml" ContentType="application/xml"/><Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/><Override PartName="/docProps/core.xml" ContentType="application/vnd.openxmlformats-package.core-properties+xml"/></Types>'
        Add-Part $archive '_rels/.rels' '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/><Relationship Id="rId2" Type="http://schemas.openxmlformats.org/package/2006/relationships/metadata/core-properties" Target="docProps/core.xml"/></Relationships>'
        Add-Part $archive 'word/document.xml' '<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:body><w:p><w:r><w:t>Test</w:t></w:r></w:p></w:body></w:document>'
        Add-Part $archive 'docProps/core.xml' '<cp:coreProperties xmlns:cp="http://schemas.openxmlformats.org/package/2006/metadata/core-properties" xmlns:dc="http://purl.org/dc/elements/1.1/"><dc:creator>PrivateAuthor</dc:creator></cp:coreProperties>'
    } finally { $archive.Dispose() }

    $sourceHash = (Get-FileHash -LiteralPath $source -Algorithm SHA256).Hash
    $cleaner = Join-Path (Split-Path -Parent $PSScriptRoot) 'metacalypse.ps1'
    & $cleaner -TargetPaths $source
    if (-not (Test-Path -LiteralPath $clean)) { throw 'Clean copy was not created.' }
    if ((Get-FileHash -LiteralPath $source -Algorithm SHA256).Hash -ne $sourceHash) { throw 'Source file changed.' }

    $archive = [System.IO.Compression.ZipFile]::OpenRead($clean)
    try {
        if ($archive.GetEntry('docProps/core.xml')) { throw 'Core properties remain.' }
        if (-not $archive.GetEntry('word/document.xml')) { throw 'Document content is missing.' }
    } finally { $archive.Dispose() }

    & $cleaner -TargetPaths $source
    if (-not (Test-Path -LiteralPath $second)) { throw 'Second copy was not created.' }
    if ((Get-FileHash -LiteralPath $source -Algorithm SHA256).Hash -ne $sourceHash) { throw 'Source file changed after second run.' }
    Write-Host 'METACALYPSE smoke test passed.'
} finally {
    Remove-Item -LiteralPath $root -Recurse -Force -ErrorAction SilentlyContinue
}
