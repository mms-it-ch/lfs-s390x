# Puts build\NAME.ins together in WSL (tools/mkNAME.sh) and loads it into
# Hercules without a panel. What Linux said ends up in build\hercules.log and
# on the screen - between Hercules' own report of every page fault.
#
#   .\run\hercules.ps1                       stage 0: the kernel and busybox
#
# -Name picks build\NAME.ins through run\NAME.rc, -Machine the configuration.
param(
    [switch] $NoBuild,
    [string] $Name = "stage0",
    [string] $Machine = "linux",
    # hercules.exe: $env:HERCULES, or one on the path
    [string] $Hercules = $(if ($env:HERCULES) { $env:HERCULES } else { "hercules.exe" }),
    [int] $Seconds = 90
)

$root = Split-Path -Parent $PSScriptRoot
$wslRoot = "/mnt/" + $root.Substring(0, 1).ToLower() + ($root.Substring(2) -replace "\\", "/")

if (-not $NoBuild) {
    wsl -d Ubuntu -e bash "$wslRoot/tools/mk$Name.sh"
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
}

$log = Join-Path $root "build\hercules.log"
$process = Start-Process -FilePath $Hercules `
    -ArgumentList "-d", "-f", "$Machine.cnf", "-r", "$Name.rc" `
    -WorkingDirectory $PSScriptRoot -NoNewWindow -PassThru `
    -RedirectStandardOutput $log -RedirectStandardError (Join-Path $root "build\hercules.err")

# Without a panel "quit" does not end the process on Windows, so it is ended
# from here once the script has had its time
if (-not $process.WaitForExit($Seconds * 1000)) { $process.Kill() }

# Hercules' own messages all carry an HHC number; what is left is the program
# - and its errors, the program check and the wait state it ended in
Get-Content $log | Where-Object { $_ -notmatch "HHC\d{5}[A-Z]" -or $_ -match "HHC\d{5}E|HHC008(01|09)|HHC02324" } |
    ForEach-Object { $_ -replace "^\d\d:\d\d:\d\d ", "" }
