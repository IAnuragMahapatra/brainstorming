# Start the brainstorm server and output connection info
# Usage: .\start-server.ps1 [--project-dir <path>] [--bind-host <bind-host>] [--url-host <display-host>] [--foreground]
#
# Starts server on a random high port, outputs JSON with URL.
# Each session gets its own directory to avoid conflicts.
#
# Options:
#   --project-dir <path>   Store session files under <path>/.superpowers/brainstorm/
#                          instead of $env:TEMP. Files persist after server stops.
#   --host <bind-host>     Host/interface to bind (default: 127.0.0.1).
#   --url-host <host>      Hostname shown in returned URL JSON.
#   --foreground           Run server in the current terminal (blocks).

param(
    [string]$ProjectDir = "",
    [string]$BindHost = "127.0.0.1",
    [string]$UrlHost = "",
    [switch]$Foreground
)

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition

# Resolve URL host
if (-not $UrlHost) {
    if ($BindHost -eq "127.0.0.1" -or $BindHost -eq "localhost") {
        $UrlHost = "localhost"
    }
    else {
        $UrlHost = $BindHost
    }
}

# Generate unique session ID
$SessionId = "$PID-$([DateTimeOffset]::UtcNow.ToUnixTimeSeconds())"

if ($ProjectDir) {
    $SessionDir = Join-Path $ProjectDir ".superpowers\brainstorm\$SessionId"
}
else {
    $SessionDir = Join-Path $env:TEMP "brainstorm-$SessionId"
}

$StateDir = Join-Path $SessionDir "state"
$ContentDir = Join-Path $SessionDir "content"
$PidFile = Join-Path $StateDir "server.pid"
$LogFile = Join-Path $StateDir "server.log"

# Create directories
New-Item -ItemType Directory -Force -Path $ContentDir | Out-Null
New-Item -ItemType Directory -Force -Path $StateDir   | Out-Null

# Kill any existing server using a stale PID file
if (Test-Path $PidFile) {
    $OldPid = Get-Content $PidFile -ErrorAction SilentlyContinue
    if ($OldPid) {
        Stop-Process -Id $OldPid -Force -ErrorAction SilentlyContinue
    }
    Remove-Item $PidFile -Force -ErrorAction SilentlyContinue
}

# Environment for the Node server
$Env = @{
    BRAINSTORM_DIR       = $SessionDir
    BRAINSTORM_HOST      = $BindHost
    BRAINSTORM_URL_HOST  = $UrlHost
    BRAINSTORM_OWNER_PID = "$PID"
}

$ServerScript = Join-Path $ScriptDir "server.cjs"

if ($Foreground) {
    # Blocking mode — write our own PID so stop-server.ps1 can kill us
    $PID | Set-Content $PidFile
    $env:BRAINSTORM_DIR = $Env.BRAINSTORM_DIR
    $env:BRAINSTORM_HOST = $Env.BRAINSTORM_HOST
    $env:BRAINSTORM_URL_HOST = $Env.BRAINSTORM_URL_HOST
    $env:BRAINSTORM_OWNER_PID = $Env.BRAINSTORM_OWNER_PID
    & node $ServerScript
    exit $LASTEXITCODE
}

# Background mode: launch node as a detached job, capture stdout to log
$NodeArgs = @($ServerScript)

# Start the process detached, redirect stdout to log
$ProcArgs = @{
    FilePath               = "node"
    ArgumentList           = $NodeArgs
    RedirectStandardOutput = $LogFile
    RedirectStandardError  = $LogFile
    NoNewWindow            = $true
    PassThru               = $true
}

$env:BRAINSTORM_DIR = $Env.BRAINSTORM_DIR
$env:BRAINSTORM_HOST = $Env.BRAINSTORM_HOST
$env:BRAINSTORM_URL_HOST = $Env.BRAINSTORM_URL_HOST
$env:BRAINSTORM_OWNER_PID = $Env.BRAINSTORM_OWNER_PID

$Proc = Start-Process @ProcArgs
$ServerPid = $Proc.Id
$ServerPid | Set-Content $PidFile

# Wait up to 5 seconds for "server-started" in the log
$Started = $false
for ($i = 0; $i -lt 50; $i++) {
    Start-Sleep -Milliseconds 100
    if (Test-Path $LogFile) {
        $LogContent = Get-Content $LogFile -Raw -ErrorAction SilentlyContinue
        if ($LogContent -match "server-started") {
            # Confirm process is still alive
            $Alive = $true
            for ($j = 0; $j -lt 20; $j++) {
                if (-not (Get-Process -Id $ServerPid -ErrorAction SilentlyContinue)) {
                    $Alive = $false
                    break
                }
                Start-Sleep -Milliseconds 100
            }
            if (-not $Alive) {
                $ProjectDirFlag = if ($ProjectDir) { " --project-dir `"$ProjectDir`"" } else { "" }
                Write-Output "{`"error`": `"Server started but was killed. Retry with: $ScriptDir\start-server.ps1$ProjectDirFlag --bind-host $BindHost --url-host $UrlHost --foreground`"}"
                exit 1
            }
            # Print the server-started JSON line
            $LogContent -split "`n" | Where-Object { $_ -match "server-started" } | Select-Object -First 1 | Write-Output
            $Started = $true
            break
        }
    }
}

if (-not $Started) {
    Write-Output '{"error": "Server failed to start within 5 seconds"}'
    exit 1
}
