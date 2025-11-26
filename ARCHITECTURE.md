# System Architecture

## 🏗️ Architecture Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                         USER LAYER                              │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐         │
│  │  config.yaml │  │ Custom YAML  │  │   Profiles   │         │
│  │   (Default)  │  │    Files     │  │   (Gaming,   │         │
│  │              │  │              │  │     Dev)     │         │
│  └──────┬───────┘  └──────┬───────┘  └──────┬───────┘         │
│         │                 │                 │                  │
│         └─────────────────┴─────────────────┘                  │
│                           │                                     │
└───────────────────────────┼─────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────────┐
│                    ORCHESTRATION LAYER                          │
│                                                                 │
│  ┌───────────────────────────────────────────────────────────┐ │
│  │     Install-WindowsAutomation.ps1 (Main Script)           │ │
│  │                                                            │ │
│  │  ┌──────────────────────────────────────────────────────┐ │ │
│  │  │  Configuration Management                            │ │ │
│  │  │  • Read YAML config                                  │ │ │
│  │  │  • Validate settings                                 │ │ │
│  │  │  • Parse parameters                                  │ │ │
│  │  └──────────────────────────────────────────────────────┘ │ │
│  │                                                            │ │
│  │  ┌──────────────────────────────────────────────────────┐ │ │
│  │  │  Safety Layer                                        │ │ │
│  │  │  • Create restore point                              │ │ │
│  │  │  • Backup registry                                   │ │ │
│  │  │  • Initialize logging                                │ │ │
│  │  └──────────────────────────────────────────────────────┘ │ │
│  │                                                            │ │
│  │  ┌──────────────────────────────────────────────────────┐ │ │
│  │  │  Execution Engine                                    │ │ │
│  │  │  • Software installation                             │ │ │
│  │  │  • System optimization                               │ │ │
│  │  │  • Registry modifications                            │ │ │
│  │  │  • Service management                                │ │ │
│  │  └──────────────────────────────────────────────────────┘ │ │
│  │                                                            │ │
│  │  ┌──────────────────────────────────────────────────────┐ │ │
│  │  │  Logging & Reporting                                 │ │ │
│  │  │  • Console output (colored)                          │ │ │
│  │  │  • File logging                                      │ │ │
│  │  │  • Error tracking                                    │ │ │
│  │  └──────────────────────────────────────────────────────┘ │ │
│  └───────────────────────────────────────────────────────────┘ │
└───────────────────────────┬─────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────────┐
│                    INTEGRATION LAYER                            │
│                                                                 │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐         │
│  │    Winget    │  │ Win11Debloat │  │  CTT WinUtil │         │
│  │   (Package   │  │  (Debloat &  │  │   (Manual    │         │
│  │  Management) │  │   Privacy)   │  │   Tweaks)    │         │
│  └──────┬───────┘  └──────┬───────┘  └──────┬───────┘         │
│         │                 │                 │                  │
└─────────┼─────────────────┼─────────────────┼──────────────────┘
          │                 │                 │
          ▼                 ▼                 ▼
┌─────────────────────────────────────────────────────────────────┐
│                    WINDOWS SYSTEM LAYER                         │
│                                                                 │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐         │
│  │   Registry   │  │   Services   │  │   Scheduled  │         │
│  │              │  │              │  │     Tasks    │         │
│  └──────────────┘  └──────────────┘  └──────────────┘         │
│                                                                 │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐         │
│  │   AppX       │  │    System    │  │    Files     │         │
│  │   Packages   │  │   Settings   │  │              │         │
│  └──────────────┘  └──────────────┘  └──────────────┘         │
└─────────────────────────────────────────────────────────────────┘
```

## 📦 Component Details

### 1. Configuration Layer

**Purpose:** Define what should be done

**Components:**
- `config.yaml` - Default configuration
- `configs/gaming-pc.yaml` - Gaming profile
- `configs/developer-setup.yaml` - Developer profile
- Custom user configurations

**Data Flow:**
```
User edits YAML → YAML Parser → Configuration Object → Execution Engine
```

### 2. Orchestration Layer

**Purpose:** Control execution flow and manage operations

#### 2.1 Configuration Management
```powershell
Read-ConfigFile
├── Load YAML content
├── Parse with PowerShell-Yaml
├── Validate structure
└── Return configuration object
```

#### 2.2 Safety Layer
```powershell
Safety Operations
├── New-SystemRestorePoint
│   ├── Enable System Protection
│   └── Create restore point
├── Backup-RegistryKeys
│   ├── Create backup directory
│   └── Export registry to .reg file
└── Initialize-Logging
    ├── Create log directory
    └── Start log file
```

#### 2.3 Execution Engine
```powershell
Main Execution Flow
├── Install-WingetPackages
│   ├── Check Winget availability
│   ├── Loop through package list
│   └── Install enabled packages
├── Set-RegistryTweaks
│   ├── Create registry paths
│   └── Set registry values
├── Set-ServiceConfiguration
│   ├── Stop services
│   └── Disable services
├── Disable-ScheduledTasksList
│   └── Disable specified tasks
├── Invoke-Win11Debloat
│   ├── Download script
│   ├── Execute with parameters
│   └── Remove custom apps
└── Invoke-PostScripts
    └── Execute custom commands
```

### 3. Integration Layer

**Purpose:** Interface with external tools and systems

#### 3.1 Winget Integration
```
Configuration → Install-WingetPackages → winget CLI → Windows Package Manager
                                                      ↓
                                                  Downloads & Installs
```

#### 3.2 Win11Debloat Integration
```
Configuration → Invoke-Win11Debloat → Download Script → Execute
                                                         ↓
                                                    Remove Apps
                                                    Disable Telemetry
                                                    Apply Tweaks
```

#### 3.3 CTT WinUtil Integration
```
Configuration → Invoke-CTTWinUtil → Download Script → Manual Execution
                                                      (GUI-based)
```

### 4. Windows System Layer

**Purpose:** Actual system modifications

**Modified Components:**
- Registry (HKLM, HKCU)
- Windows Services
- Scheduled Tasks
- AppX Packages
- System Files
- System Settings

## 🔄 Execution Flow

### Standard Execution

```
START
  │
  ├─→ [1] Check Administrator Privileges
  │     ├─ Yes → Continue
  │     └─ No  → Exit with error
  │
  ├─→ [2] Install Prerequisites
  │     └─ PowerShell-Yaml module
  │
  ├─→ [3] Load Configuration
  │     ├─ Read YAML file
  │     ├─ Parse configuration
  │     └─ Validate structure
  │
  ├─→ [4] Initialize Logging
  │     ├─ Create log directory
  │     └─ Start log file
  │
  ├─→ [5] Safety Operations
  │     ├─ Create restore point
  │     └─ Backup registry
  │
  ├─→ [6] Software Installation
  │     ├─ Check Winget
  │     └─ Install packages
  │
  ├─→ [7] Registry Tweaks
  │     ├─ Create paths
  │     └─ Set values
  │
  ├─→ [8] Service Configuration
  │     ├─ Stop services
  │     └─ Disable services
  │
  ├─→ [9] Scheduled Tasks
  │     └─ Disable tasks
  │
  ├─→ [10] Win11Debloat
  │     ├─ Download script
  │     ├─ Execute debloat
  │     └─ Remove custom apps
  │
  ├─→ [11] Post Scripts
  │     └─ Execute custom commands
  │
  ├─→ [12] Completion
  │     ├─ Log summary
  │     └─ Optional reboot
  │
END
```

### Dry Run Mode

```
START
  │
  ├─→ [1-4] Same as standard
  │
  ├─→ [5-11] For each operation:
  │     ├─ Log what WOULD be done
  │     ├─ Validate configuration
  │     └─ Skip actual execution
  │
  ├─→ [12] Report summary
  │
END
```

## 🔐 Security Architecture

### Permission Levels

```
┌─────────────────────────────────────────┐
│  Administrator Required                 │
│  • Registry modifications               │
│  • Service management                   │
│  • System restore points                │
│  • AppX package removal                 │
└─────────────────────────────────────────┘
         │
         ▼
┌─────────────────────────────────────────┐
│  User Level                             │
│  • Read configuration                   │
│  • View logs                            │
│  • Dry run mode                         │
└─────────────────────────────────────────┘
```

### Safety Mechanisms

```
┌─────────────────────────────────────────┐
│  Before Execution                       │
│  ✓ Administrator check                  │
│  ✓ Configuration validation             │
│  ✓ Restore point creation               │
│  ✓ Registry backup                      │
└─────────────────────────────────────────┘
         │
         ▼
┌─────────────────────────────────────────┐
│  During Execution                       │
│  ✓ Try-catch error handling             │
│  ✓ Graceful failure                     │
│  ✓ Detailed logging                     │
│  ✓ Continue on non-critical errors      │
└─────────────────────────────────────────┘
         │
         ▼
┌─────────────────────────────────────────┐
│  After Execution                        │
│  ✓ Summary report                       │
│  ✓ Log file saved                       │
│  ✓ Restore point available              │
│  ✓ Registry backup available            │
└─────────────────────────────────────────┘
```

## 📊 Data Flow

### Configuration to Execution

```
config.yaml
    │
    ├─ software.packages[]
    │  └─→ Install-WingetPackages()
    │      └─→ winget install
    │
    ├─ registry_tweaks.tweaks[]
    │  └─→ Set-RegistryTweaks()
    │      └─→ Set-ItemProperty
    │
    ├─ services.services_to_disable[]
    │  └─→ Set-ServiceConfiguration()
    │      └─→ Set-Service
    │
    ├─ scheduled_tasks.tasks_to_disable[]
    │  └─→ Disable-ScheduledTasksList()
    │      └─→ Disable-ScheduledTask
    │
    ├─ win11debloat.options{}
    │  └─→ Invoke-Win11Debloat()
    │      └─→ Win11Debloat.ps1
    │
    └─ post_scripts.scripts[]
       └─→ Invoke-PostScripts()
           └─→ Invoke-Expression
```

### Logging Flow

```
Operation
    │
    ├─→ Write-Log()
    │   ├─→ Console Output (colored)
    │   └─→ File Output (timestamped)
    │
    └─→ Log File
        ├─ Timestamp
        ├─ Level (Info/Success/Warning/Error)
        └─ Message
```

## 🧩 Module Dependencies

```
Install-WindowsAutomation.ps1
    │
    ├─ PowerShell 5.1+
    │  ├─ Core cmdlets
    │  ├─ Registry provider
    │  └─ Service management
    │
    ├─ powershell-yaml
    │  └─ YAML parsing
    │
    ├─ External Tools (Optional)
    │  ├─ Winget (Microsoft.DesktopAppInstaller)
    │  ├─ Win11Debloat (downloaded)
    │  └─ CTT WinUtil (downloaded)
    │
    └─ Windows APIs
       ├─ System Restore
       ├─ Registry
       ├─ Services
       └─ Scheduled Tasks
```

## 🎯 Extension Points

### Adding New Features

```
1. Configuration Schema
   └─ Add new section to config.yaml

2. Function Implementation
   └─ Create new function in main script

3. Integration
   └─ Call function from Start-WindowsAutomation

4. Documentation
   └─ Update README and examples
```

### Example: Adding Chocolatey Support

```
1. Config:
   software:
     install_method: "chocolatey"

2. Function:
   function Install-ChocolateyPackages { ... }

3. Integration:
   if ($config.software.install_method -eq "chocolatey") {
       Install-ChocolateyPackages
   }

4. Docs:
   Update README with Chocolatey instructions
```

## 📈 Performance Considerations

### Optimization Points

```
┌─────────────────────────────────────────┐
│  Fast Operations (<1 min)              │
│  • Configuration loading                │
│  • Registry modifications               │
│  • Service configuration                │
│  • Scheduled task management            │
└─────────────────────────────────────────┘

┌─────────────────────────────────────────┐
│  Medium Operations (1-5 min)            │
│  • Restore point creation               │
│  • Registry backup                      │
│  • Win11Debloat execution               │
└─────────────────────────────────────────┘

┌─────────────────────────────────────────┐
│  Slow Operations (5+ min)               │
│  • Software installation (varies)       │
│  • Large app removal                    │
│  • System updates                       │
└─────────────────────────────────────────┘
```

## 🔄 Error Handling Strategy

```
Operation Attempt
    │
    ├─→ Try
    │   └─→ Execute operation
    │       ├─ Success → Log success, continue
    │       └─ Failure → Throw exception
    │
    └─→ Catch
        ├─→ Log error with details
        ├─→ Continue with next operation (non-critical)
        └─→ Exit (critical errors only)
```

## 🎨 Design Patterns Used

1. **Configuration Pattern**
   - Declarative YAML configuration
   - Separation of config and logic

2. **Template Method Pattern**
   - Standard execution flow
   - Customizable steps

3. **Strategy Pattern**
   - Different installation methods (Winget/Chocolatey)
   - Pluggable components

4. **Facade Pattern**
   - Simple interface to complex operations
   - Hide implementation details

5. **Command Pattern**
   - Post-installation scripts
   - Encapsulated operations

## 📝 Summary

This architecture provides:

✅ **Modularity** - Easy to extend and modify
✅ **Safety** - Multiple protection layers
✅ **Flexibility** - Declarative configuration
✅ **Maintainability** - Clear separation of concerns
✅ **Reliability** - Comprehensive error handling
✅ **Transparency** - Detailed logging and reporting

The system is designed to be both powerful and safe, with clear extension points for future enhancements.

