[CmdletBinding()]
param([Parameter(Mandatory = $true)][string]$TargetPath)

$ErrorActionPreference = 'Stop'
$queueRoot = Join-Path ([System.IO.Path]::GetTempPath()) 'METACALYPSE-queue'
$mutex = New-Object System.Threading.Mutex($false, 'Local\METACALYPSEQueue')
$locked = $false
try {
    try { $locked = $mutex.WaitOne(10000) }
    catch [System.Threading.AbandonedMutexException] { $locked = $true }
    if (-not $locked) { throw 'Queue lock timeout.' }
    [void][System.IO.Directory]::CreateDirectory($queueRoot)
    $name = [guid]::NewGuid().ToString('N')
    $pending = Join-Path $queueRoot ($name + '.tmp')
    $ready = Join-Path $queueRoot ($name + '.path')
    [System.IO.File]::WriteAllText($pending, $TargetPath, (New-Object System.Text.UTF8Encoding($false)))
    [System.IO.File]::Move($pending, $ready)

    $pidFile = Join-Path $queueRoot 'worker.pid'
    $workerAlive = $false
    if (Test-Path -LiteralPath $pidFile) {
        $workerId = 0
        if ([int]::TryParse([System.IO.File]::ReadAllText($pidFile), [ref]$workerId)) {
            $workerAlive = $null -ne (Get-Process -Id $workerId -ErrorAction SilentlyContinue)
        }
    }
    if (-not $workerAlive) {
        $powershell = (Get-Command powershell.exe -ErrorAction Stop).Source
        $script = Join-Path $PSScriptRoot 'metacalypse.ps1'
        $arguments = '-NoLogo -NoProfile -NoExit -ExecutionPolicy Bypass -File "' + $script + '" -QueueMode'
        $worker = Start-Process -FilePath $powershell -ArgumentList $arguments -WorkingDirectory $PSScriptRoot -WindowStyle Normal -PassThru
        [System.IO.File]::WriteAllText($pidFile, [string]$worker.Id)
    }
} catch {
    $errorLog = Join-Path ([System.IO.Path]::GetTempPath()) 'METACALYPSE-launch-error.log'
    Add-Content -LiteralPath $errorLog -Value ('[{0}] {1}: {2}' -f (Get-Date), $TargetPath, $_.Exception.Message) -Encoding UTF8
    throw
} finally {
    if ($locked) { $mutex.ReleaseMutex() }
    $mutex.Dispose()
}
