package main

import (
	"flag"
	"fmt"
	"os"
	"strings"

	"gopkg.in/yaml.v3"
)

type Config struct {
	Installers []Installer     `yaml:"installers"`
	Bundles    []Bundle        `yaml:"bundles"`
	Debloat    DebloatConfig   `yaml:"debloat"`
	Brave      BraveConfig     `yaml:"brave"`
	Wallpaper  WallpaperConfig `yaml:"wallpaper"`
	Shell      ShellConfig     `yaml:"shell"`
	RTSS       RTSSConfig      `yaml:"rtss"`
}

type Installer struct {
	Name         string `yaml:"name"`
	WingetID     string `yaml:"wingetId"`
	InstallerURL string `yaml:"installerUrl"`
	SilentArgs   string `yaml:"silentArgs"`
}

type Bundle struct {
	Name       string            `yaml:"name"`
	ArchiveURL string            `yaml:"archiveUrl"`
	Installer  BundleInstaller   `yaml:"installer"`
	Additional []BundleInstaller `yaml:"additionalInstallers"`
}

type BundleInstaller struct {
	Name          string `yaml:"name"`
	InstallerFile string `yaml:"installerFile"`
	SilentArgs    string `yaml:"silentArgs"`
}

type DebloatConfig struct {
	EnableRestorePoint *bool `yaml:"enableRestorePoint"`
	RunWinUtil         *bool `yaml:"runWinUtil"`
	RunWin11Debloat    *bool `yaml:"runWin11Debloat"`
}

type BraveConfig struct {
	Enabled         bool     `yaml:"enabled"`
	StartupURLs     []string `yaml:"startupUrls"`
	EnabledFlags    []string `yaml:"enabledFlags"`
	DisabledFlags   []string `yaml:"disabledFlags"`
	ClearDataOnExit bool     `yaml:"clearDataOnExit"`
	HideTopSites    bool     `yaml:"hideTopSites"`
}

type WallpaperConfig struct {
	Source      string `yaml:"source"`
	Destination string `yaml:"destination"`
}

type ShellConfig struct {
	UnpinStart       bool `yaml:"unpinStart"`
	ClearTaskbar     bool `yaml:"clearTaskbar"`
	HideDesktopIcons bool `yaml:"hideDesktopIcons"`
	AutoHideTaskbar  bool `yaml:"autoHideTaskbar"`
}

type RTSSConfig struct {
	OverlayPath string `yaml:"overlayPath"`
}

func main() {
	configPath := flag.String("config", "config.yaml", "Path to YAML configuration file")
	flag.Parse()

	cfg, err := loadConfig(*configPath)
	if err != nil {
		fmt.Fprintf(os.Stderr, "failed to load config: %v\n", err)
		os.Exit(1)
	}

	script := buildPowerShellScript(cfg)
	fmt.Println(script)
}

func loadConfig(path string) (Config, error) {
	data, err := os.ReadFile(path)
	if err != nil {
		return Config{}, err
	}

	var cfg Config
	if err := yaml.Unmarshal(data, &cfg); err != nil {
		return Config{}, err
	}

	applyDefaults(&cfg)
	return cfg, nil
}

func applyDefaults(cfg *Config) {
	defaultBool(&cfg.Debloat.EnableRestorePoint, true)
	defaultBool(&cfg.Debloat.RunWinUtil, true)
	defaultBool(&cfg.Debloat.RunWin11Debloat, true)

	if cfg.Brave.Enabled {
		if len(cfg.Brave.EnabledFlags) == 0 {
			cfg.Brave.EnabledFlags = []string{
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
				"brave-adblock-cosmetic-filtering-sync-load@1",
			}
		}

		if len(cfg.Brave.DisabledFlags) == 0 {
			cfg.Brave.DisabledFlags = []string{
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
				"webxr-incubations",
			}
		}

		if len(cfg.Brave.StartupURLs) == 0 {
			cfg.Brave.StartupURLs = []string{"https://start.duckduckgo.com", "https://github.com"}
		}
	}

	if cfg.Wallpaper.Destination == "" && cfg.Wallpaper.Source != "" {
		cfg.Wallpaper.Destination = "$env:LOCALAPPDATA\\Microsoft\\Windows\\Themes\\CustomWallpaper.jpg"
	}

	if cfg.RTSS.OverlayPath == "" {
		cfg.RTSS.OverlayPath = "assets/rtss/custom.ovl"
	}
}

func buildPowerShellScript(cfg Config) string {
	var sections []string

	sections = append(sections, buildHeader())

	if len(cfg.Installers) > 0 {
		sections = append(sections, buildWingetInstallers(cfg.Installers))
	}

	vendorInstallers := filterVendorInstallers(cfg.Installers)
	if len(vendorInstallers) > 0 {
		sections = append(sections, buildVendorInstallers(vendorInstallers))
	}

	if len(cfg.Bundles) > 0 {
		sections = append(sections, buildBundleSection(cfg.Bundles))
	}

	sections = append(sections, buildDebloatSection(cfg.Debloat))

	if cfg.Brave.Enabled {
		sections = append(sections, buildBraveSection(cfg.Brave))
	}

	if cfg.Wallpaper.Source != "" {
		sections = append(sections, buildWallpaperSection(cfg.Wallpaper))
	}

	if cfg.Shell.UnpinStart || cfg.Shell.ClearTaskbar || cfg.Shell.HideDesktopIcons || cfg.Shell.AutoHideTaskbar {
		sections = append(sections, buildShellSection(cfg.Shell))
	}

	if cfg.RTSS.OverlayPath != "" {
		sections = append(sections, buildRtssSection(cfg.RTSS))
	}

	sections = append(sections, buildFooter())

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

func buildWingetInstallers(installers []Installer) string {
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

func buildVendorInstallers(installers []Installer) string {
	var sb strings.Builder
	sb.WriteString("# Install vendor-provided packages\n")

	for _, app := range installers {
		safeName := strings.ReplaceAll(app.Name, " ", "-")
		sb.WriteString(fmt.Sprintf(`Write-Host "Installing %s from vendor package..." -ForegroundColor Green
$download = Join-Path $env:TEMP "%s"
Invoke-WebRequest -Uri "%s" -OutFile $download
Start-Process -FilePath $download -ArgumentList "%s" -Wait

`, app.Name, safeName, app.InstallerURL, app.SilentArgs))
	}

	return strings.TrimSpace(sb.String())
}

func buildBundleSection(bundles []Bundle) string {
	var sb strings.Builder
	sb.WriteString("# Install bundled packages (archives containing multiple installers)\n")

	for _, bundle := range bundles {
		safeName := strings.ReplaceAll(bundle.Name, " ", "-")
		sb.WriteString(fmt.Sprintf(`Write-Host "Installing %s bundle..." -ForegroundColor Green
$bundleZip = Join-Path $env:TEMP "%s.zip"
$bundleDir = Join-Path $env:TEMP "%s"
Invoke-WebRequest -Uri "%s" -OutFile $bundleZip
Expand-Archive -Path $bundleZip -DestinationPath $bundleDir -Force

$primaryExe = Join-Path $bundleDir "%s"
Start-Process -FilePath $primaryExe -ArgumentList "%s" -Wait
`, bundle.Name, safeName, safeName, bundle.ArchiveURL, bundle.Installer.InstallerFile, bundle.Installer.SilentArgs))

		for _, addl := range bundle.Additional {
			sb.WriteString(fmt.Sprintf(`$extraExe = Join-Path $bundleDir "%s"
if (Test-Path $extraExe) {
    Write-Host "Installing %s from bundle..." -ForegroundColor Green
    Start-Process -FilePath $extraExe -ArgumentList "%s" -Wait
}
`, addl.InstallerFile, addl.Name, addl.SilentArgs))
		}

		sb.WriteString("\n")
	}

	return strings.TrimSpace(sb.String())
}

func buildDebloatSection(cfg DebloatConfig) string {
	var sb strings.Builder
	sb.WriteString("# Debloat and optimize using community scripts\n")

	if boolValue(cfg.EnableRestorePoint) {
		sb.WriteString(strings.TrimSpace(`Write-Host "Creating a system restore point before debloating..." -ForegroundColor Yellow
try {
    Checkpoint-Computer -Description "Pre-WinDebloat" -RestorePointType MODIFY_SETTINGS | Out-Null
    Write-Host "Restore point created." -ForegroundColor Green
} catch {
    Write-Warning "Failed to create restore point. Continuing without it."
}

`))
		sb.WriteString("\n")
	}

	if boolValue(cfg.RunWinUtil) {
		sb.WriteString(strings.TrimSpace(`Write-Host "Running Chris Titus Tech WinUtil..." -ForegroundColor Green
Invoke-Expression (Invoke-WebRequest -Uri "https://christitus.com/win" -UseBasicParsing).Content

`))
	}

	if boolValue(cfg.RunWin11Debloat) {
		sb.WriteString(strings.TrimSpace(`Write-Host "Running Win11Debloat..." -ForegroundColor Green
$debloatTemp = Join-Path $env:TEMP "Win11Debloat"
if (-not (Test-Path $debloatTemp)) { New-Item -Path $debloatTemp -ItemType Directory | Out-Null }
Invoke-WebRequest -Uri "https://raw.githubusercontent.com/Raphire/Win11Debloat/main/Win11Debloat.ps1" -OutFile (Join-Path $debloatTemp "Win11Debloat.ps1")
Set-ExecutionPolicy -Scope Process Bypass -Force
& powershell -ExecutionPolicy Bypass -File (Join-Path $debloatTemp "Win11Debloat.ps1")
`))
	}

	return strings.TrimSpace(sb.String())
}

func defaultBool(target **bool, defaultValue bool) {
	if *target == nil {
		*target = ptrBool(defaultValue)
	}
}

func boolValue(value *bool) bool {
	if value == nil {
		return false
	}

	return *value
}

func ptrBool(value bool) *bool {
	return &value
}

func buildBraveSection(cfg BraveConfig) string {
	braveFlags := fmt.Sprintf(`$enabledFlags = @(
    "%s"
)`, strings.Join(cfg.EnabledFlags, "\"\n    \""))
	disabledFlags := fmt.Sprintf(`$disabledFlags = @(
    "%s"
)`, strings.Join(cfg.DisabledFlags, "\"\n    \""))

	startupURLs := fmt.Sprintf("@(%s)", quoteStrings(cfg.StartupURLs))

	var sb strings.Builder
	sb.WriteString("# Apply Brave Browser configuration\n")
	sb.WriteString(strings.TrimSpace(fmt.Sprintf(`$braveUserData = Join-Path $env:LOCALAPPDATA "BraveSoftware/Brave-Browser/User Data"
$profilePath = Join-Path $braveUserData "Default"
$preferencesPath = Join-Path $profilePath "Preferences"
$localStatePath = Join-Path $braveUserData "Local State"

%s

%s

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
    $Json.Value.brave.new_tab_page_show_top_sites = $%t
    $Json.Value.brave.welcome_tour_completed = $true
    $Json.Value.brave.sync_promo_shown = $true

    if (-not $Json.Value.PSObject.Properties.Match("session").Count) {
        $Json.Value.session = @{}
    }
    $Json.Value.session.restore_on_startup = 4
    $Json.Value.session.urls_to_restore_on_startup = %s
}

Update-JsonFile -Path $localStatePath -Update {
    param([ref]$Json)
    if (-not $Json.Value.PSObject.Properties.Match("browser").Count) {
        $Json.Value.browser = @{}
    }

    $Json.Value.browser.enabled_labs_experiments = $enabledFlags
    $Json.Value.browser.disabled_labs_experiments = $disabledFlags
`, braveFlags, disabledFlags, cfg.HideTopSites, startupURLs)))

	if cfg.ClearDataOnExit {
		sb.WriteString("    $Json.Value.browser.clear_data = @{on_exit = @{ cache = $true; cookies = $true; history = $true }}\n")
	}

	sb.WriteString("}\n`)")

	return sb.String()
}

func quoteStrings(values []string) string {
	if len(values) == 0 {
		return ""
	}
	quoted := make([]string, len(values))
	for i, v := range values {
		quoted[i] = fmt.Sprintf("\"%s\"", v)
	}
	return strings.Join(quoted, ", ")
}

func buildWallpaperSection(cfg WallpaperConfig) string {
	return strings.TrimSpace(fmt.Sprintf(`# Set wallpaper
$wallpaperSource = "%s"
$wallpaperTarget = "%s"
$wallpaperDir = Split-Path -Parent $wallpaperTarget
if (-not (Test-Path $wallpaperDir)) { New-Item -ItemType Directory -Force -Path $wallpaperDir | Out-Null }

if ($wallpaperSource -match '^https?://') {
    Write-Host "Downloading wallpaper from $wallpaperSource..." -ForegroundColor Green
    Invoke-WebRequest -Uri $wallpaperSource -OutFile $wallpaperTarget
} else {
    $resolvedSource = Join-Path $PSScriptRoot $wallpaperSource
    if (-not (Test-Path $resolvedSource)) {
        Write-Warning "Wallpaper not found at $resolvedSource"
    } else {
        Copy-Item -Path $resolvedSource -Destination $wallpaperTarget -Force
    }
}

reg add "HKCU\\Control Panel\\Desktop" /v Wallpaper /t REG_SZ /d "$wallpaperTarget" /f | Out-Null
rundll32.exe user32.dll, UpdatePerUserSystemParameters
`, cfg.Source, cfg.Destination))
}

func buildShellSection(cfg ShellConfig) string {
	var sb strings.Builder
	sb.WriteString("# Shell/UI cleanup\n")

	if cfg.UnpinStart {
		sb.WriteString(strings.TrimSpace(`Write-Host "Resetting pinned Start entries..." -ForegroundColor Green
$startLayoutPath = Join-Path $env:LOCALAPPDATA "Packages\Microsoft.Windows.StartMenuExperienceHost_cw5n1h2txyewy\LocalState"
Get-ChildItem $startLayoutPath -Filter "start*.bin" -ErrorAction SilentlyContinue | Remove-Item -Force -ErrorAction SilentlyContinue
Stop-Process -Name StartMenuExperienceHost -Force -ErrorAction SilentlyContinue

`))
		sb.WriteString("\n")
	}

	if cfg.ClearTaskbar {
		sb.WriteString(strings.TrimSpace(`Write-Host "Clearing pinned taskbar shortcuts..." -ForegroundColor Green
$taskbarPins = Join-Path $env:APPDATA "Microsoft\Internet Explorer\Quick Launch\User Pinned\TaskBar"
Get-ChildItem $taskbarPins -Filter "*.lnk" -ErrorAction SilentlyContinue | Remove-Item -Force -ErrorAction SilentlyContinue
`))
		sb.WriteString("\n")
	}

	if cfg.HideDesktopIcons {
		sb.WriteString(strings.TrimSpace(`Write-Host "Hiding desktop icons..." -ForegroundColor Green
Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name HideIcons -Value 1
`))
		sb.WriteString("\n")
	}

	if cfg.AutoHideTaskbar {
		sb.WriteString(strings.TrimSpace(`Write-Host "Enabling taskbar auto-hide..." -ForegroundColor Green
Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\StuckRects3" -Name Settings -Value ([byte[]]("30,00,00,00,fe,ff,ff,ff,02,00,00,00,03,00,00,00,3c,00,00,00,3c,00,00,00,3c,00,00,00,00,00,00,00,00,00,00,00,00,00,00,00,00,00,00,00,00,00,00,00,00,00,00,00,00,00,00,00,00,00,00" -split ','))
`))
		sb.WriteString("\n")
	}

	sb.WriteString(strings.TrimSpace(`Write-Host "Restarting Explorer to apply shell changes..." -ForegroundColor Yellow
Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue
Start-Process explorer.exe
`))

	return strings.TrimSpace(sb.String())
}

func buildRtssSection(cfg RTSSConfig) string {
	return strings.TrimSpace(fmt.Sprintf(`# Import RTSS overlay
$overlaySource = Join-Path $PSScriptRoot "%s"
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
`, cfg.OverlayPath))
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

func filterVendorInstallers(installers []Installer) []Installer {
	var vendor []Installer
	for _, inst := range installers {
		if inst.WingetID == "" && inst.InstallerURL != "" {
			vendor = append(vendor, inst)
		}
	}
	return vendor
}
