<#
.SYNOPSIS
    Bootstrap script to download and run Windows Automation from a fresh install
    
.DESCRIPTION
    This script can be run on a fresh Windows installation to:
    1. Download the automation repository
    2. Install prerequisites
    3. Run the automation with your configuration
    
.PARAMETER ConfigUrl
    URL to a custom config.yaml file (optional)
    
.PARAMETER SkipDownload
    Skip downloading the repository if already present
    
.EXAMPLE
    # Run from PowerShell (as Admin):
    irm https://raw.githubusercontent.com/yourusername/windoze-automation/main/bootstrap.ps1 | iex
    
.EXAMPLE
    # With custom config URL:
    $ConfigUrl = "https://example.com/my-config.yaml"
    irm https://raw.githubusercontent.com/yourusername/windoze-automation/main/bootstrap.ps1 | iex
    
.NOTES
    Requires: Administrator privileges
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$ConfigUrl = "",
    
    [Parameter(Mandatory = $false)]
    [switch]$SkipDownload
)

#Requires -RunAsAdministrator

$ErrorActionPreference = "Stop"

# Configuration
$RepoUrl = "https://github.com/yourusername/windoze-automation/archive/refs/heads/main.zip"
$InstallPath = "C:\WindowsAutomation"
$TempPath = Join-Path $env:TEMP "windoze-automation"

function Write-ColorOutput {
    param(
        [string]$Message,
        [string]$Color = "White"
    )
    Write-Host $Message -ForegroundColor $Color
}

function Test-Administrator {
    $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($currentUser)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Install-Prerequisites {
    Write-ColorOutput "`n[1/4] Installing prerequisites..." "Cyan"
    
    # Check for Winget
    try {
        $wingetVersion = winget --version
        Write-ColorOutput "✓ Winget is installed: $wingetVersion" "Green"
    }
    catch {
        Write-ColorOutput "⚠ Winget not found. Installing App Installer..." "Yellow"
        Write-ColorOutput "Please install 'App Installer' from Microsoft Store and run this script again." "Yellow"
        Start-Process "ms-windows-store://pdp/?ProductId=9NBLGGH4NNS1"
        exit 1
    }
    
    # Check for Git (optional but recommended)
    try {
        $gitVersion = git --version
        Write-ColorOutput "✓ Git is installed: $gitVersion" "Green"
    }
    catch {
        Write-ColorOutput "⚠ Git not found. Installing Git..." "Yellow"
        winget install --id Git.Git --silent --accept-package-agreements --accept-source-agreements
        Write-ColorOutput "✓ Git installed" "Green"
    }
}

function Download-Repository {
    Write-ColorOutput "`n[2/4] Downloading Windows Automation..." "Cyan"
    
    if ($SkipDownload -and (Test-Path $InstallPath)) {
        Write-ColorOutput "✓ Skipping download, using existing installation" "Green"
        return
    }
    
    # Clean up old installation
    if (Test-Path $InstallPath) {
        Write-ColorOutput "Removing old installation..." "Yellow"
        Remove-Item -Path $InstallPath -Recurse -Force
    }
    
    # Create temp directory
    if (-not (Test-Path $TempPath)) {
        New-Item -Path $TempPath -ItemType Directory -Force | Out-Null
    }
    
    # Download repository
    $zipPath = Join-Path $TempPath "repo.zip"
    Write-ColorOutput "Downloading from GitHub..." "White"
    
    try {
        Invoke-WebRequest -Uri $RepoUrl -OutFile $zipPath -UseBasicParsing
        Write-ColorOutput "✓ Download complete" "Green"
    }
    catch {
        Write-ColorOutput "✗ Failed to download repository: $_" "Red"
        exit 1
    }
    
    # Extract
    Write-ColorOutput "Extracting files..." "White"
    Expand-Archive -Path $zipPath -DestinationPath $TempPath -Force
    
    # Move to install location
    $extractedFolder = Get-ChildItem -Path $TempPath -Directory | Select-Object -First 1
    Move-Item -Path $extractedFolder.FullName -Destination $InstallPath -Force
    
    # Cleanup
    Remove-Item -Path $TempPath -Recurse -Force
    
    Write-ColorOutput "✓ Repository downloaded to: $InstallPath" "Green"
}

function Get-CustomConfig {
    Write-ColorOutput "`n[3/4] Configuration setup..." "Cyan"
    
    if ($ConfigUrl) {
        Write-ColorOutput "Downloading custom configuration..." "White"
        $configPath = Join-Path $InstallPath "config.yaml"
        
        try {
            Invoke-WebRequest -Uri $ConfigUrl -OutFile $configPath -UseBasicParsing
            Write-ColorOutput "✓ Custom configuration downloaded" "Green"
        }
        catch {
            Write-ColorOutput "✗ Failed to download custom config: $_" "Red"
            Write-ColorOutput "Using default configuration instead" "Yellow"
        }
    }
    else {
        Write-ColorOutput "Using default configuration" "White"
        Write-ColorOutput "You can customize: $InstallPath\config.yaml" "Yellow"
    }
}

function Start-Automation {
    Write-ColorOutput "`n[4/4] Starting Windows Automation..." "Cyan"
    
    $scriptPath = Join-Path $InstallPath "Install-WindowsAutomation.ps1"
    
    if (-not (Test-Path $scriptPath)) {
        Write-ColorOutput "✗ Automation script not found: $scriptPath" "Red"
        exit 1
    }
    
    Write-ColorOutput "`nReady to start automation!" "Green"
    Write-ColorOutput "`nThis will:" "White"
    Write-ColorOutput "  • Create a system restore point" "White"
    Write-ColorOutput "  • Backup your registry" "White"
    Write-ColorOutput "  • Install software" "White"
    Write-ColorOutput "  • Remove bloatware" "White"
    Write-ColorOutput "  • Apply privacy tweaks" "White"
    Write-ColorOutput "  • Optimize system settings" "White"
    
    Write-Host "`n"
    $response = Read-Host "Do you want to continue? (Y/N)"
    
    if ($response -eq "Y" -or $response -eq "y") {
        Write-ColorOutput "`nStarting automation..." "Cyan"
        Set-Location $InstallPath
        & $scriptPath
    }
    else {
        Write-ColorOutput "`nAutomation cancelled." "Yellow"
        Write-ColorOutput "You can run it later with:" "White"
        Write-ColorOutput "  cd $InstallPath" "Cyan"
        Write-ColorOutput "  .\Install-WindowsAutomation.ps1" "Cyan"
    }
}

# Main execution
try {
    Write-ColorOutput @"
╔════════════════════════════════════════════════════════════════╗
║                                                                ║
║        Windows Automation Bootstrap Script                    ║
║                                                                ║
╚════════════════════════════════════════════════════════════════╝
"@ "Cyan"
    
    # Check for admin rights
    if (-not (Test-Administrator)) {
        Write-ColorOutput "`n✗ This script must be run as Administrator!" "Red"
        Write-ColorOutput "Right-click PowerShell and select 'Run as Administrator'" "Yellow"
        exit 1
    }
    
    Install-Prerequisites
    Download-Repository
    Get-CustomConfig
    Start-Automation
    
    Write-ColorOutput "`n✓ Bootstrap complete!" "Green"
}
catch {
    Write-ColorOutput "`n✗ An error occurred: $_" "Red"
    Write-ColorOutput "Please check the error message and try again." "Yellow"
    exit 1
}

