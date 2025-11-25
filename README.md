# windoze-automation

A Go-based Windows post-install automation script that provisions core apps, runs debloat tools, tunes Brave Browser settings/flags, and imports a custom RTSS overlay.

## How it works
- Generates a single PowerShell script that:
  - Installs apps via `winget` or vendor packages (OBS, Brave, 1Password, Steam, Epic Games, DaVinci Resolve Studio, HWInfo, Cinebench R23, RustDesk, MSI Afterburner, RTSS).
  - Runs both Chris Titus Tech WinUtil and the Win11Debloat script for cleanup/tuning.
  - Applies Brave profile defaults (startup pages, hides top sites, enables lab flags, clears data on exit).
  - Copies a custom `.ovl` overlay into the RTSS profiles folder.
- The Go binary just prints the PowerShell payload to stdout so you can review/pipe it directly into PowerShell.

## Prerequisites
- Windows 11 with PowerShell and winget available.
- Admin (elevated) PowerShell session to allow installers and debloat scripts to run.
- If you want the RTSS overlay import, place your overlay at `assets/rtss/custom.ovl` before building.

## Quick start
1. From an elevated PowerShell prompt, install Go and build the tool (optional, bootstrap script can do this):
   ```powershell
   Set-ExecutionPolicy -Scope Process Bypass -Force
   .\scripts\bootstrap.ps1 -Build
   ```
2. Generate and run the automation script:
   ```powershell
   .\windoze-automation.exe | powershell -NoProfile -ExecutionPolicy Bypass
   ```
   You can also redirect output to a `.ps1` file if you prefer to inspect before running.

## Notes
- The script uses `winget` IDs for most apps and falls back to vendor downloads for MSI Afterburner/RTSS.
- Brave settings are applied to the `Default` profile. Adjust the JSON in `buildBraveSection` if you want different defaults.
- Debloat scripts are executed as-is from their upstream sources. Review before running if you need tighter control.
