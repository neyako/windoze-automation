# Privacy, ads and AI tweaks plus bloat removal.
# Deliberately never touches power plans, hibernation, fast startup, sleep or any powercfg setting.

function Set-Reg([string]$Path, [string]$Name, $Value) {
    if (-not (Test-Path $Path)) { New-Item -Path $Path -Force | Out-Null }
    New-ItemProperty -Path $Path -Name $Name -Value $Value -PropertyType DWord -Force | Out-Null
}

$cdm = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'
$adv = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'
$exp = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer'
$startKey = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Start'

# Leading commas keep each row an array; without them PowerShell flattens the list.
$Tweaks = @(
    # Telemetry and tracking
    ,@('HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection', 'AllowTelemetry', 0)
    ,@('HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection', 'DoNotShowFeedbackNotifications', 1)
    ,@('HKCU:\Software\Microsoft\Siuf\Rules', 'NumberOfSIUFInPeriod', 0)
    ,@('HKCU:\Software\Microsoft\Windows\CurrentVersion\Privacy', 'TailoredExperiencesWithDiagnosticDataEnabled', 0)
    ,@('HKLM:\SOFTWARE\Policies\Microsoft\Windows\AdvertisingInfo', 'DisabledByGroupPolicy', 1)
    ,@('HKCU:\Software\Microsoft\Windows\CurrentVersion\AdvertisingInfo', 'Enabled', 0)
    ,@('HKLM:\SOFTWARE\Policies\Microsoft\Windows\System', 'PublishUserActivities', 0)
    ,@('HKLM:\SOFTWARE\Policies\Microsoft\Windows\System', 'UploadUserActivities', 0)
    ,@('HKLM:\SOFTWARE\Policies\Microsoft\Windows\System', 'EnableActivityFeed', 0)
    ,@('HKCU:\Software\Microsoft\Input\TIPC', 'Enabled', 0)
    ,@('HKCU:\Software\Microsoft\InputPersonalization', 'RestrictImplicitInkCollection', 1)
    ,@('HKCU:\Software\Microsoft\InputPersonalization', 'RestrictImplicitTextCollection', 1)

    # Ads, suggestions, silently installed apps
    ,@('HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent', 'DisableWindowsConsumerFeatures', 1)
    ,@('HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent', 'DisableConsumerAccountStateContent', 1)
    ,@('HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent', 'DisableCloudOptimizedContent', 1)
    ,@('HKCU:\Software\Policies\Microsoft\Windows\CloudContent', 'DisableTailoredExperiencesWithDiagnosticData', 1)
    ,@($cdm, 'ContentDeliveryAllowed', 0)
    ,@($cdm, 'OemPreInstalledAppsEnabled', 0)
    ,@($cdm, 'PreInstalledAppsEnabled', 0)
    ,@($cdm, 'PreInstalledAppsEverEnabled', 0)
    ,@($cdm, 'SilentInstalledAppsEnabled', 0)
    ,@($cdm, 'SoftLandingEnabled', 0)
    ,@($cdm, 'SystemPaneSuggestionsEnabled', 0)
    ,@($cdm, 'RotatingLockScreenOverlayEnabled', 0)
    ,@($cdm, 'SubscribedContent-310093Enabled', 0)   # Welcome experience after updates
    ,@($cdm, 'SubscribedContent-338387Enabled', 0)   # Lock screen fun facts
    ,@($cdm, 'SubscribedContent-338388Enabled', 0)   # Start suggestions
    ,@($cdm, 'SubscribedContent-338389Enabled', 0)   # Tips and suggestions notifications
    ,@($cdm, 'SubscribedContent-338393Enabled', 0)   # Settings suggested content
    ,@($cdm, 'SubscribedContent-353694Enabled', 0)
    ,@($cdm, 'SubscribedContent-353696Enabled', 0)
    ,@($cdm, 'SubscribedContent-353698Enabled', 0)   # Timeline suggestions
    ,@($adv, 'ShowSyncProviderNotifications', 0)     # File Explorer ads
    ,@($adv, 'Start_IrisRecommendations', 0)         # Start menu recommendations
    ,@($adv, 'Start_AccountNotifications', 0)
    ,@('HKCU:\Software\Microsoft\Windows\CurrentVersion\UserProfileEngagement', 'ScoobeSystemSettingEnabled', 0)   # "Finish setting up" nag
    ,@('HKCU:\Software\Microsoft\Windows\CurrentVersion\SystemSettings\AccountNotifications', 'EnableAccountNotifications', 0)

    # Bing and web results in Start search
    ,@('HKCU:\Software\Policies\Microsoft\Windows\Explorer', 'DisableSearchBoxSuggestions', 1)
    ,@('HKCU:\Software\Microsoft\Windows\CurrentVersion\Search', 'BingSearchEnabled', 0)
    ,@('HKCU:\Software\Microsoft\Windows\CurrentVersion\SearchSettings', 'IsDynamicSearchBoxEnabled', 0)
    ,@('HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search', 'AllowCortana', 0)
    ,@('HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search', 'EnableDynamicContentInWSB', 0)

    # Copilot, Recall, Click to Do (Widgets: its policy key is write-protected, so the package is removed instead)
    ,@('HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsCopilot', 'TurnOffWindowsCopilot', 1)
    ,@('HKCU:\Software\Policies\Microsoft\Windows\WindowsCopilot', 'TurnOffWindowsCopilot', 1)
    ,@($adv, 'ShowCopilotButton', 0)
    ,@('HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsAI', 'DisableAIDataAnalysis', 1)
    ,@('HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsAI', 'AllowRecallEnablement', 0)
    ,@('HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsAI', 'DisableClickToDo', 1)
    ,@('HKCU:\Software\Policies\Microsoft\Windows\WindowsAI', 'DisableAIDataAnalysis', 1)

    # Background game recording skews benchmarks
    ,@('HKCU:\System\GameConfigStore', 'GameDVR_Enabled', 0)
    ,@('HKCU:\Software\Microsoft\Windows\CurrentVersion\GameDVR', 'AppCaptureEnabled', 0)

    # UAC on "never notify": no prompts, but EnableLUA stays 1 because 0 breaks Store apps (Terminal, vendor apps)
    ,@('HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System', 'ConsentPromptBehaviorAdmin', 0)
    ,@('HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System', 'PromptOnSecureDesktop', 0)

    # No Windows Update restarts while signed in: they close Cinebench mid-run and end battery tests
    ,@('HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU', 'NoAutoRebootWithLoggedOnUsers', 1)

    # Keep OneDrive from coming back; give PrtSc to ShareX instead of the (removed) Snipping Tool
    ,@('HKLM:\SOFTWARE\Policies\Microsoft\Windows\OneDrive', 'DisableFileSyncNGSC', 1)
    ,@('HKCU:\Control Panel\Keyboard', 'PrintScreenKeyForSnippingEnabled', 0)

    # Snapping stays; the maximize-button layout flyout and the drag-to-top snap bar go
    ,@($adv, 'EnableSnapAssistFlyout', 0)
    ,@($adv, 'EnableSnapBar', 0)

    # File Explorer opens at This PC; every Folder Options > Privacy box off
    ,@($adv, 'LaunchTo', 1)
    ,@($exp, 'ShowRecent', 0)
    ,@($exp, 'ShowFrequent', 0)
    ,@($exp, 'ShowRecommendations', 0)
    ,@($exp, 'ShowCloudFilesInQuickAccess', 0)

    # No Recent section in Start: recent files, recently added and most used apps
    ,@($adv, 'Start_TrackDocs', 0)
    ,@($adv, 'Start_TrackProgs', 0)
    ,@($startKey, 'ShowRecentList', 0)
    ,@($startKey, 'ShowFrequentList', 0)

    # Taste
    ,@('HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize', 'AppsUseLightTheme', 0)
    ,@('HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize', 'SystemUsesLightTheme', 0)
    ,@($adv, 'HideFileExt', 0)
)

$TelemetryTasks = @(
    '\Microsoft\Windows\Application Experience\Microsoft Compatibility Appraiser'
    '\Microsoft\Windows\Application Experience\ProgramDataUpdater'
    '\Microsoft\Windows\Customer Experience Improvement Program\Consolidator'
    '\Microsoft\Windows\Customer Experience Improvement Program\UsbCeip'
    '\Microsoft\Windows\Feedback\Siuf\DmClient'
    '\Microsoft\Windows\Feedback\Siuf\DmClientOnScenarioDownload'
)

# Console windows open in Windows Terminal instead of the old conhost (elevated task launches ignore this; setup calls wt.exe for those).
function Set-DefaultTerminal {
    $console = 'HKCU:\Console\%%Startup'
    if (-not (Test-Path $console)) { New-Item $console | Out-Null }
    Set-ItemProperty $console DelegationConsole '{2EACA947-7F5F-4CFA-BA87-8F7FBEEFBE69}'
    Set-ItemProperty $console DelegationTerminal '{E12CFF52-A866-4C77-9A90-F570A7AA2C6B}'
}

function Invoke-Debloat($Config) {
    $applied = 0
    foreach ($t in $Tweaks) {
        try { Set-Reg $t[0] $t[1] $t[2]; $applied++ } catch { Write-Warn "$($t[0])\$($t[1]): $($_.Exception.Message)" }
    }
    Write-Host "  $applied of $($Tweaks.Count) registry tweaks applied"

    foreach ($svc in 'DiagTrack', 'dmwappushservice') {
        Stop-Service $svc -Force -ErrorAction SilentlyContinue
        Set-Service $svc -StartupType Disabled -ErrorAction SilentlyContinue
    }
    foreach ($task in $TelemetryTasks) {   # cmdlet, not schtasks: native stderr is fatal under ErrorActionPreference Stop
        $path = $task.Substring(0, $task.LastIndexOf('\') + 1)
        Disable-ScheduledTask -TaskPath $path -TaskName (Split-Path $task -Leaf) -ErrorAction SilentlyContinue | Out-Null
    }
    Set-NetFirewallProfile -All -Enabled False
    Write-Host '  firewall off, UAC prompts off'

    $provisioned = Get-AppxProvisionedPackage -Online
    foreach ($pattern in $Config.RemoveAppx) {
        foreach ($p in Get-AppxPackage -AllUsers -Name $pattern) {
            try { Remove-AppxPackage -Package $p.PackageFullName -AllUsers; Write-Host "  removed $($p.Name)" }
            catch { Write-Warn "could not remove $($p.Name)" }
        }
        # Usually already gone: removing for all users also deprovisions on current builds.
        $provisioned | Where-Object DisplayName -like $pattern | ForEach-Object {
            try { Remove-AppxProvisionedPackage -Online -PackageName $_.PackageName | Out-Null } catch {}
        }
    }

    foreach ($name in $Config.RemoveWin32) {
        winget uninstall --name $name --silent --accept-source-agreements --disable-interactivity 2>&1 | Out-Null
        # 0x8A150014 = nothing matched
        if ($LASTEXITCODE -eq 0) { Write-Host "  uninstalled $name" }
        elseif ($LASTEXITCODE -ne -1978335212) { Write-Warn "could not uninstall $name, remove it by hand" }
    }

    Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue   # apply taskbar/theme changes
}

# Disables everything in Task Manager's Startup tab except $Keep (wildcards on name or command).
# Uses the same StartupApproved flags as Task Manager, so it is reversible there.
function Disable-StartupApps([string[]]$Keep) {
    $approved = 'Software\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved'
    $off = [byte[]](3, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
    function Test-Keep($text) { foreach ($k in $Keep) { if ($text -like $k) { return $true } }; $false }
    function Set-Off($hive, $list, $name) {
        $path = "${hive}:\$approved\$list"
        if (-not (Test-Path $path)) { New-Item $path -Force | Out-Null }
        New-ItemProperty $path $name -Value $off -PropertyType Binary -Force | Out-Null
        Write-Host "  disabled $name"
    }

    $runKeys = @(
        ,@('HKCU', 'Software\Microsoft\Windows\CurrentVersion\Run', 'Run')
        ,@('HKLM', 'Software\Microsoft\Windows\CurrentVersion\Run', 'Run')
        ,@('HKLM', 'Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Run', 'Run32')
    )
    foreach ($r in $runKeys) {
        $key = Get-Item "$($r[0]):\$($r[1])" -ErrorAction SilentlyContinue
        if (-not $key) { continue }
        foreach ($name in $key.GetValueNames()) {
            if ($name -and -not (Test-Keep $name) -and -not (Test-Keep $key.GetValue($name))) { Set-Off $r[0] $r[2] $name }
        }
    }

    $folders = @(
        ,@('HKCU', [Environment]::GetFolderPath('Startup'))
        ,@('HKLM', [Environment]::GetFolderPath('CommonStartup'))
    )
    foreach ($f in $folders) {
        Get-ChildItem $f[1] -File -ErrorAction SilentlyContinue | Where-Object Name -ne 'desktop.ini' |
            Where-Object { -not (Test-Keep $_.Name) } | ForEach-Object { Set-Off $f[0] 'StartupFolder' $_.Name }
    }

    # Store apps: State 2 = enabled, 1 = disabled by user
    Get-ChildItem 'HKCU:\Software\Classes\Local Settings\Software\Microsoft\Windows\CurrentVersion\AppModel\SystemAppData\*\*' -ErrorAction SilentlyContinue |
        Where-Object { $_.GetValue('State') -eq 2 -and -not (Test-Keep $_.PSParentPath) } | ForEach-Object {
            Set-ItemProperty $_.PSPath State 1
            Write-Host "  disabled $(Split-Path $_.PSParentPath -Leaf)"
        }
}

# Unpins everything from Start and the taskbar for the current user.
function Clear-Pins {
    # Start: an empty pinnedList stops Windows' and the OEM's default pins from being re-seeded; the empty
    # start2.bin clears the current pins (template from github.com/Raphire/Win11Debloat, MIT).
    $shell = "$env:LOCALAPPDATA\Microsoft\Windows\Shell"
    New-Item -ItemType Directory -Force $shell | Out-Null
    '{ "pinnedList": [] }' | Set-Content "$shell\LayoutModification.json" -Encoding ASCII
    $start = "$env:LOCALAPPDATA\Packages\Microsoft.Windows.StartMenuExperienceHost_cw5n1h2txyewy\LocalState"
    New-Item -ItemType Directory -Force $start | Out-Null
    Copy-Item "$PSScriptRoot\..\assets\start2.bin" "$start\start2.bin" -Force
    # Killed after the copy so it can't write its old layout back on exit; Windows restarts it.
    Stop-Process -Name StartMenuExperienceHost -Force -ErrorAction SilentlyContinue

    Remove-Item "$env:APPDATA\Microsoft\Internet Explorer\Quick Launch\User Pinned\TaskBar\*.lnk" -Force -ErrorAction SilentlyContinue
    Remove-Item 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Taskband' -Recurse -Force -ErrorAction SilentlyContinue
    Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue
    Write-Host '  Start and taskbar pins cleared'
}
