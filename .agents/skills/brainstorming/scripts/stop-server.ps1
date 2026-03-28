# Stop the brainstorm server and clean up
# Usage: .\stop-server.ps1 <session_dir>
#
# Kills the server process. Only deletes session directory if it's
# under $env:TEMP (ephemeral). Persistent directories (.superpowers/) are
# kept so mockups can be reviewed later.

param(
    [Parameter(Mandatory)]
    [string]$SessionDir
)

$StateDir = Join-Path $SessionDir "state"
$PidFile  = Join-Path $StateDir "server.pid"

if (-not (Test-Path $PidFile)) {
    Write-Output '{"status": "not_running"}'
    exit 0
}

$Pid = Get-Content $PidFile -ErrorAction SilentlyContinue

if (-not $Pid) {
    Write-Output '{"status": "not_running"}'
    exit 0
}

# Try graceful stop first
$Proc = Get-Process -Id $Pid -ErrorAction SilentlyContinue
if ($Proc) {
    $Proc.CloseMainWindow() | Out-Null

    # Wait up to 2 seconds for graceful exit
    for ($i = 0; $i -lt 20; $i++) {
        if (-not (Get-Process -Id $Pid -ErrorAction SilentlyContinue)) { break }
        Start-Sleep -Milliseconds 100
    }

    # Escalate to force kill if still running
    if (Get-Process -Id $Pid -ErrorAction SilentlyContinue) {
        Stop-Process -Id $Pid -Force -ErrorAction SilentlyContinue
        Start-Sleep -Milliseconds 100
    }

    # Final check
    if (Get-Process -Id $Pid -ErrorAction SilentlyContinue) {
        Write-Output '{"status": "failed", "error": "process still running"}'
        exit 1
    }
}

# Cleanup
Remove-Item $PidFile -Force -ErrorAction SilentlyContinue
$LogFile = Join-Path $StateDir "server.log"
Remove-Item $LogFile -Force -ErrorAction SilentlyContinue

# Only delete ephemeral TEMP directories — keep .superpowers/ persistent
$TempPath = $env:TEMP.TrimEnd('\').TrimEnd('/')
if ($SessionDir.StartsWith($TempPath, [System.StringComparison]::OrdinalIgnoreCase)) {
    Remove-Item $SessionDir -Recurse -Force -ErrorAction SilentlyContinue
}

Write-Output '{"status": "stopped"}'
