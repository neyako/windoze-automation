# Shared helpers. Dot-source from setup.ps1 and bench scripts. Windows PowerShell 5.1 compatible.

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'   # Invoke-WebRequest is 10x slower with the progress bar

$BenchRoot = 'C:\Bench'

function Write-Step($msg) { Write-Host "`n==> $msg" -ForegroundColor Cyan }
function Write-Warn($msg) { Write-Host "  ! $msg" -ForegroundColor Yellow }

# Starts powershell.exe with these arguments in Windows Terminal (inbox on Win11), else in the old console.
function Start-InTerminal([string]$Arguments, [switch]$Elevated) {
    $ps = "-NoProfile -ExecutionPolicy Bypass $Arguments"
    $run = if (Get-Command wt.exe -ErrorAction SilentlyContinue) { @{ FilePath = 'wt.exe'; ArgumentList = "powershell.exe $ps" } }
           else { @{ FilePath = 'powershell.exe'; ArgumentList = $ps } }
    if ($Elevated) { $run.Verb = 'RunAs' }
    Start-Process @run
}

# Keeps the system and display awake while this process runs. Does not change any power setting.
function Enable-KeepAwake {
    if (-not ('Win32.Power' -as [type])) {
        Add-Type -Namespace Win32 -Name Power -MemberDefinition '[DllImport("kernel32.dll")] public static extern uint SetThreadExecutionState(uint esFlags);'
    }
    # ES_CONTINUOUS | ES_SYSTEM_REQUIRED | ES_DISPLAY_REQUIRED
    [void][Win32.Power]::SetThreadExecutionState([uint32]'0x80000003')
}

# Friendly model name. Lenovo puts the marketing name in Version and a type code in Model.
function Get-LaptopModel {
    $cs = Get-CimInstance Win32_ComputerSystem
    $name = $cs.Model
    if ($cs.Manufacturer -match 'LENOVO') { $name = (Get-CimInstance Win32_ComputerSystemProduct).Version }
    ("$($cs.Manufacturer.Split(' ')[0]) $name" -replace '[\\/:*?"<>|]', '').Trim()
}

function Get-ResultsDir {
    $dir = Join-Path $BenchRoot "results\$(Get-LaptopModel)"
    New-Item -ItemType Directory -Force $dir | Out-Null
    $dir
}

# The SSD copy of this repo, found by its bench folder on any non-C: drive.
function Get-SsdRoot {
    foreach ($d in Get-PSDrive -PSProvider FileSystem) {
        if ($d.Root -eq 'C:\') { continue }
        $hit = Get-ChildItem "$($d.Root)*\bench\Cinebench.ps1" -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($hit) { return $hit.Directory.Parent.FullName }
    }
}

# Anything that reboots or swaps runtimes mid-test sends Cinebench a close request
# ("The external renderer is calculating an image. Do you want to stop it?") or ends the battery run.
function Assert-BenchReady {
    $state = Get-Content "$BenchRoot\state.json" -Raw -ErrorAction SilentlyContinue | ConvertFrom-Json
    $problem = if ($state -and -not $state.Finished) { 'Setup is still running (it reboots and installs drivers). Let it finish first.' }
               elseif (Test-Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired') {
                   'Windows Update is waiting to reboot and would restart mid-test. Reboot first.' }
    if ($problem) { Write-Warn $problem; Read-Host 'Press Enter to close'; exit 1 }
}

function Get-CpuName { (Get-CimInstance Win32_Processor | Select-Object -First 1).Name.Trim() }

# Mirror local results to the SSD when it is plugged in, then rebuild the all-laptops tables there.
function Sync-Results {
    $ssd = Get-SsdRoot
    if (-not $ssd) { return }
    $all = Join-Path $ssd 'results'
    robocopy (Join-Path $BenchRoot 'results') $all /E /XO /NJH /NJS /NFL /NDL /NP | Out-Null
    foreach ($name in 'cbr23', 'battery') {
        $rows = Get-ChildItem "$all\*\$name-summary.csv" -ErrorAction SilentlyContinue | ForEach-Object { Import-Csv $_.FullName }
        if ($rows) { $rows | Export-Csv "$all\$name-all-laptops.csv" -NoTypeInformation }
    }
    Write-Host "Results mirrored to $all"
}

function Get-PowerState {
    Add-Type -AssemblyName System.Windows.Forms
    $s = [System.Windows.Forms.SystemInformation]::PowerStatus
    $overlays = @{
        'ded574b5-45a0-4f42-8737-46345c09c238' = 'Best performance'
        '961cc777-2547-4f9d-8174-7d86181b8a7a' = 'Best power efficiency'
        '00000000-0000-0000-0000-000000000000' = 'Balanced'
    }
    $online = $s.PowerLineStatus -eq 'Online'
    $key = if ($online) { 'ActiveOverlayAcPowerScheme' } else { 'ActiveOverlayDcPowerScheme' }
    $guid = (Get-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control\Power\User\PowerSchemes' -ErrorAction SilentlyContinue).$key
    $mode = if ($guid -and $overlays[$guid]) { $overlays[$guid] } else { 'Balanced' }
    [pscustomobject]@{
        Source  = if ($online) { 'AC' } else { 'DC' }
        Battery = [math]::Round($s.BatteryLifePercent * 100)
        Mode    = $mode
    }
}
