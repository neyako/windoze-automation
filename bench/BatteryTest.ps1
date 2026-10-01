# Battery rundown: loops web browsing, Word/Excel and YouTube until the laptop dies.
# Logs battery % every minute to results\<model>\battery-<time>.csv; the last row is the runtime.
# Runs from C:\Bench, so unplug the SSD too (it draws power).

. "$PSScriptRoot\..\lib\common.ps1"
Assert-BenchReady

$Cfg = (Import-PowerShellDataFile "$PSScriptRoot\..\config.psd1").Battery
$Work = "$BenchRoot\battery"
$BraveProfile = "$Work\brave-profile"
$Results = Get-ResultsDir
$Shell = New-Object -ComObject WScript.Shell

$Brave = @("$env:ProgramFiles\BraveSoftware\Brave-Browser\Application\brave.exe",
           "$env:LOCALAPPDATA\BraveSoftware\Brave-Browser\Application\brave.exe") |
    Where-Object { Test-Path $_ } | Select-Object -First 1
if (-not $Brave) { throw 'Brave is not installed' }

# --- logging ---------------------------------------------------------------

$script:LogPath = $null
$script:Start = $null
$script:NextLog = $null
$script:Phase = ''

function Write-BatteryLog {
    if ((Get-Date) -lt $script:NextLog) { return }
    $p = Get-PowerState
    $min = [int]((Get-Date) - $script:Start).TotalMinutes
    '{0},{1},{2:0}:{3:00},{4},{5}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $min, [math]::Floor($min / 60), ($min % 60), $p.Battery, $script:Phase |
        Add-Content $script:LogPath
    Write-Host "  $([math]::Floor($min / 60))h$($min % 60)m  $($p.Battery)%  $script:Phase"
    if ($p.Source -eq 'AC') { throw 'Charger plugged in, test stopped' }
    $script:NextLog = $script:NextLog.AddMinutes(1)
}

# Every wait goes through here so the log keeps ticking.
function Wait-Test([int]$Seconds) {
    $end = (Get-Date).AddSeconds($Seconds)
    while ((Get-Date) -lt $end) { Write-BatteryLog; Start-Sleep 2 }
}

# --- workloads -------------------------------------------------------------

function Open-Brave([string]$Url) {
    Start-Process $Brave "--user-data-dir=`"$BraveProfile`" --no-first-run --no-default-browser-check --autoplay-policy=no-user-gesture-required --start-maximized $Url"
}

function Close-Brave {
    Get-Process brave -ErrorAction SilentlyContinue | Where-Object MainWindowHandle -ne 0 | ForEach-Object { [void]$_.CloseMainWindow() }
    Start-Sleep 3
    Stop-Process -Name brave -Force -ErrorAction SilentlyContinue
}

function Invoke-Web {
    $script:Phase = 'web'
    foreach ($url in $Cfg.Sites) {
        Open-Brave $url
        Wait-Test 5
        $steps = [math]::Max(1, [int]($Cfg.SiteSeconds / 3))
        for ($i = 0; $i -lt $steps; $i++) {
            [void]$Shell.AppActivate('Brave')
            $Shell.SendKeys($(if ($i % 10 -lt 7) { '{PGDN}' } else { '{PGUP}' }))
            Wait-Test 3
        }
    }
    Close-Brave
}

function New-OfficeFiles {
    $dir = New-Item -ItemType Directory -Force "$Work\office"
    if (Test-Path "$dir\sheet.xlsx") { return }
    Write-Host 'Generating Office test files...'
    $words = 'laptop battery display processor memory storage keyboard thermal performance efficiency graphics wireless'.Split(' ')
    $rng = New-Object Random 42
    $word = New-Object -ComObject Word.Application
    foreach ($n in 1..3) {
        $doc = $word.Documents.Add()
        $paras = foreach ($p in 1..(150 * $n)) { ((1..60 | ForEach-Object { $words[$rng.Next($words.Count)] }) -join ' ') + '.' }
        $doc.Content.Text = $paras -join "`r"
        $doc.SaveAs2("$dir\doc$n.docx")
        $doc.Close()
    }
    $word.Quit()
    $excel = New-Object -ComObject Excel.Application
    $wb = $excel.Workbooks.Add()
    $ws = $wb.Worksheets.Item(1)
    $ws.Range('A1:L3000').Formula = '=RAND()*1000'
    $ws.Range('M1:M3000').Formula = '=SUM(A1:L1)'
    $wb.SaveAs("$dir\sheet.xlsx")
    $wb.Close($false)
    $excel.Quit()
}

function Scroll-Office($App, [int]$Seconds) {
    $steps = [math]::Max(1, [int]($Seconds / 3))
    for ($i = 0; $i -lt $steps; $i++) {
        if ($i % 10 -lt 7) { $App.ActiveWindow.SmallScroll(15) } else { $App.ActiveWindow.SmallScroll(0, 15) }
        Wait-Test 3
    }
}

function Invoke-Office {
    $script:Phase = 'office'
    $word = New-Object -ComObject Word.Application
    $word.Visible = $true
    foreach ($n in 1..3) {
        $doc = $word.Documents.Open("$Work\office\doc$n.docx", $false, $true)
        $word.WindowState = 1   # maximized
        Scroll-Office $word $Cfg.OfficeSeconds
        $doc.Close($false)
    }
    $word.Quit()

    $excel = New-Object -ComObject Excel.Application
    $excel.Visible = $true
    $wb = $excel.Workbooks.Open("$Work\office\sheet.xlsx", 0, $true)
    $excel.WindowState = -4137   # maximized
    Scroll-Office $excel $Cfg.OfficeSeconds
    $wb.Close($false)
    $excel.Quit()
}

function Invoke-YouTube {
    $script:Phase = 'youtube'
    foreach ($url in $Cfg.Videos) {
        Open-Brave $url
        Wait-Test ($Cfg.VideoMinutes * 60)
        Close-Brave
    }
}

# --- run -------------------------------------------------------------------

# One row per finished run (the last log line is the runtime), rebuilt from the logs each time.
$model = Get-LaptopModel
$cpu = Get-CpuName
$summary = Get-ChildItem $Results -Filter 'battery-2*.csv' | Sort-Object Name | ForEach-Object {
    $end = Import-Csv $_.FullName | Select-Object -Last 1
    if ($end) {
        [pscustomobject]@{ Laptop = $model; CPU = $cpu; Date = $end.Time; Runtime = $end.Elapsed; Minutes = $end.Minutes
                           EndBattery = $end.Battery; EndPhase = $end.Phase; Log = $_.Name }
    }
}
if ($summary) {
    $summary | Export-Csv "$Results\battery-summary.csv" -NoTypeInformation
    $summary | Format-Table Date, Runtime, EndBattery, EndPhase, Log -AutoSize
}
Sync-Results

# A fresh profile has no media engagement, so unmuted autoplay needs --autoplay-policy (see Open-Brave).
# Also pin Brave's own autoplay site setting to Allow in case it was changed.
if (-not (Test-Path "$BraveProfile\Default\Preferences")) {
    New-Item -ItemType Directory -Force "$BraveProfile\Default" | Out-Null
    '{"profile":{"default_content_setting_values":{"autoplay":1}}}' | Set-Content "$BraveProfile\Default\Preferences" -Encoding ASCII
}
$office = $true
try { New-OfficeFiles } catch { $office = $false; Write-Warn "Office not usable, skipping Word/Excel: $_" }

Write-Host @'

Checklist: charged to 100%, Windows power mode Balanced, Wi-Fi + Bluetooth on,
battery saver at default, SSD and all USB devices unplugged.
Brightness and volume are set by the script.

Unplug the charger to start (Ctrl+C to cancel)...
'@
while ((Get-PowerState).Source -eq 'AC') { Start-Sleep 2 }

Enable-KeepAwake
Get-CimInstance -Namespace root/WMI -ClassName WmiMonitorBrightnessMethods |
    Invoke-CimMethod -MethodName WmiSetBrightness -Arguments @{ Timeout = 0; Brightness = [byte]$Cfg.Brightness } | Out-Null
1..50 | ForEach-Object { $Shell.SendKeys([char]174) }   # volume down to 0

$script:LogPath = Join-Path $Results "battery-$(Get-Date -Format 'yyyyMMdd-HHmm').csv"
'Time,Minutes,Elapsed,Battery,Phase' | Set-Content $script:LogPath
$script:Start = Get-Date
$script:NextLog = $script:Start
Write-Step "Logging to $script:LogPath"

try {
    while ($true) {
        Invoke-Web
        if ($office) { Invoke-Office }
        Invoke-YouTube
    }
} finally {
    Close-Brave
    Write-Host "Stopped. Log: $script:LogPath"
}
