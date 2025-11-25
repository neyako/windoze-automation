package main

import (
	"fmt"
	"os"
	"strings"
)

type installer struct {
	Name         string
	WingetID     string
	InstallerURL string
	SilentArgs   string
}

func main() {
	script := buildPowerShellScript()
	fmt.Println(script)
}

func buildPowerShellScript() string {
	installers := []installer{
		{Name: "OBS Studio", WingetID: "OBSProject.OBSStudio"},
		{Name: "Brave Browser", WingetID: "Brave.Brave"},
		{Name: "1Password", WingetID: "1Password.1Password"},
		{Name: "ImageGlass", WingetID: "DuongDieuPhap.ImageGlass"},
		{Name: "Steam", WingetID: "Valve.Steam"},
		{Name: "Epic Games", WingetID: "EpicGames.EpicGamesLauncher"},
		{Name: "DaVinci Resolve Studio", WingetID: "BlackmagicDesign.DaVinciResolveStudio"},
		{Name: "HWInfo", WingetID: "REALiX.HWiNFO"},
		{Name: "Cinebench R23", WingetID: "Maxon.CinebenchR23"},
		{Name: "RustDesk", WingetID: "RustDesk.RustDesk"},
		{Name: "K-Lite Codec Pack Full", WingetID: "CodecGuide.K-LiteCodecPack.Full"},
		{Name: "LocalSend", WingetID: "LocalSend.LocalSend"},
		{
			Name:         "MSI Afterburner",
			InstallerURL: "https://download.msi.com/uti_exe/vga/MSIAfterburnerSetup.zip",
			SilentArgs:   "/S",
		},
		{
			Name:         "RivaTuner Statistics Server",
			InstallerURL: "https://download-gcdn.guru3d.com/rtss/RTSSSetup763.exe",
			SilentArgs:   "/S",
		},
	}

	sections := []string{
		buildHeader(),
		buildWingetInstallers(installers),
		buildAfterburnerInstaller(),
		buildDebloatSection(),
		buildBraveSection(),
		buildRtssSection(),
		buildFooter(),
	}

	return strings.Join(sections, "\n\n")
}

func buildHeader() string {
	return strings.TrimSpace(`$ErrorActionPreference = "Stop"

if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltinRole] "Administrator")) {
    Write-Warning "Please run this script from an elevated PowerShell session."
    exit 1
}

Write-Host "Starting Windows post-install automation..." -ForegroundColor Cyan
`)
}

func buildWingetInstallers(installers []installer) string {
	var sb strings.Builder

	sb.WriteString("# Install applications via winget where possible\n")
	sb.WriteString("$apps = @()\n")
	for _, app := range installers {
		if app.WingetID != "" {
			sb.WriteString(fmt.Sprintf(`$apps += @{ Name="%s"; WingetId="%s" }
`, app.Name, app.WingetID))
		}
	}

	sb.WriteString(strings.TrimSpace(`foreach ($app in $apps) {
    Write-Host "Installing $($app.Name) via winget..." -ForegroundColor Green
    winget install --id $app.WingetId --silent --accept-source-agreements --accept-package-agreements -h -e -o "${env:TEMP}\$($app.Name.Replace(' ', ''))" | Out-Host
}`))

	return sb.String()
}

func buildAfterburnerInstaller() string {
	return strings.TrimSpace(`# MSI Afterburner installer helper (winget listing is inconsistent)
$afterburnerZip = Join-Path $env:TEMP "msi-afterburner.zip"
$afterburnerDir = Join-Path $env:TEMP "msi-afterburner"
$afterburnerExe = Join-Path $afterburnerDir "MSIAfterburnerSetup.exe"

Write-Host "Installing MSI Afterburner from vendor package..." -ForegroundColor Green
Invoke-WebRequest -Uri "https://download.msi.com/uti_exe/vga/MSIAfterburnerSetup.zip" -OutFile $afterburnerZip
Expand-Archive -Path $afterburnerZip -DestinationPath $afterburnerDir -Force
Start-Process -FilePath $afterburnerExe -ArgumentList "/S" -Wait

Write-Host "Installing RTSS from vendor package..." -ForegroundColor Green
$rtssExe = Join-Path $afterburnerDir "RTSSSetup*.exe"
$rtss = Get-ChildItem -Path $afterburnerDir -Filter "RTSSSetup*.exe" | Select-Object -First 1
if ($rtss) {
    Start-Process -FilePath $rtss.FullName -ArgumentList "/S" -Wait
} else {
    Invoke-WebRequest -Uri "https://download-gcdn.guru3d.com/rtss/RTSSSetup763.exe" -OutFile (Join-Path $env:TEMP "RTSSSetup.exe")
    Start-Process -FilePath (Join-Path $env:TEMP "RTSSSetup.exe") -ArgumentList "/S" -Wait
}
`)
}

func buildDebloatSection() string {
	return strings.TrimSpace(`# Debloat and optimize using community scripts
Write-Host "Creating a system restore point before debloating..." -ForegroundColor Yellow
try {
    Checkpoint-Computer -Description "Pre-WinDebloat" -RestorePointType MODIFY_SETTINGS | Out-Null
    Write-Host "Restore point created." -ForegroundColor Green
} catch {
    Write-Warning "Failed to create restore point. Continuing without it."
}

Write-Host "Running Chris Titus Tech WinUtil..." -ForegroundColor Green
Invoke-Expression (Invoke-WebRequest -Uri "https://christitus.com/win" -UseBasicParsing).Content

Write-Host "Running Win11Debloat..." -ForegroundColor Green
$debloatTemp = Join-Path $env:TEMP "Win11Debloat"
if (-not (Test-Path $debloatTemp)) { New-Item -Path $debloatTemp -ItemType Directory | Out-Null }
Invoke-WebRequest -Uri "https://raw.githubusercontent.com/Raphire/Win11Debloat/main/Win11Debloat.ps1" -OutFile (Join-Path $debloatTemp "Win11Debloat.ps1")
Set-ExecutionPolicy -Scope Process Bypass -Force
& powershell -ExecutionPolicy Bypass -File (Join-Path $debloatTemp "Win11Debloat.ps1")
`)
}

func buildBraveSection() string {
	return strings.TrimSpace(`# Apply Brave Browser configuration
$braveUserData = Join-Path $env:LOCALAPPDATA "BraveSoftware/Brave-Browser/User Data"
$profilePath = Join-Path $braveUserData "Default"
$preferencesPath = Join-Path $profilePath "Preferences"
$localStatePath = Join-Path $braveUserData "Local State"

$enabledFlags = @(
    "block-insecure-private-network-requests@1",
    "brave-domain-block@1",
    "brave-ephemeral-storage@1",
    "clear-cross-site-cross-browsing-context-group-window-name@1",
    "disallow-doc-written-script-loads@1",
    "enable-isolated-sandboxed-iframes@1",
    "enable-webview-tag-site-isolation@1",
    "origin-agent-cluster-default@1",
    "brave-adblock-cosmetic-filtering-child-frames@1",
    "brave-dark-mode-block@1",
    "brave-debounce@1",
    "brave-domain-block-1pes@1",
    "brave-extension-network-blocking@1",
    "disable-process-reuse@1",
    "enable-quic@1",
    "brave-adblock-cosmetic-filtering@2",
    "brave-vertical-tabs@1",
    "brave-speedreader@1",
    "brave-adblock-cosmetic-filtering-sync-load@1"
)

$disabledFlags = @(
    "strict-origin-isolation",
    "sync-trusted-vault-passphrase-recovery",
    "u2f-security-key-api",
    "web-sql-access",
    "autofill-enable-sending-bcn-in-get-upload-details",
    "autofill-fill-merchant-promo-code-fields",
    "autofill-parse-merchant-promo-code-fields",
    "device-posture",
    "edit-context",
    "enable-accessibility-live-caption",
    "enable-autofill-credit-card-authentication",
    "enable-generic-sensor-extra-classes",
    "enable-webusb-device-detection",
    "font-access",
    "system-keyboard-lock",
    "webxr-incubations"
)

if (-not (Test-Path $profilePath)) {
    Write-Host "Creating initial Brave profile structure..." -ForegroundColor Yellow
    New-Item -ItemType Directory -Force -Path $profilePath | Out-Null
}

function Update-JsonFile {
    param(
        [string]$Path,
        [ScriptBlock]$Update
    )

    if (Test-Path $Path) {
        $json = Get-Content $Path -Raw | ConvertFrom-Json
    } else {
        $json = [ordered]@{}
    }

    & $Update -Json ([ref]$json)
    $json | ConvertTo-Json -Depth 10 | Set-Content -Path $Path -Encoding UTF8
}

Update-JsonFile -Path $preferencesPath -Update {
    param([ref]$Json)
    if (-not $Json.Value.PSObject.Properties.Match("brave").Count) {
        $Json.Value.brave = @{}
    }
    $Json.Value.brave.new_tab_page_show_top_sites = $false
    $Json.Value.brave.welcome_tour_completed = $true
    $Json.Value.brave.sync_promo_shown = $true

    if (-not $Json.Value.PSObject.Properties.Match("session").Count) {
        $Json.Value.session = @{}
    }
    $Json.Value.session.restore_on_startup = 4
    $Json.Value.session.urls_to_restore_on_startup = @("https://start.duckduckgo.com", "https://github.com")
}

Update-JsonFile -Path $localStatePath -Update {
    param([ref]$Json)
    if (-not $Json.Value.PSObject.Properties.Match("browser").Count) {
        $Json.Value.browser = @{}
    }

    $Json.Value.browser.enabled_labs_experiments = $enabledFlags
    $Json.Value.browser.disabled_labs_experiments = $disabledFlags
    $Json.Value.browser.clear_data = @{on_exit = @{ cache = $true; cookies = $true; history = $true }}
}
`)
}

func buildRtssSection() string {
	return strings.TrimSpace(`# Import RTSS overlay
$overlaySource = Join-Path $PSScriptRoot "assets\rtss\custom.ovl"
$rtssProfileDir = "${env:ProgramFiles(x86)}\RivaTuner Statistics Server\Profiles"
if (-not (Test-Path $overlaySource)) {
    Write-Warning "Custom RTSS overlay not found at $overlaySource. Skipping import."
} elseif (-not (Test-Path $rtssProfileDir)) {
    Write-Warning "RTSS not found under Program Files (x86)." 
} else {
    $destination = Join-Path $rtssProfileDir "custom.ovl"
    Copy-Item -Path $overlaySource -Destination $destination -Force
    Write-Host "Imported RTSS overlay to $destination" -ForegroundColor Green
}
`)
}

func buildFooter() string {
	return strings.TrimSpace(`Write-Host "Automation complete. Please reboot to apply all changes." -ForegroundColor Cyan
`)
}

// ensure we include assets in the repository tree during development
func init() {
	_ = os.MkdirAll("assets/rtss", 0o755)
	_, _ = os.Stat("assets/rtss/custom.ovl")
}
