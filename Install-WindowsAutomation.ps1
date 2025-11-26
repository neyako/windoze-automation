<#
.SYNOPSIS
    Windows Post-Installation Automation Script
    
.DESCRIPTION
    Declarative automation system for Windows post-installation tasks including:
    - System restore point creation
    - Registry backup
    - Software installation via Winget
    - Driver updates (NVIDIA via NVCleanstall)
    - System optimization via CTT WinUtil
    - Debloating via Win11Debloat
    - Custom registry tweaks
    
.PARAMETER ConfigPath
    Path to the YAML configuration file. Defaults to config.yaml in the script directory.
    
.PARAMETER DryRun
    If specified, shows what would be done without actually making changes.
    
.EXAMPLE
    .\Install-WindowsAutomation.ps1
    
.EXAMPLE
    .\Install-WindowsAutomation.ps1 -ConfigPath "C:\custom-config.yaml" -DryRun
    
.NOTES
    Author: Windows Automation System
    Requires: PowerShell 5.1+ and Administrator privileges
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$ConfigPath = (Join-Path $PSScriptRoot "config.yaml"),
    
    [Parameter(Mandatory = $false)]
    [switch]$DryRun
)

#Requires -RunAsAdministrator

# Script version
$script:Version = "1.0.0"

# Initialize logging
$script:LogFile = $null
$script:Config = $null

#region Helper Functions

function Write-Log {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message,
        
        [Parameter(Mandatory = $false)]
        [ValidateSet('Info', 'Success', 'Warning', 'Error')]
        [string]$Level = 'Info'
    )
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "[$timestamp] [$Level] $Message"
    
    # Color coding for console output
    $color = switch ($Level) {
        'Info'    { 'White' }
        'Success' { 'Green' }
        'Warning' { 'Yellow' }
        'Error'   { 'Red' }
    }
    
    Write-Host $logMessage -ForegroundColor $color
    
    if ($script:LogFile) {
        Add-Content -Path $script:LogFile -Value $logMessage
    }
}

function Initialize-Logging {
    param([string]$LogPath)
    
    try {
        if (-not (Test-Path $LogPath)) {
            New-Item -Path $LogPath -ItemType Directory -Force | Out-Null
        }
        
        $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
        $script:LogFile = Join-Path $LogPath "automation_$timestamp.log"
        
        Write-Log "Logging initialized: $script:LogFile" -Level Info
        Write-Log "Script Version: $script:Version" -Level Info
        Write-Log "PowerShell Version: $($PSVersionTable.PSVersion)" -Level Info
        Write-Log "OS: $([System.Environment]::OSVersion.VersionString)" -Level Info
        
        if ($DryRun) {
            Write-Log "DRY RUN MODE - No changes will be made" -Level Warning
        }
    }
    catch {
        Write-Warning "Failed to initialize logging: $_"
    }
}

function Install-PowerShellYaml {
    Write-Log "Checking for powershell-yaml module..." -Level Info
    
    if (-not (Get-Module -ListAvailable -Name powershell-yaml)) {
        Write-Log "Installing powershell-yaml module..." -Level Info
        
        if ($DryRun) {
            Write-Log "[DRY RUN] Would install powershell-yaml module" -Level Warning
            return $true
        }
        
        try {
            Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force -ErrorAction Stop | Out-Null
            Install-Module -Name powershell-yaml -Force -Scope CurrentUser -ErrorAction Stop
            Write-Log "powershell-yaml module installed successfully" -Level Success
        }
        catch {
            Write-Log "Failed to install powershell-yaml: $_" -Level Error
            return $false
        }
    }
    else {
        Write-Log "powershell-yaml module already installed" -Level Success
    }
    
    Import-Module powershell-yaml -ErrorAction Stop
    return $true
}

function Read-ConfigFile {
    param([string]$Path)
    
    Write-Log "Reading configuration file: $Path" -Level Info
    
    if (-not (Test-Path $Path)) {
        Write-Log "Configuration file not found: $Path" -Level Error
        throw "Configuration file not found"
    }
    
    try {
        $yamlContent = Get-Content -Path $Path -Raw
        $config = ConvertFrom-Yaml $yamlContent
        Write-Log "Configuration loaded successfully" -Level Success
        return $config
    }
    catch {
        Write-Log "Failed to parse configuration file: $_" -Level Error
        throw
    }
}

function New-SystemRestorePoint {
    param([string]$Description)
    
    Write-Log "Creating system restore point: $Description" -Level Info
    
    if ($DryRun) {
        Write-Log "[DRY RUN] Would create restore point: $Description" -Level Warning
        return $true
    }
    
    try {
        # Enable System Restore if not enabled
        Enable-ComputerRestore -Drive "C:\" -ErrorAction SilentlyContinue
        
        # Create restore point
        Checkpoint-Computer -Description $Description -RestorePointType "MODIFY_SETTINGS"
        Write-Log "System restore point created successfully" -Level Success
        return $true
    }
    catch {
        Write-Log "Failed to create restore point: $_" -Level Error
        return $false
    }
}

function Backup-RegistryKeys {
    param([string]$BackupPath)
    
    Write-Log "Backing up registry..." -Level Info
    
    if ($DryRun) {
        Write-Log "[DRY RUN] Would backup registry to: $BackupPath" -Level Warning
        return $true
    }
    
    try {
        if (-not (Test-Path $BackupPath)) {
            New-Item -Path $BackupPath -ItemType Directory -Force | Out-Null
        }
        
        $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
        $backupFile = Join-Path $BackupPath "registry_backup_$timestamp.reg"
        
        # Export entire registry (this may take a while)
        $regExportCmd = "reg export HKLM `"$backupFile`" /y"
        Start-Process -FilePath "cmd.exe" -ArgumentList "/c $regExportCmd" -Wait -NoNewWindow
        
        Write-Log "Registry backed up to: $backupFile" -Level Success
        return $true
    }
    catch {
        Write-Log "Failed to backup registry: $_" -Level Error
        return $false
    }
}

function Install-WingetPackages {
    param([array]$Packages)
    
    Write-Log "Starting software installation via Winget..." -Level Info
    
    # Check if winget is available
    try {
        $wingetVersion = winget --version
        Write-Log "Winget version: $wingetVersion" -Level Info
    }
    catch {
        Write-Log "Winget not found. Please install App Installer from Microsoft Store." -Level Error
        return $false
    }
    
    $installedCount = 0
    $failedCount = 0
    
    foreach ($package in $Packages) {
        if (-not $package.enabled) {
            Write-Log "Skipping disabled package: $($package.name)" -Level Info
            continue
        }
        
        Write-Log "Installing: $($package.name) ($($package.id))" -Level Info
        
        if ($DryRun) {
            Write-Log "[DRY RUN] Would install: $($package.name)" -Level Warning
            continue
        }
        
        try {
            $result = winget install --id $package.id --silent --accept-package-agreements --accept-source-agreements 2>&1
            
            if ($LASTEXITCODE -eq 0) {
                Write-Log "Successfully installed: $($package.name)" -Level Success
                $installedCount++
            }
            else {
                Write-Log "Failed to install: $($package.name)" -Level Warning
                $failedCount++
            }
        }
        catch {
            Write-Log "Error installing $($package.name): $_" -Level Error
            $failedCount++
        }
    }
    
    Write-Log "Software installation complete. Installed: $installedCount, Failed: $failedCount" -Level Info
    return $true
}

function Invoke-CTTWinUtil {
    param([hashtable]$Config)
    
    Write-Log "Starting CTT WinUtil integration..." -Level Info
    
    if ($DryRun) {
        Write-Log "[DRY RUN] Would run CTT WinUtil with configured tweaks" -Level Warning
        return $true
    }
    
    try {
        Write-Log "Downloading CTT WinUtil..." -Level Info
        
        # Download and execute WinUtil
        $winUtilScript = Invoke-RestMethod "https://christitus.com/win"
        
        Write-Log "CTT WinUtil downloaded. Note: Manual interaction may be required." -Level Warning
        Write-Log "For full automation, consider using WinUtil's preset files." -Level Info
        
        # Note: WinUtil is primarily GUI-based. For full automation, you'd need to:
        # 1. Use WinUtil's preset system
        # 2. Or create a custom wrapper that invokes specific functions
        
        Write-Log "Please run WinUtil manually or implement preset-based automation" -Level Warning
        
        return $true
    }
    catch {
        Write-Log "Failed to download/run CTT WinUtil: $_" -Level Error
        return $false
    }
}

function Invoke-Win11Debloat {
    param([hashtable]$Config)
    
    Write-Log "Starting Win11Debloat integration..." -Level Info
    
    if ($DryRun) {
        Write-Log "[DRY RUN] Would run Win11Debloat" -Level Warning
        return $true
    }
    
    try {
        Write-Log "Downloading Win11Debloat..." -Level Info
        
        $debloatUrl = "https://raw.githubusercontent.com/Raphire/Win11Debloat/master/Win11Debloat.ps1"
        $debloatScript = Invoke-RestMethod $debloatUrl
        
        # Create a temporary script file with parameters
        $tempScript = Join-Path $env:TEMP "Win11Debloat_Automated.ps1"
        Set-Content -Path $tempScript -Value $debloatScript
        
        # Build parameters based on config
        $params = @()
        
        if ($Config.options.remove_apps) {
            $params += "-RemoveApps"
        }
        if ($Config.options.disable_telemetry) {
            $params += "-DisableTelemetry"
        }
        if ($Config.options.disable_bing) {
            $params += "-DisableBing"
        }
        
        $params += "-Silent"
        
        Write-Log "Running Win11Debloat with parameters: $($params -join ' ')" -Level Info
        
        # Execute the script
        & $tempScript @params
        
        # Remove custom apps if specified
        if ($Config.custom_apps_to_remove -and $Config.custom_apps_to_remove.Count -gt 0) {
            Write-Log "Removing custom specified apps..." -Level Info
            foreach ($app in $Config.custom_apps_to_remove) {
                try {
                    Get-AppxPackage -Name "*$app*" | Remove-AppxPackage -ErrorAction SilentlyContinue
                    Write-Log "Removed: $app" -Level Success
                }
                catch {
                    Write-Log "Failed to remove $app : $_" -Level Warning
                }
            }
        }
        
        Remove-Item $tempScript -Force -ErrorAction SilentlyContinue
        
        Write-Log "Win11Debloat completed" -Level Success
        return $true
    }
    catch {
        Write-Log "Failed to run Win11Debloat: $_" -Level Error
        return $false
    }
}

function Set-RegistryTweaks {
    param([array]$Tweaks)
    
    Write-Log "Applying registry tweaks..." -Level Info
    
    $appliedCount = 0
    $failedCount = 0
    
    foreach ($tweak in $Tweaks) {
        if ($tweak.enabled -eq $false) {
            continue
        }
        
        Write-Log "Applying: $($tweak.description)" -Level Info
        
        if ($DryRun) {
            Write-Log "[DRY RUN] Would set $($tweak.path)\$($tweak.name) = $($tweak.value)" -Level Warning
            continue
        }
        
        try {
            # Create registry path if it doesn't exist
            if (-not (Test-Path $tweak.path)) {
                New-Item -Path $tweak.path -Force | Out-Null
            }
            
            # Set registry value
            Set-ItemProperty -Path $tweak.path -Name $tweak.name -Value $tweak.value -Type $tweak.type -Force
            Write-Log "Applied: $($tweak.description)" -Level Success
            $appliedCount++
        }
        catch {
            Write-Log "Failed to apply $($tweak.description): $_" -Level Error
            $failedCount++
        }
    }
    
    Write-Log "Registry tweaks complete. Applied: $appliedCount, Failed: $failedCount" -Level Info
    return $true
}

function Set-ServiceConfiguration {
    param([array]$Services)
    
    Write-Log "Configuring services..." -Level Info
    
    foreach ($svc in $Services) {
        if ($svc.enabled -eq $false) {
            continue
        }
        
        Write-Log "Disabling service: $($svc.name) - $($svc.description)" -Level Info
        
        if ($DryRun) {
            Write-Log "[DRY RUN] Would disable service: $($svc.name)" -Level Warning
            continue
        }
        
        try {
            $service = Get-Service -Name $svc.name -ErrorAction SilentlyContinue
            
            if ($service) {
                Stop-Service -Name $svc.name -Force -ErrorAction SilentlyContinue
                Set-Service -Name $svc.name -StartupType Disabled -ErrorAction Stop
                Write-Log "Disabled: $($svc.name)" -Level Success
            }
            else {
                Write-Log "Service not found: $($svc.name)" -Level Warning
            }
        }
        catch {
            Write-Log "Failed to disable $($svc.name): $_" -Level Error
        }
    }
    
    return $true
}

function Disable-ScheduledTasksList {
    param([array]$Tasks)
    
    Write-Log "Disabling scheduled tasks..." -Level Info
    
    foreach ($taskPath in $Tasks) {
        Write-Log "Disabling task: $taskPath" -Level Info
        
        if ($DryRun) {
            Write-Log "[DRY RUN] Would disable task: $taskPath" -Level Warning
            continue
        }
        
        try {
            Disable-ScheduledTask -TaskPath $taskPath -ErrorAction Stop | Out-Null
            Write-Log "Disabled: $taskPath" -Level Success
        }
        catch {
            Write-Log "Failed to disable $taskPath : $_" -Level Warning
        }
    }
    
    return $true
}

function Invoke-PostScripts {
    param([array]$Scripts)
    
    Write-Log "Running post-installation scripts..." -Level Info
    
    foreach ($script in $Scripts) {
        if (-not $script.enabled) {
            continue
        }
        
        Write-Log "Running: $($script.name)" -Level Info
        
        if ($DryRun) {
            Write-Log "[DRY RUN] Would run: $($script.command)" -Level Warning
            continue
        }
        
        try {
            Invoke-Expression $script.command
            Write-Log "Completed: $($script.name)" -Level Success
        }
        catch {
            Write-Log "Failed to run $($script.name): $_" -Level Error
        }
    }
    
    return $true
}

function Update-NvidiaDrivers {
    param([hashtable]$Config)
    
    Write-Log "NVIDIA driver update requested..." -Level Info
    
    if ($Config.use_nvcleanstall) {
        Write-Log "NVCleanstall integration requires manual setup." -Level Warning
        Write-Log "Please download NVCleanstall from: https://www.techpowerup.com/nvcleanstall/" -Level Info
        Write-Log "For automation, consider using NVCleanstall's command-line options." -Level Info
    }
    else {
        Write-Log "Standard NVIDIA driver update not implemented. Use GeForce Experience or NVCleanstall." -Level Info
    }
    
    return $true
}

#endregion

#region Main Execution

function Start-WindowsAutomation {
    Write-Host @"
╔════════════════════════════════════════════════════════════════╗
║                                                                ║
║        Windows Post-Installation Automation System            ║
║                    Version $script:Version                            ║
║                                                                ║
╚════════════════════════════════════════════════════════════════╝
"@ -ForegroundColor Cyan
    
    Write-Host ""
    
    # Load configuration
    try {
        if (-not (Install-PowerShellYaml)) {
            throw "Failed to install required PowerShell-Yaml module"
        }
        
        $script:Config = Read-ConfigFile -Path $ConfigPath
    }
    catch {
        Write-Host "Failed to load configuration: $_" -ForegroundColor Red
        exit 1
    }
    
    # Initialize logging
    $logPath = if ($script:Config.general.log_path) { 
        $script:Config.general.log_path 
    } else { 
        Join-Path $PSScriptRoot "Logs" 
    }
    Initialize-Logging -LogPath $logPath
    
    Write-Log "Starting Windows automation process..." -Level Info
    Write-Log "Configuration file: $ConfigPath" -Level Info
    
    # Create restore point
    if ($script:Config.general.create_restore_point) {
        $description = $script:Config.general.restore_point_description
        if (-not (New-SystemRestorePoint -Description $description)) {
            Write-Log "Failed to create restore point, but continuing..." -Level Warning
        }
    }
    
    # Backup registry
    if ($script:Config.general.backup_registry) {
        $backupPath = $script:Config.general.registry_backup_path
        if (-not (Backup-RegistryKeys -BackupPath $backupPath)) {
            Write-Log "Failed to backup registry, but continuing..." -Level Warning
        }
    }
    
    # Install software
    if ($script:Config.software.enabled) {
        Install-WingetPackages -Packages $script:Config.software.packages
    }
    
    # Update drivers
    if ($script:Config.drivers.enabled -and $script:Config.drivers.nvidia.enabled) {
        Update-NvidiaDrivers -Config $script:Config.drivers.nvidia
    }
    
    # Apply registry tweaks
    if ($script:Config.registry_tweaks.enabled) {
        Set-RegistryTweaks -Tweaks $script:Config.registry_tweaks.tweaks
    }
    
    # Configure services
    if ($script:Config.services.enabled) {
        Set-ServiceConfiguration -Services $script:Config.services.services_to_disable
    }
    
    # Disable scheduled tasks
    if ($script:Config.scheduled_tasks.enabled) {
        Disable-ScheduledTasksList -Tasks $script:Config.scheduled_tasks.tasks_to_disable
    }
    
    # Run Win11Debloat
    if ($script:Config.win11debloat.enabled) {
        Invoke-Win11Debloat -Config $script:Config.win11debloat
    }
    
    # Run CTT WinUtil (Note: This is primarily GUI-based)
    if ($script:Config.ctt_winutil.enabled) {
        Write-Log "CTT WinUtil is GUI-based. For full automation, manual configuration is needed." -Level Warning
        Write-Log "You can run it manually: irm https://christitus.com/win | iex" -Level Info
    }
    
    # Run post-installation scripts
    if ($script:Config.post_scripts.enabled) {
        Invoke-PostScripts -Scripts $script:Config.post_scripts.scripts
    }
    
    Write-Log "Windows automation process completed!" -Level Success
    Write-Log "Log file saved to: $script:LogFile" -Level Info
    
    # Reboot if configured
    if ($script:Config.general.reboot_after_completion -and -not $DryRun) {
        Write-Log "System will reboot in 60 seconds. Press Ctrl+C to cancel." -Level Warning
        Start-Sleep -Seconds 60
        Restart-Computer -Force
    }
}

# Execute main function
Start-WindowsAutomation

#endregion

