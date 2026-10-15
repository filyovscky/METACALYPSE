$ErrorActionPreference = 'Stop'
if (-not ($PSVersionTable.PSEdition -eq 'Desktop' -or $IsWindows)) {
    throw 'Explorer context-menu integration is available only on Windows.'
}
$launcher = Join-Path $PSScriptRoot 'queue-selection.ps1'
$worker = Join-Path $PSScriptRoot 'metacalypse.ps1'
if (-not (Test-Path -LiteralPath $launcher) -or -not (Test-Path -LiteralPath $worker)) {
    throw 'Required METACALYPSE scripts are missing.'
}
$powershell = (Get-Command powershell.exe -ErrorAction Stop).Source
$base = 'Registry::HKEY_CURRENT_USER\Software\Classes'
foreach ($path in @('*\shell\KillMetadata', 'Directory\shell\KillMetadata', 'Directory\Background\shell\KillMetadata')) {
    Remove-Item -LiteralPath (Join-Path $base $path) -Recurse -Force -ErrorAction SilentlyContinue
}
foreach ($entry in @(
    @{ Key = '*\shell\METACALYPSE'; Label = 'METACALYPSE - Clean metadata (copy)'; Placeholder = '%1'; Multi = $true },
    @{ Key = 'Directory\shell\METACALYPSE'; Label = 'METACALYPSE - Clean metadata (copies)'; Placeholder = '%1'; Multi = $false },
    @{ Key = 'Directory\Background\shell\METACALYPSE'; Label = 'METACALYPSE - Clean metadata (copies)'; Placeholder = '%V'; Multi = $false }
)) {
    $key = Join-Path $base $entry.Key
    $command = Join-Path $key 'command'
    New-Item -Path $command -Force | Out-Null
    Set-Item -LiteralPath $key -Value $entry.Label
    if ($entry.Multi) { New-ItemProperty -LiteralPath $key -Name 'MultiSelectModel' -PropertyType String -Value 'Player' -Force | Out-Null }
    $line = '"{0}" -NoLogo -NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File "{1}" -TargetPath "{2}"' -f $powershell, $launcher, $entry.Placeholder
    Set-Item -LiteralPath $command -Value $line
}
Write-Host 'METACALYPSE context menu installed for current user.'
Write-Host 'Right-click selected files to create cleaned copies in one window.'
