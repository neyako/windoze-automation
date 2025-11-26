# Troubleshooting Guide

Common issues and their solutions for Windows Automation.

## 🚨 Common Issues

### 1. Script Won't Run - "Running scripts is disabled"

**Error:**
```
File cannot be loaded because running scripts is disabled on this system.
```

**Solution:**
```powershell
# Run this in PowerShell as Administrator
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

**Alternative:**
```powershell
# Bypass for single session
PowerShell -ExecutionPolicy Bypass -File .\Install-WindowsAutomation.ps1
```

---

### 2. "Winget: The term 'winget' is not recognized"

**Cause:** App Installer not installed or not in PATH

**Solution:**

**Option A: Install from Microsoft Store**
1. Open Microsoft Store
2. Search for "App Installer"
3. Install/Update it

**Option B: Direct Download**
```powershell
# Download latest App Installer
$url = "https://aka.ms/getwinget"
$output = "$env:TEMP\Microsoft.DesktopAppInstaller.msixbundle"
Invoke-WebRequest -Uri $url -OutFile $output
Add-AppxPackage -Path $output
```

**Option C: Use Chocolatey Instead**
Modify `config.yaml`:
```yaml
software:
  install_method: "chocolatey"
```

---

### 3. "Access Denied" or Permission Errors

**Cause:** Not running as Administrator

**Solution:**
1. Close PowerShell
2. Right-click PowerShell
3. Select "Run as Administrator"
4. Navigate to script directory
5. Run script again

**Verify Admin Rights:**
```powershell
# This should return True
([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
```

---

### 4. "Cannot find path" or "File not found"

**Cause:** Working directory or file path issue

**Solution:**
```powershell
# Navigate to script directory first
cd C:\path\to\windoze-automation

# Then run the script
.\Install-WindowsAutomation.ps1
```

**Check Config Path:**
```powershell
# Verify config.yaml exists
Test-Path .\config.yaml

# Use absolute path if needed
.\Install-WindowsAutomation.ps1 -ConfigPath "C:\full\path\to\config.yaml"
```

---

### 5. YAML Parsing Errors

**Error:**
```
Failed to parse configuration file: ...
```

**Common YAML Mistakes:**

❌ **Wrong:**
```yaml
software:
  enabled: yes  # Use true/false, not yes/no
```

✅ **Correct:**
```yaml
software:
  enabled: true
```

❌ **Wrong:**
```yaml
packages:
- id: Mozilla.Firefox  # Missing quotes with special characters
```

✅ **Correct:**
```yaml
packages:
  - id: "Mozilla.Firefox"
```

❌ **Wrong:**
```yaml
path: C:\Windows\System32  # Backslashes need escaping
```

✅ **Correct:**
```yaml
path: "C:\\Windows\\System32"
# OR
path: 'C:\Windows\System32'
```

**Validate YAML:**
```powershell
# Test YAML syntax
$yaml = Get-Content .\config.yaml -Raw
ConvertFrom-Yaml $yaml
```

---

### 6. Restore Point Creation Fails

**Error:**
```
Failed to create restore point
```

**Solutions:**

**Enable System Protection:**
1. Press `Win + R`
2. Type `sysdm.cpl` and press Enter
3. Go to "System Protection" tab
4. Select C: drive
5. Click "Configure"
6. Enable "Turn on system protection"
7. Set disk space usage (at least 5%)

**Via PowerShell:**
```powershell
# Enable System Restore on C:
Enable-ComputerRestore -Drive "C:\"

# Check status
Get-ComputerRestorePoint
```

**Workaround:**
Set in `config.yaml`:
```yaml
general:
  create_restore_point: false
```

---

### 7. Registry Backup Fails

**Error:**
```
Failed to backup registry
```

**Solutions:**

**Check Disk Space:**
```powershell
Get-PSDrive C | Select-Object Used,Free
```

**Check Permissions:**
```powershell
# Ensure backup directory is writable
$path = "C:\Backups\Registry"
New-Item -Path $path -ItemType Directory -Force
```

**Change Backup Location:**
```yaml
general:
  registry_backup_path: "D:\\Backups\\Registry"  # Use different drive
```

---

### 8. Software Installation Fails

**Issue:** Some packages fail to install

**Diagnosis:**
```powershell
# Check if package exists
winget search "package name"

# Try manual install
winget install --id Package.ID

# Check logs
Get-Content "C:\Logs\WindowsAutomation\automation_*.log" | Select-String "Failed"
```

**Solutions:**

**Update Winget:**
```powershell
# Update App Installer from Microsoft Store
winget upgrade --id Microsoft.AppInstaller
```

**Check Package ID:**
```powershell
# Get exact package ID
winget search --exact "Firefox"
```

**Disable Problematic Packages:**
```yaml
packages:
  - id: "Problematic.Package"
    enabled: false  # Disable temporarily
```

---

### 9. Win11Debloat Download Fails

**Error:**
```
Failed to download Win11Debloat
```

**Solutions:**

**Check Internet Connection:**
```powershell
Test-NetConnection github.com -Port 443
```

**Manual Download:**
```powershell
# Download manually
$url = "https://raw.githubusercontent.com/Raphire/Win11Debloat/master/Win11Debloat.ps1"
$output = "C:\Temp\Win11Debloat.ps1"
Invoke-WebRequest -Uri $url -OutFile $output

# Run manually
& $output -Silent -RemoveApps -DisableTelemetry
```

**Disable in Config:**
```yaml
win11debloat:
  enabled: false
```

---

### 10. "Cannot remove AppxPackage" Errors

**Issue:** Some apps can't be removed

**Cause:** System apps or apps in use

**Solutions:**

**Check if App is Running:**
```powershell
# Close all instances of the app first
Get-Process | Where-Object {$_.ProcessName -like "*AppName*"} | Stop-Process -Force
```

**Remove for All Users:**
```powershell
Get-AppxPackage -AllUsers -Name "*AppName*" | Remove-AppxPackage -AllUsers
```

**Prevent Reinstall:**
```powershell
Get-AppxProvisionedPackage -Online | Where-Object {$_.DisplayName -like "*AppName*"} | Remove-AppxProvisionedPackage -Online
```

---

### 11. Registry Tweaks Not Applied

**Issue:** Registry changes don't take effect

**Solutions:**

**Verify Changes:**
```powershell
# Check if value was set
Get-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Search" -Name "BingSearchEnabled"
```

**Restart Explorer:**
```powershell
# Restart Windows Explorer to apply changes
Stop-Process -Name explorer -Force
```

**Reboot System:**
Some changes require a full reboot to take effect.

---

### 12. Services Won't Disable

**Error:**
```
Failed to disable service: Access Denied
```

**Solution:**

**Use SYSTEM Privileges:**
```powershell
# Some services need SYSTEM privileges
PsExec.exe -s -i PowerShell.exe
# Then run the script
```

**Check Service Dependencies:**
```powershell
# Check what depends on the service
Get-Service -Name "ServiceName" | Select-Object -ExpandProperty DependentServices
```

**Manual Disable:**
```powershell
# Disable via registry
Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\ServiceName" -Name "Start" -Value 4
```

---

### 13. Scheduled Tasks Errors

**Issue:** Can't disable certain scheduled tasks

**Solutions:**

**Check Task Exists:**
```powershell
Get-ScheduledTask | Where-Object {$_.TaskPath -like "*Microsoft*"}
```

**Use Task Scheduler GUI:**
1. Press `Win + R`
2. Type `taskschd.msc`
3. Navigate to the task
4. Right-click → Disable

**Export Task List:**
```powershell
Get-ScheduledTask | Select-Object TaskName, State, TaskPath | Export-Csv tasks.csv
```

---

### 14. PowerShell-Yaml Module Issues

**Error:**
```
Failed to install powershell-yaml
```

**Solutions:**

**Update PowerShellGet:**
```powershell
Install-Module -Name PowerShellGet -Force -AllowClobber
```

**Manual Install:**
```powershell
# Install NuGet provider first
Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force

# Then install module
Install-Module -Name powershell-yaml -Force -Scope CurrentUser
```

**Alternative: Use JSON Config**
Convert your YAML to JSON if needed.

---

### 15. Dry Run Shows Errors

**Issue:** Errors appear even in dry run mode

**Cause:** Some checks run even in dry run

**Solution:**
Review the errors and fix configuration before actual run:

```powershell
# Check logs for details
Get-Content "C:\Logs\WindowsAutomation\automation_*.log" | Select-String "Error"
```

---

## 🔍 Diagnostic Commands

### Check System Status
```powershell
# Windows version
Get-ComputerInfo | Select-Object WindowsProductName, WindowsVersion, OsArchitecture

# PowerShell version
$PSVersionTable.PSVersion

# Execution policy
Get-ExecutionPolicy -List

# Admin rights
([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
```

### Check Installed Software
```powershell
# Via Winget
winget list

# Via PowerShell
Get-Package

# Installed apps
Get-AppxPackage | Select-Object Name, Version
```

### Check Services
```powershell
# List all services
Get-Service | Sort-Object Status

# Check specific service
Get-Service -Name "DiagTrack"
```

### Check Logs
```powershell
# View latest log
Get-ChildItem "C:\Logs\WindowsAutomation\" | Sort-Object LastWriteTime -Descending | Select-Object -First 1 | Get-Content

# Search for errors
Get-Content "C:\Logs\WindowsAutomation\automation_*.log" | Select-String "Error|Failed"
```

---

## 🆘 Getting Help

### 1. Check the Logs
```powershell
# View full log
notepad "C:\Logs\WindowsAutomation\automation_YYYYMMDD_HHMMSS.log"
```

### 2. Run in Dry Run Mode
```powershell
.\Install-WindowsAutomation.ps1 -DryRun
```

### 3. Test Individual Components

**Test Winget:**
```powershell
winget search firefox
winget install --id Mozilla.Firefox --dry-run
```

**Test Registry Access:**
```powershell
Test-Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Search"
```

**Test Service Access:**
```powershell
Get-Service -Name "DiagTrack"
```

### 4. Validate Configuration
```powershell
# Load and check config
Import-Module powershell-yaml
$config = Get-Content .\config.yaml -Raw | ConvertFrom-Yaml
$config.general
```

---

## 🔄 Recovery Options

### Restore from Restore Point
```powershell
# List restore points
Get-ComputerRestorePoint

# Restore via GUI
rstrui.exe
```

### Restore Registry
```powershell
# Import registry backup
reg import "C:\Backups\Registry\registry_backup_YYYYMMDD_HHMMSS.reg"
```

### Re-enable Services
```powershell
# Re-enable a service
Set-Service -Name "ServiceName" -StartupType Automatic
Start-Service -Name "ServiceName"
```

### Reinstall Removed Apps
```powershell
# Reinstall from Microsoft Store
# Or use Winget
winget install --id "Microsoft.AppName"
```

---

## 📞 Still Need Help?

1. **Check the logs** in `C:\Logs\WindowsAutomation\`
2. **Review your config.yaml** for syntax errors
3. **Run with `-DryRun`** to see what would happen
4. **Open an issue** on GitHub with:
   - Your log file
   - Your config.yaml (remove sensitive info)
   - Windows version
   - Error message

---

**Remember:** Always create a restore point before making system changes!

