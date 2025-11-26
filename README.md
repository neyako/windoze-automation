# windoze-automation

A Go-based Windows post-install automation script that provisions core apps, runs debloat tools, tunes Brave Browser settings/flags, optionally applies a wallpaper, hides Start/taskbar/desktop items, and imports a custom RTSS overlay.

## How it works
- Generates a single PowerShell script that:
  - Installs apps via `winget` or vendor packages (OBS, Brave, 1Password, ImageGlass, Steam, Epic Games, DaVinci Resolve Studio, HWInfo, Cinebench R23, RustDesk, K-Lite Codec Pack Full, LocalSend, MSI Afterburner, RTSS).
  - Creates a system restore point before any debloating runs.
  - Runs both Chris Titus Tech WinUtil and the Win11Debloat script for cleanup/tuning.
  - Applies Brave profile defaults and hardening flags from the [brave-browser-hardening](https://gitlab.com/CHEF-KOCH/brave-browser-hardening/-/tree/main) project.
  - Copies a custom `.ovl` overlay into the RTSS profiles folder.
- The Go binary just prints the PowerShell payload to stdout so you can review/pipe it directly into PowerShell.

## Prerequisites
- Windows 11 with PowerShell and winget available.
- Admin (elevated) PowerShell session to allow installers and debloat scripts to run.
- If you want the RTSS overlay import, place your overlay at `assets/rtss/custom.ovl` before building.

## Quick start
1. Copy `config.sample.yaml` to `config.yaml` and adjust the declarative settings (winget IDs/vendor URLs, Brave flags, wallpaper source, and shell cleanup toggles).
2. From an elevated PowerShell prompt, install Go and build the tool (optional, the bootstrap script can do this):
   ```powershell
   Set-ExecutionPolicy -Scope Process Bypass -Force
   .\scripts\bootstrap.ps1 -Build
   ```
3. Generate and run the automation script (uses `config.yaml` by default):
   ```powershell
   .\windoze-automation.exe | powershell -NoProfile -ExecutionPolicy Bypass
   ```
   Use `-config <path>` to point at a different YAML file. You can also redirect output to a `.ps1` file if you prefer to inspect before running.

## Configuration reference
- `installers`: winget-based app installs (name + `wingetId`).
- `bundles`: vendor archives that contain one or more installers (for example, the MSI Afterburner + RTSS zip).
- `debloat`: toggle restore point creation and whether to run WinUtil / Win11Debloat.
- `brave`: enable/disable Brave tuning and override startup URLs, hardening flags, and clear-on-exit behavior.
- `wallpaper`: set a wallpaper from a URL or a relative repo path; the script copies/downloads it and updates the user wallpaper.
- `shell`: hide desktop icons, unpin Start, clear taskbar pins, and enable taskbar auto-hide.
- `rtss`: path to a custom overlay to copy into the RTSS profiles folder.

## Notes
- The script uses `winget` IDs for most apps and falls back to vendor downloads for MSI Afterburner/RTSS.
- Brave settings are applied to the `Default` profile with hardening and privacy-focused flags. Adjust the JSON in `buildBraveSection` if you want different defaults.
- Debloat scripts are executed as-is from their upstream sources. Review before running if you need tighter control.
