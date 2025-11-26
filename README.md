# Windows Post-Installation Automation

A declarative automation system for Windows post-installation tasks. Configure everything in YAML and let the script handle the rest!

## 🚀 Features

- **Declarative Configuration**: Define your entire Windows setup in a single YAML file
- **Safety First**: Automatic restore point creation and registry backup before making changes
- **Software Installation**: Automated installation via Winget
- **Driver Updates**: NVIDIA driver updates via NVCleanstall integration
- **System Optimization**: Integration with CTT WinUtil and Win11Debloat
- **Privacy & Debloating**: Remove bloatware, disable telemetry, and apply privacy tweaks
- **Custom Tweaks**: Registry modifications, service configuration, and scheduled task management
- **Comprehensive Logging**: Detailed logs of all operations
- **Dry Run Mode**: Preview changes before applying them

## 📋 Prerequisites

- Windows 10 or Windows 11
- PowerShell 5.1 or higher
- Administrator privileges
- Internet connection (for downloading tools and software)

## 🔧 Installation

1. **Clone or download this repository**:
   ```powershell
   git clone https://github.com/yourusername/windoze-automation.git
   cd windoze-automation
   ```

2. **Review and customize the configuration**:
   - Open `config.yaml` in your favorite text editor
   - Enable/disable features as needed
   - Add or remove software packages
   - Customize tweaks and optimizations

3. **Run the automation script**:
   ```powershell
   # Run with default config
   .\Install-WindowsAutomation.ps1

   # Preview changes without applying (dry run)
   .\Install-WindowsAutomation.ps1 -DryRun

   # Use a custom config file
   .\Install-WindowsAutomation.ps1 -ConfigPath "C:\path\to\custom-config.yaml"
   ```

## 📝 Configuration Guide

The `config.yaml` file is organized into sections:

### General Settings
```yaml
general:
  create_restore_point: true
  backup_registry: true
  registry_backup_path: "C:\\Backups\\Registry"
  log_path: "C:\\Logs\\WindowsAutomation"
  reboot_after_completion: false
```

### Software Installation
```yaml
software:
  enabled: true
  install_method: "winget"
  packages:
    - id: "Mozilla.Firefox"
      name: "Firefox"
      enabled: true
```

Add any software available in the Winget repository. Find package IDs at [winget.run](https://winget.run/).

### Driver Updates
```yaml
drivers:
  enabled: true
  nvidia:
    enabled: true
    use_nvcleanstall: true
```

**Note**: NVCleanstall requires manual setup. Download from [TechPowerUp](https://www.techpowerup.com/nvcleanstall/).

### CTT WinUtil Integration
```yaml
ctt_winutil:
  enabled: true
  tweaks:
    - name: "WPFTweaksDisableTelemetry"
      description: "Disable Telemetry"
      enabled: true
```

**Note**: CTT WinUtil is primarily GUI-based. The script will guide you to run it manually or you can implement preset-based automation.

### Win11Debloat Integration
```yaml
win11debloat:
  enabled: true
  options:
    remove_apps: true
    disable_telemetry: true
    disable_bing: true
  custom_apps_to_remove:
    - "Microsoft.BingNews"
    - "Microsoft.GamingApp"
```

### Registry Tweaks
```yaml
registry_tweaks:
  enabled: true
  tweaks:
    - path: "HKCU:\\Software\\Microsoft\\Windows\\CurrentVersion\\Search"
      name: "BingSearchEnabled"
      value: 0
      type: "DWord"
      description: "Disable Bing in Windows Search"
```

### Services Configuration
```yaml
services:
  enabled: true
  services_to_disable:
    - name: "DiagTrack"
      description: "Connected User Experiences and Telemetry"
```

### Scheduled Tasks
```yaml
scheduled_tasks:
  enabled: true
  tasks_to_disable:
    - "\\Microsoft\\Windows\\Application Experience\\Microsoft Compatibility Appraiser"
```

## 🎯 Usage Examples

### Basic Usage
```powershell
# Run with administrator privileges
.\Install-WindowsAutomation.ps1
```

### Preview Changes (Recommended First Run)
```powershell
.\Install-WindowsAutomation.ps1 -DryRun
```

### Custom Configuration
```powershell
.\Install-WindowsAutomation.ps1 -ConfigPath ".\configs\gaming-pc.yaml"
```

## 🔒 Safety Features

1. **System Restore Point**: Automatically created before any changes
2. **Registry Backup**: Full registry backup saved to specified location
3. **Dry Run Mode**: Preview all changes without applying them
4. **Comprehensive Logging**: All operations logged with timestamps
5. **Error Handling**: Graceful failure handling with detailed error messages

## 📊 What Gets Automated

### ✅ Fully Automated
- ✔️ System restore point creation
- ✔️ Registry backup
- ✔️ Software installation via Winget
- ✔️ Win11Debloat execution
- ✔️ Registry tweaks
- ✔️ Service configuration
- ✔️ Scheduled task management
- ✔️ Post-installation scripts

### ⚠️ Requires Manual Steps
- ⚠️ CTT WinUtil (GUI-based, can be run separately)
- ⚠️ NVCleanstall (requires initial setup and configuration)

## 🛠️ Advanced Configuration

### Creating Multiple Profiles

Create different configuration files for different scenarios:

```
configs/
  ├── gaming-pc.yaml
  ├── work-laptop.yaml
  ├── minimal-install.yaml
  └── developer-setup.yaml
```

Run with specific profile:
```powershell
.\Install-WindowsAutomation.ps1 -ConfigPath ".\configs\gaming-pc.yaml"
```

### Adding Custom Software

Find Winget package IDs:
```powershell
winget search "application name"
```

Add to `config.yaml`:
```yaml
- id: "Package.ID"
  name: "Friendly Name"
  enabled: true
```

### Custom Registry Tweaks

Add your own registry modifications:
```yaml
registry_tweaks:
  tweaks:
    - path: "HKCU:\\Path\\To\\Key"
      name: "ValueName"
      value: 1
      type: "DWord"  # Options: String, DWord, QWord, Binary
      description: "What this tweak does"
```

## 📁 Project Structure

```
windoze-automation/
├── Install-WindowsAutomation.ps1  # Main automation script
├── config.yaml                     # Default configuration
├── README.md                       # This file
└── Logs/                          # Generated logs (created automatically)
```

## 🐛 Troubleshooting

### Script Won't Run
- Ensure you're running PowerShell as Administrator
- Check execution policy: `Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser`

### Winget Not Found
- Install "App Installer" from Microsoft Store
- Or download from: https://github.com/microsoft/winget-cli/releases

### PowerShell-Yaml Module Issues
- The script will automatically install it
- Manual install: `Install-Module -Name powershell-yaml -Force`

### Restore Point Creation Fails
- Enable System Protection for C: drive in System Properties
- Ensure you have sufficient disk space

## 🔗 Related Projects

- [CTT WinUtil](https://github.com/ChrisTitusTech/winutil) - Comprehensive Windows utility
- [Win11Debloat](https://github.com/Raphire/Win11Debloat) - Windows 11 debloating tool
- [NVCleanstall](https://www.techpowerup.com/nvcleanstall/) - Clean NVIDIA driver installer

## 📜 License

MIT License - Feel free to use and modify as needed.

## 🤝 Contributing

Contributions are welcome! Please feel free to submit pull requests or open issues for bugs and feature requests.

## ⚠️ Disclaimer

This script makes system-wide changes to your Windows installation. While it includes safety features like restore points and registry backups, use at your own risk. Always test in a non-production environment first.

## 📞 Support

- Open an issue on GitHub
- Check the logs in the configured log directory
- Review the configuration file for syntax errors

## 🗺️ Roadmap

- [ ] Full CTT WinUtil preset integration
- [ ] NVCleanstall command-line automation
- [ ] GUI configuration editor
- [ ] Pre-built configuration profiles
- [ ] Rollback functionality
- [ ] Remote configuration management
- [ ] Windows Update automation
- [ ] Chocolatey support as alternative to Winget

## 📚 Additional Resources

- [Winget Package Repository](https://winget.run/)
- [Windows Registry Reference](https://docs.microsoft.com/en-us/windows/win32/sysinfo/registry)
- [PowerShell Documentation](https://docs.microsoft.com/en-us/powershell/)

---

**Made with ❤️ for Windows power users**

