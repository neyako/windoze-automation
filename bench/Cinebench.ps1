# Cinebench R23 sustained run with HWiNFO logging. Run once plugged in and once on battery.
# Writes results\<model>\cbr23-<time>-<AC|DC>.csv (full sensor log) and appends cbr23-summary.csv.
param(
    [ValidateSet('Both', 'Multi', 'Single')] [string]$Test = 'Both',
    [int]$Minutes = 10,
    [int]$CooldownSeconds = 120,
    [string]$Note
)

. "$PSScriptRoot\..\lib\common.ps1"

$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole('Administrators')
if (-not $isAdmin) {
    $fwd = "-File `"$PSCommandPath`" -Test $Test -Minutes $Minutes -CooldownSeconds $CooldownSeconds"
    if ($PSBoundParameters.ContainsKey('Note')) { $fwd += " -Note `"$Note`"" }   # else the elevated run asks for it
    Start-InTerminal $fwd -Elevated
    exit
}

. "$PSScriptRoot\..\lib\hwinfo.ps1"
Assert-BenchReady

$Cinebench = "$BenchRoot\tools\CinebenchR23\Cinebench.exe"
if (-not (Test-Path $Cinebench)) { throw "Cinebench not found at $Cinebench" }

# Something on some laptops asks Cinebench to close mid-run (seen during single core on a Legion 5), which
# pops "The external renderer is calculating an image. Do you want to stop it?". Answer No so the run goes on.
# Cinebench's own quit after the run can pop it too, so Invoke-Cinebench stops at the score instead of waiting for exit.
if (-not ('CloseGuard' -as [type])) {
Add-Type -TypeDefinition @'
using System;
using System.Diagnostics;
using System.Runtime.InteropServices;
using System.Text;
using System.Threading;

public static class CloseGuard {
    delegate bool EnumProc(IntPtr hwnd, IntPtr lParam);
    [DllImport("user32.dll")] static extern bool EnumWindows(EnumProc proc, IntPtr lParam);
    [DllImport("user32.dll")] static extern uint GetWindowThreadProcessId(IntPtr hwnd, out uint pid);
    [DllImport("user32.dll", CharSet = CharSet.Unicode)] static extern int GetClassName(IntPtr hwnd, StringBuilder name, int max);
    [DllImport("user32.dll")] static extern IntPtr GetDlgItem(IntPtr hwnd, int id);
    [DllImport("user32.dll")] static extern bool PostMessage(IntPtr hwnd, uint msg, IntPtr wParam, IntPtr lParam);
    const int IDNO = 7;
    const uint WM_COMMAND = 0x0111;
    static Timer timer;
    public static int Declined;
    public static string Times = "";

    public static void Start() { Declined = 0; Times = ""; timer = new Timer(Tick, null, 0, 1000); }
    public static void Stop() { if (timer != null) timer.Dispose(); }

    static void Tick(object _) {
        try { EnumWindows(delegate (IntPtr h, IntPtr l) {
            var cls = new StringBuilder(16);
            GetClassName(h, cls, cls.Capacity);
            if (cls.ToString() != "#32770" || GetDlgItem(h, IDNO) == IntPtr.Zero) return true;   // Yes/No dialogs only
            uint pid;
            GetWindowThreadProcessId(h, out pid);
            try { if (Process.GetProcessById((int)pid).ProcessName != "Cinebench") return true; } catch { return true; }
            PostMessage(h, WM_COMMAND, (IntPtr)IDNO, IntPtr.Zero);
            Declined++;
            Times += DateTime.Now.ToString("HH:mm:ss") + " ";
            return true;
        }, IntPtr.Zero); } catch { }   // an exception on a timer thread would kill PowerShell
    }
}
'@
}

function Invoke-Cinebench([string]$Kind) {
    $flags = if ($Kind -eq 'Multi') { 'g_CinebenchCpuXTest=true g_CinebenchCpu1Test=false' }
             else { 'g_CinebenchCpu1Test=true g_CinebenchCpuXTest=false' }
    $out = "$env:TEMP\cbr23-out.txt"
    $bat = "$env:TEMP\cbr23-run.cmd"
    Remove-Item $out -ErrorAction SilentlyContinue
    # Cinebench only prints its score when started this way (start /b + inner cmd redirect).
    "@start `"cb`" /b /wait cmd.exe /c `"`"$Cinebench`" $flags g_CinebenchMinimumTestDuration=$($Minutes * 60) >> `"$out`"`"" |
        Set-Content $bat -Encoding ASCII
    [CloseGuard]::Start()
    $run = Start-Process cmd.exe "/c `"$bat`"" -NoNewWindow -PassThru
    try {
        # Test-Path first: a missing file is a terminating error for Select-String in 5.1
        while (-not $run.HasExited -and -not ((Test-Path $out) -and (Select-String -Path $out -Pattern '^CB\s+[\d.]+\s' -Quiet))) { Start-Sleep 2 }
    } finally {
        [CloseGuard]::Stop()
        Stop-Process -Name Cinebench -Force -ErrorAction SilentlyContinue
    }
    if ([CloseGuard]::Declined) { Write-Warn "Something asked Cinebench to close at $([CloseGuard]::Times)- answered No (check Event Viewer around then)" }
    $line = Get-Content $out -ErrorAction SilentlyContinue | Where-Object { $_ -match '^CB\s+[\d.]+' } | Select-Object -Last 1
    if ($line -notmatch '^CB\s+([\d.]+)') { throw "no score in Cinebench output ($out)" }
    [math]::Round([double]$Matches[1])
}

$model = Get-LaptopModel
$cpu = Get-CpuName
$power = Get-PowerState
Write-Host "$model | $cpu | $($power.Source) $($power.Battery)% | Windows mode: $($power.Mode)" -ForegroundColor Cyan
if (-not $PSBoundParameters.ContainsKey('Note')) { $Note = Read-Host 'Note, e.g. vendor fan mode (Enter to skip)' }

Enable-KeepAwake
$results = Get-ResultsDir
$stamp = Get-Date -Format 'yyyyMMdd-HHmm'
$logFile = "cbr23-$stamp-$($power.Source).csv"
$log = Start-HwInfoLogger
$log.Start((Join-Path $results $logFile), 1000)

$pkg = $log.Find(5, [string[]]@('CPU Package Power'))
$temp = $log.Find(1, [string[]]@('CPU Package', 'CPU (Tctl/Tdie)'))
$clock = $log.Find(6, [string[]]@('Average Effective Clock', 'Core Effective Clocks (avg)', 'Core Clocks (avg)'))
# Fastest core each second (Intel "P-core 0 Effective Clock", AMD "Core 0 T0 Effective Clock"): the all-core average means little for single core
$log.PeakSet = [int[]]@(0..($log.Labels.Count - 1) | Where-Object { $log.Types[$_] -eq 6 -and $log.Labels[$_] -match 'core.*\d.*Effective Clock$' })
if ($pkg -lt 0 -or $temp -lt 0) { Write-Warn 'CPU package power/temp sensor not found; summary will have blanks' }

$tests = if ($Test -eq 'Both') { 'Multi', 'Single' } else { $Test }
try {
    foreach ($kind in $tests) {
        Write-Step "Cooldown $CooldownSeconds s"
        $log.Phase = 'cooldown'
        Start-Sleep $CooldownSeconds

        Write-Step "Cinebench R23 $kind, $Minutes min"
        $log.ResetStats()
        $log.Phase = $kind.ToLower()
        $score = Invoke-Cinebench $kind
        $row = [pscustomobject]@{
            Laptop      = $model
            CPU         = $cpu
            Date        = Get-Date -Format 'yyyy-MM-dd HH:mm'
            Power       = $power.Source
            Battery     = $power.Battery
            WindowsMode = $power.Mode
            Note        = $Note
            Test        = $kind
            Minutes     = $Minutes
            Score       = $score
            PkgW_Avg    = $log.Avg($pkg)
            PkgW_Max    = $log.Max($pkg)
            TempC_Avg   = $log.Avg($temp)
            TempC_Max   = $log.Max($temp)
            ClockMHz_Avg = $log.Avg($clock)
            TopCoreMHz_Avg = $log.PeakAvg()
            Log         = $logFile
        }
        $row | Export-Csv (Join-Path $results 'cbr23-summary.csv') -Append -NoTypeInformation
        Write-Host "Score $score | $($row.PkgW_Avg) W avg | $($row.TempC_Avg) C avg" -ForegroundColor Green
    }
} finally {
    $log.Stop()
    if ($script:HwInfoStarted) { Stop-Process -Name HWiNFO64 -ErrorAction SilentlyContinue }
}

Write-Step "All runs on $model"
Import-Csv (Join-Path $results 'cbr23-summary.csv') |
    Format-Table Date, Power, WindowsMode, Note, Test, Score, PkgW_Avg, PkgW_Max, TempC_Avg, TempC_Max, ClockMHz_Avg, TopCoreMHz_Avg -AutoSize
Sync-Results
Read-Host 'Press Enter to close'
