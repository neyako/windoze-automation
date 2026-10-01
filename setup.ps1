# One-shot laptop setup. Launched by Setup.cmd from the SSD; resumes from C:\Bench after reboots.
# Steps are recorded in C:\Bench\state.json. Delete that file to run everything again.

. "$PSScriptRoot\lib\common.ps1"
. "$PSScriptRoot\lib\debloat.ps1"

$Config = Import-PowerShellDataFile "$PSScriptRoot\config.psd1"
$StatePath = "$BenchRoot\state.json"
$TaskName = 'windoze-setup'
$MicrosoftUpdate = '7971f918-a847-4430-9279-4a52d1efe18d'
$MaxUpdatePasses = 5
$UserAgent = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)'

New-Item -ItemType Directory -Force $BenchRoot | Out-Null
Start-Transcript -Append "$BenchRoot\setup.log" | Out-Null
Enable-KeepAwake

$State = if (Test-Path $StatePath) { Get-Content $StatePath -Raw | ConvertFrom-Json }
         else { [pscustomobject]@{ Done = @(); Failed = @(); UpdatePasses = 0; Ssd = '' } }
function Save-State { $State | ConvertTo-Json | Set-Content $StatePath }
function Add-Failure($msg) { Write-Warn $msg; $State.Failed += $msg; Save-State }

# --- helpers ---------------------------------------------------------------

function Initialize-Winget {
    if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
        Add-AppxPackage -RegisterByFamilyName -MainPackage Microsoft.DesktopAppInstaller_8wekyb3d8bbwe -ErrorAction SilentlyContinue
    }
    if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
        Invoke-WebRequest https://aka.ms/getwinget -OutFile "$env:TEMP\winget.msixbundle" -UseBasicParsing
        Add-AppxPackage "$env:TEMP\winget.msixbundle"
    }
    winget source update --disable-interactivity 2>&1 | Out-Null
}

function Install-WingetPackage([string]$Id) {
    Write-Host "  $Id"
    $out = winget install --id $Id --exact --silent --accept-package-agreements --accept-source-agreements --disable-interactivity 2>&1
    # ok, reboot needed, already installed, no newer version, reboot to finish
    if ($LASTEXITCODE -notin 0, 3010, -1978335135, -1978335189, -1978334967) {
        Add-Failure "winget $Id (exit $LASTEXITCODE): $(($out | Select-Object -Last 3) -join ' ')"
    }
}

function Invoke-Installer([string]$Name, [string]$File, [string]$Arguments) {
    Write-Host "  $Name"
    $ext = [IO.Path]::GetExtension($File)
    $p = if ($ext -eq '.msi') { Start-Process msiexec.exe "/i `"$File`" /qn /norestart" -Wait -PassThru }
         elseif ($Arguments) { Start-Process $File $Arguments -Wait -PassThru }
         else { Start-Process $File -Wait -PassThru }
    if ($p.ExitCode -notin 0, 3010) { Add-Failure "$Name installer exit $($p.ExitCode)" }
}

function Get-Download([string]$Url, [string]$Referer) {
    $dir = New-Item -ItemType Directory -Force "$BenchRoot\downloads"
    $file = Join-Path $dir ([IO.Path]::GetFileName(([uri]$Url).AbsolutePath))
    $curlArgs = @('-L', '--fail', '-s', '-A', $UserAgent, '-o', $file)
    if ($Referer) { $curlArgs += @('-e', $Referer) }
    & curl.exe @curlArgs $Url
    if ($LASTEXITCODE -ne 0) { throw "download failed: $Url" }
    $file
}

# curl.exe, not Invoke-WebRequest: Cloudflare challenges the .NET client (hwinfo.com does).
function Get-Page([string]$Url) {
    $page = (& curl.exe -L -s --fail -A $UserAgent $Url) -join "`n"
    if ($LASTEXITCODE -ne 0) { throw "could not fetch $Url" }
    $page
}

function Get-GitHubAsset([string]$Repo, [string]$Pattern) {
    $rel = Invoke-RestMethod "https://api.github.com/repos/$Repo/releases/latest" -UseBasicParsing
    $asset = $rel.assets | Where-Object name -match $Pattern | Select-Object -First 1
    if (-not $asset) { throw "no asset matching $Pattern in $Repo $($rel.tag_name)" }
    Get-Download $asset.browser_download_url
}

function Register-Resume {
    $me = [Security.Principal.WindowsIdentity]::GetCurrent().Name
    $ps = "-NoProfile -ExecutionPolicy Bypass -File `"$BenchRoot\setup.ps1`""
    # wt.exe directly: the default-terminal setting is ignored for elevated task launches
    $wt = Get-Command wt.exe -ErrorAction SilentlyContinue
    $action = if ($wt) { New-ScheduledTaskAction -Execute $wt.Source -Argument "powershell.exe $ps" }
              else { New-ScheduledTaskAction -Execute 'powershell.exe' -Argument $ps }
    $trigger = New-ScheduledTaskTrigger -AtLogOn -User $me
    $principal = New-ScheduledTaskPrincipal -UserId $me -RunLevel Highest -LogonType Interactive
    $settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -ExecutionTimeLimit 0
    Register-ScheduledTask $TaskName -Action $action -Trigger $trigger -Principal $principal -Settings $settings -Force | Out-Null
}

function New-Shortcut([string]$Path, [string]$Target, [string]$Arguments = '', [string]$WorkDir = (Split-Path $Target)) {
    $lnk = (New-Object -ComObject WScript.Shell).CreateShortcut($Path)
    $lnk.TargetPath = $Target
    $lnk.Arguments = $Arguments
    $lnk.WorkingDirectory = $WorkDir
    $lnk.Save()
}

function New-BenchShortcut([string]$Name, [string]$Script) {
    $ps = "-NoProfile -ExecutionPolicy Bypass -File `"$BenchRoot\bench\$Script`""
    $lnk = "$([Environment]::GetFolderPath('Desktop'))\$Name.lnk"
    $wt = Get-Command wt.exe -ErrorAction SilentlyContinue
    if ($wt) { New-Shortcut $lnk $wt.Source "powershell.exe $ps" "$BenchRoot\bench" }
    else { New-Shortcut $lnk 'powershell.exe' $ps "$BenchRoot\bench" }
}

# --- steps -----------------------------------------------------------------

function Copy-ToBench {
    # Scripts only: games and installers stay on the SSD. ._* files are macOS junk from using the SSD on the Mac.
    robocopy $PSScriptRoot $BenchRoot /E /XD .git results tools games downloads /XF state.json setup.log ._* .DS_Store /NJH /NJS /NFL /NDL /NP | Out-Null
    $State.Ssd = $PSScriptRoot
    Save-State
    New-BenchShortcut 'CBR23 Bench' 'Cinebench.ps1'
    New-BenchShortcut 'Battery Test' 'BatteryTest.ps1'
    Register-Resume
}

# Key-only SSH so the devbox can debug this laptop (private key stays on the devbox).
# assets\devbox.pub is not in git, so a fresh clone skips this.
function Enable-Ssh {
    $pub = "$PSScriptRoot\assets\devbox.pub"
    if (-not (Test-Path $pub)) { Write-Host '  no assets\devbox.pub, skipped'; return }
    if (-not (Get-Service sshd -ErrorAction SilentlyContinue)) {
        # Microsoft's MSI, not Add-WindowsCapability: that one goes through Windows Update and can sit silently for ages
        Invoke-Installer 'OpenSSH' (Get-GitHubAsset 'PowerShell/Win32-OpenSSH' 'Win64-v[\d.]+\.msi$')
    }
    Set-Service sshd -StartupType Automatic
    Start-Service sshd   # the first start writes the default sshd_config
    $keys = "$env:ProgramData\ssh\administrators_authorized_keys"
    Copy-Item $pub $keys -Force
    icacls.exe $keys /inheritance:r /grant '*S-1-5-32-544:F' /grant '*S-1-5-18:F' | Out-Null   # sshd ignores it otherwise
    $conf = "$env:ProgramData\ssh\sshd_config"
    (Get-Content $conf) -replace '^#?PasswordAuthentication .*', 'PasswordAuthentication no' | Set-Content $conf -Encoding ASCII
    Restart-Service sshd
    Write-Host "  ssh $(Get-SshTarget)"
}

function Get-SshTarget {
    $ips = (Get-NetIPAddress -AddressFamily IPv4 | Where-Object { $_.IPAddress -notmatch '^(127|169\.254)\.' }).IPAddress
    "$env:USERNAME@$($ips -join ' / ')"
}

# Setup usually happens with the US region (more features), which also sets a US time zone.
function Set-Clock {
    Set-TimeZone -Id $Config.TimeZone
    Set-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Services\tzautoupdate' Start 4   # auto time zone would flip it back
    Set-Service w32time -StartupType Automatic
    Start-Service w32time
    w32tm /config /syncfromflags:manual /manualpeerlist:time.cloudflare.com /update | Out-Null
    w32tm /resync /force | Out-Null
    Write-Host "  $((Get-TimeZone).DisplayName), now $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
}

function Install-Runtimes {
    $Config.Runtimes | ForEach-Object { Install-WingetPackage $_ }
    Write-Host '  .NET Framework 3.5'
    Enable-WindowsOptionalFeature -Online -FeatureName NetFx3 -All -NoRestart | Out-Null
}

function Install-Apps {
    $Config.Apps | ForEach-Object { Install-WingetPackage $_ }
    foreach ($z in $Config.PortableZips) {
        Write-Host "  $($z.Name)"
        try {
            $dir = "$env:ProgramFiles\$($z.Name)"
            Expand-Archive (Get-Download $z.Url) $dir -Force
            New-Shortcut "$env:ProgramData\Microsoft\Windows\Start Menu\Programs\$($z.Name).lnk" (Join-Path $dir $z.Exe)
        } catch { Add-Failure "$($z.Name): $_" }
    }
    foreach ($g in $Config.GitHubMsi) {
        try { Invoke-Installer $g.Repo (Get-GitHubAsset $g.Repo $g.Asset) '' } catch { Add-Failure "$($g.Repo): $_" }
    }
}

function Install-BenchTools {
    $tools = "$BenchRoot\tools"
    Write-Host '  Cinebench R23'
    $ssdCinebench = Join-Path $State.Ssd 'tools\CinebenchR23'
    if (Test-Path "$ssdCinebench\Cinebench.exe") {   # R23 is final, so an SSD copy is as good as a download
        robocopy $ssdCinebench "$tools\CinebenchR23" /E /XF ._* /NJH /NJS /NFL /NDL /NP | Out-Null
    } else {
        Expand-Archive (Get-Download 'https://installer.maxon.net/cinebench/CinebenchR23.zip') "$tools\CinebenchR23" -Force
    }

    # winget's HWiNFO is years old; take the newest stable portable build (hwi_NNN.zip, betas have an extra _NNNN).
    # Falls back to the newest tools\hwi_*.zip on the SSD if hwinfo.com can't be reached.
    try {
        $zip = [regex]::Matches((Get-Page 'https://www.hwinfo.com/download/'), 'https://www\.hwinfo\.com/files/hwi_(\d+)\.zip') |
            Sort-Object { [int]$_.Groups[1].Value } | Select-Object -Last 1
        if (-not $zip) { throw 'no download link on the page' }
        $hwinfo = Get-Download $zip.Value 'https://www.hwinfo.com/download/'
    } catch {
        $hwinfo = (Get-ChildItem (Join-Path $State.Ssd 'tools\hwi_*.zip') -ErrorAction SilentlyContinue | Sort-Object Name | Select-Object -Last 1).FullName
        if (-not $hwinfo) { throw "HWiNFO download failed ($_) and no tools\hwi_*.zip on the SSD" }
        Write-Warn "HWiNFO download failed, using $hwinfo"
    }
    Write-Host "  HWiNFO $([IO.Path]::GetFileNameWithoutExtension($hwinfo))"
    Expand-Archive $hwinfo "$tools\HWiNFO" -Force
    # Sensors-only window with Shared Memory on, so the bench script can read sensors without clicking anything.
    "[Settings]`r`nSensorsOnly=1`r`nSensorsSM=1`r`nShowWelcomeAndProgress=0`r`nOpenSystemSummary=0`r`nAutoUpdateBetaDisable=1`r`n" |
        Set-Content "$tools\HWiNFO\HWiNFO64.INI" -Encoding ASCII
}

# Big installers from the SSD, last so a slow or non-silent installer can't hold up everything else.
function Install-SsdInstallers {
    # Silent ones first and waited on: Windows Installer runs one install at a time, so a
    # click-through installer opened alongside them fails (Resolve did while PCMark installed).
    $list = @($Config.SsdInstallers | Where-Object { -not $_.Interactive }) + @($Config.SsdInstallers | Where-Object { $_.Interactive })
    foreach ($i in $list) {
        $file = Get-ChildItem (Join-Path $State.Ssd "tools\installers\$($i.Path)") -ErrorAction SilentlyContinue |
            Sort-Object LastWriteTime | Select-Object -Last 1
        if ($file -and $i.Interactive) { Start-Process $file.FullName; Add-Failure "$($i.Name): installer window is open, click through it" }
        elseif ($file) { Invoke-Installer $i.Name $file.FullName $i.Args }
        else { Write-Warn "$($i.Name): not found in tools\installers, skipped" }
    }
}

function Set-BraveFlags {
    $path = "$env:LOCALAPPDATA\BraveSoftware\Brave-Browser\User Data\Local State"
    Stop-Process -Name brave -Force -ErrorAction SilentlyContinue
    $state = if (Test-Path $path) { Get-Content $path -Raw | ConvertFrom-Json } else { [pscustomobject]@{} }
    if (-not $state.browser) { $state | Add-Member browser ([pscustomobject]@{}) }
    $state.browser | Add-Member enabled_labs_experiments @($Config.BraveFlags) -Force
    New-Item -ItemType Directory -Force (Split-Path $path) | Out-Null
    [IO.File]::WriteAllText($path, ($state | ConvertTo-Json -Depth 100 -Compress), (New-Object Text.UTF8Encoding $false))
    Write-Host "  $($Config.BraveFlags.Count) flags set"
}

# Returns $true when a reboot is needed before the next pass.
function Invoke-UpdatePass {
    $sm = New-Object -ComObject Microsoft.Update.ServiceManager
    try { [void]$sm.AddService2($MicrosoftUpdate, 7, '') } catch {}   # also update Office and other Microsoft products

    $session = New-Object -ComObject Microsoft.Update.Session
    $searcher = $session.CreateUpdateSearcher()
    $searcher.ServerSelection = 3
    $searcher.ServiceID = $MicrosoftUpdate
    Write-Host '  searching...'
    $found = $searcher.Search('IsInstalled=0 and IsHidden=0').Updates

    $batch = New-Object -ComObject Microsoft.Update.UpdateColl
    foreach ($u in $found) {
        if ($u.InstallationBehavior.CanRequestUserInput) { continue }
        if (@($u.Categories | Where-Object Name -eq 'Upgrades').Count) { continue }   # no Windows feature upgrades
        if (-not $u.EulaAccepted) { $u.AcceptEula() }
        Write-Host "  $($u.Title)"
        [void]$batch.Add($u)
    }
    if ($batch.Count -eq 0) { return $false }

    $dl = $session.CreateUpdateDownloader(); $dl.Updates = $batch; [void]$dl.Download()
    $inst = $session.CreateUpdateInstaller(); $inst.Updates = $batch
    $result = $inst.Install()
    for ($i = 0; $i -lt $batch.Count; $i++) {
        $code = $result.GetUpdateResult($i).ResultCode   # 2 = succeeded, 3 = succeeded with errors
        if ($code -notin 2, 3) { Add-Failure "update: $($batch.Item($i).Title) (result $code)" }
    }
    $true
}

function Update-Windows {
    while ($State.UpdatePasses -lt $MaxUpdatePasses) {
        $State.UpdatePasses++; Save-State
        Write-Host "  pass $($State.UpdatePasses)"
        if (-not (Invoke-UpdatePass)) { return }
        $pending = Test-Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired'
        if ($pending) {
            Write-Step 'Rebooting to continue updates. Log in and setup resumes by itself.'
            Stop-Transcript | Out-Null
            shutdown.exe /r /t 20 /c 'windoze: rebooting to continue Windows Update'
            exit
        }
    }
}

function Update-GpuDriver {
    $gpus = (Get-CimInstance Win32_VideoController).Name
    Write-Host "  GPUs: $($gpus -join ', ')"

    if ($gpus -match 'NVIDIA') {
        $exe = Get-GitHubAsset 'HawaiiBeach/TinyNvidiaUpdateChecker' '\.exe$'
        # --config-here reads app.config from the working dir; a missing key pops a first-run question (driver type etc.)
        @'
<?xml version="1.0" encoding="utf-8"?>
<configuration>
  <appSettings>
    <add key="Check for Updates" value="false" />
    <add key="Minimal install" value="false" />
    <add key="Driver type" value="grd" />
  </appSettings>
</configuration>
'@ | Set-Content (Join-Path (Split-Path $exe) 'app.config') -Encoding UTF8
        Write-Host '  NVIDIA: checking and installing latest driver'
        $p = Start-Process $exe '--quiet --confirm-dl --noprompt --config-here' -WorkingDirectory (Split-Path $exe) -Wait -PassThru
        Write-Host "  TinyNvidiaUpdateChecker exit $($p.ExitCode)"
    }

    if ($gpus -match 'AMD|Radeon') {
        $referer = 'https://www.amd.com/en/support/download/drivers.html'
        $page = Get-Page $referer
        if ($page -notmatch 'adrenalin-edition-([\d.]+)-minimalsetup') { throw 'could not find the latest AMD driver version' }
        Write-Host "  AMD: downloading Adrenalin $($Matches[1]) (~1.6 GB)"
        $file = Get-Download "https://drivers.amd.com/drivers/whql-amd-software-adrenalin-edition-$($Matches[1])-win11-c.exe" $referer
        Invoke-Installer 'AMD Adrenalin' $file '-install'
    }
}

function Update-Everything {
    Write-Host '  winget upgrade --all'
    winget upgrade --all --silent --accept-package-agreements --accept-source-agreements --disable-interactivity 2>&1 | Out-Null
    Write-Host '  Microsoft Store apps (vendor apps included)'
    try {
        Get-CimInstance -Namespace 'root\cimv2\mdm\dmmap' -ClassName 'MDM_EnterpriseModernAppManagement_AppManagement01' |
            Invoke-CimMethod -MethodName UpdateScanMethod | Out-Null
    } catch { Write-Warn 'Store update scan failed, open Store > Downloads to update' }
}

# --- run -------------------------------------------------------------------

if ($PSScriptRoot -ne $BenchRoot) {
    Write-Step 'Copying scripts and tools to C:\Bench'
    Copy-ToBench
}

$Steps = [ordered]@{
    'Clock'          = { Set-Clock }              # first: TLS and Windows Update need a correct clock
    'Terminal'       = { Set-DefaultTerminal }
    'SSH'            = { Enable-Ssh }             # early, so a stuck setup can be debugged
    'Winget'         = { Initialize-Winget }
    'Bench tools'    = { Install-BenchTools }
    'Debloat'        = { Invoke-Debloat $Config }
    'Runtimes'       = { Install-Runtimes }
    'Apps'           = { Install-Apps }
    'Brave flags'    = { Set-BraveFlags }
    'Windows Update' = { Update-Windows }        # may reboot and exit here
    'GPU driver'     = { Update-GpuDriver }      # after Windows Update so it can't be replaced by an older one
    'Upgrade all'    = { Update-Everything }
    'SSD installers' = { Install-SsdInstallers }
    'Startup apps'   = { Disable-StartupApps $Config.StartupKeep }   # after every app has registered itself
    'Unpin'          = { Clear-Pins }                                  # after installers that pin themselves
}

foreach ($name in $Steps.Keys) {
    if ($State.Done -contains $name) { continue }
    Write-Step $name
    try { & $Steps[$name] } catch { Add-Failure "${name}: $_" }
    $State.Done += $name
    Save-State
}

Unregister-ScheduledTask $TaskName -Confirm:$false -ErrorAction SilentlyContinue
$State | Add-Member Finished $true -Force   # bench scripts refuse to start until this is set
Save-State
Write-Step 'Setup finished'
if (Test-Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired') {
    Write-Warn 'Reboot once more to finish pending updates'
}
if ($State.Failed.Count) {
    Write-Host 'Needs attention:' -ForegroundColor Yellow
    $State.Failed | ForEach-Object { Write-Host "  - $_" }
}
if (Get-Service sshd -ErrorAction SilentlyContinue) { Write-Host "`nSSH from the devbox: $(Get-SshTarget)" }
Write-Host @'

Left for you:
  - Sign in: 1Password, Brave sync, Telegram, Vesktop, Tailscale, Steam
  - Steam > Settings > Storage > add the SSD library (3DMark + games)
  - EVKey: enable "start with Windows"
  - Open Word once to clear first-run dialogs before the battery test
'@
Stop-Transcript | Out-Null
Read-Host 'Press Enter to close'
