# Quick Start Guide

Get your Windows system configured in minutes!

## 🚀 Fast Track (5 Minutes)

### Step 1: Download
```powershell
# Clone the repository
git clone https://github.com/yourusername/windoze-automation.git
cd windoze-automation
```

Or download the ZIP and extract it.

### Step 2: Customize (Optional)
Open `config.yaml` and:
- ✅ Enable/disable software you want
- ✅ Review privacy tweaks
- ✅ Adjust debloat settings

### Step 3: Preview Changes
```powershell
# See what will happen (no changes made)
.\Install-WindowsAutomation.ps1 -DryRun
```

### Step 4: Run It!
```powershell
# Right-click PowerShell → Run as Administrator
.\Install-WindowsAutomation.ps1
```

That's it! ☕ Grab a coffee while it works.

## 📋 What Happens Automatically

1. ✅ **Creates restore point** - Safety first!
2. ✅ **Backs up registry** - Just in case
3. ✅ **Installs software** - All your apps via Winget
4. ✅ **Removes bloatware** - Goodbye unnecessary apps
5. ✅ **Disables telemetry** - Privacy matters
6. ✅ **Applies tweaks** - Performance & usability improvements
7. ✅ **Logs everything** - Check `Logs/` folder

## 🎯 Common Scenarios

### Gaming PC
```yaml
# In config.yaml, enable:
software:
  packages:
    - id: "Valve.Steam"
      enabled: true
    - id: "EpicGames.EpicGamesLauncher"
      enabled: true

drivers:
  nvidia:
    enabled: true
```

### Developer Setup
```yaml
software:
  packages:
    - id: "Microsoft.VisualStudioCode"
      enabled: true
    - id: "Git.Git"
      enabled: true
    - id: "Microsoft.PowerShell"
      enabled: true
    - id: "Docker.DockerDesktop"
      enabled: true
```

### Minimal/Privacy Focused
```yaml
win11debloat:
  enabled: true
  options:
    remove_apps: true
    disable_telemetry: true
    disable_bing: true

registry_tweaks:
  enabled: true  # Disables tracking, Cortana, etc.
```

## ⚡ Pro Tips

### 1. Always Dry Run First
```powershell
.\Install-WindowsAutomation.ps1 -DryRun
```
See what will happen without making changes.

### 2. Check the Logs
```powershell
# Logs are in C:\Logs\WindowsAutomation\ by default
Get-Content "C:\Logs\WindowsAutomation\automation_*.log" -Tail 50
```

### 3. Create Multiple Profiles
```powershell
# Copy config.yaml
Copy-Item config.yaml config-gaming.yaml
Copy-Item config.yaml config-work.yaml

# Use specific profile
.\Install-WindowsAutomation.ps1 -ConfigPath ".\config-gaming.yaml"
```

### 4. Find More Software
```powershell
# Search for apps
winget search "app name"

# Get exact ID
winget search --id "Publisher.AppName"
```

## 🔧 Troubleshooting

### "Cannot be loaded because running scripts is disabled"
```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

### "Winget not found"
Install from Microsoft Store: **App Installer**

### "Access Denied"
Right-click PowerShell → **Run as Administrator**

### Something Broke?
```powershell
# Restore from the restore point created at the start
rstrui.exe
```

## 📱 Quick Commands Reference

```powershell
# Basic run
.\Install-WindowsAutomation.ps1

# Preview only
.\Install-WindowsAutomation.ps1 -DryRun

# Custom config
.\Install-WindowsAutomation.ps1 -ConfigPath ".\my-config.yaml"

# Check Winget packages
winget list

# Search for software
winget search "firefox"

# View logs
Get-Content "C:\Logs\WindowsAutomation\automation_*.log" -Tail 100
```

## 🎓 Next Steps

1. ✅ **Read the full README.md** for detailed configuration options
2. ✅ **Customize config.yaml** to your exact needs
3. ✅ **Run CTT WinUtil manually** for additional GUI-based tweaks:
   ```powershell
   irm https://christitus.com/win | iex
   ```
4. ✅ **Set up NVCleanstall** for clean NVIDIA driver installs
5. ✅ **Create a backup** of your final config.yaml

## ⚠️ Important Notes

- **Always run as Administrator**
- **Restore point is created automatically** before changes
- **Registry is backed up** to `C:\Backups\Registry\`
- **Logs are saved** to `C:\Logs\WindowsAutomation\`
- **Some changes require reboot** to take effect

## 🆘 Need Help?

1. Check the logs in `C:\Logs\WindowsAutomation\`
2. Review your `config.yaml` for syntax errors
3. Try running with `-DryRun` to see what's happening
4. Open an issue on GitHub with your log file

---

**Happy Automating! 🎉**

