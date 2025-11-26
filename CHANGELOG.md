# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] - 2025-11-26

### Added
- Initial release of Windows Post-Installation Automation
- Declarative YAML-based configuration system
- Automatic system restore point creation
- Registry backup functionality
- Software installation via Winget
- Win11Debloat integration for bloatware removal
- CTT WinUtil integration (manual execution)
- Custom registry tweaks system
- Service configuration and disabling
- Scheduled task management
- Comprehensive logging system
- Dry run mode for previewing changes
- Bootstrap script for fresh installations
- Pre-configured profiles:
  - Gaming PC configuration
  - Developer setup configuration
- Detailed documentation:
  - README.md with full feature list
  - QUICKSTART.md for fast setup
  - TROUBLESHOOTING.md for common issues
- Safety features:
  - Restore point creation before changes
  - Registry backup before modifications
  - Error handling and graceful failures
  - Detailed operation logging

### Features
- ✅ Automated software installation (Winget)
- ✅ System debloating and optimization
- ✅ Privacy tweaks and telemetry disabling
- ✅ Registry modifications
- ✅ Service management
- ✅ Scheduled task configuration
- ✅ Post-installation script execution
- ✅ Multiple configuration profiles
- ✅ Dry run mode
- ✅ Comprehensive error handling

### Documentation
- Complete README with usage instructions
- Quick start guide for new users
- Troubleshooting guide for common issues
- Example configurations for different use cases
- Inline code documentation

### Known Limitations
- CTT WinUtil is GUI-based and requires manual execution
- NVCleanstall requires manual setup and configuration
- Some Windows Store apps may require additional steps to remove
- Certain system services may require SYSTEM privileges to disable

## [Unreleased]

### Planned Features
- Full CTT WinUtil preset integration
- NVCleanstall command-line automation
- GUI configuration editor
- Additional pre-built configuration profiles
- Rollback functionality
- Remote configuration management
- Windows Update automation
- Chocolatey support as alternative to Winget
- Configuration validation tool
- Web-based configuration generator

### Planned Improvements
- Enhanced error recovery
- More granular logging levels
- Progress indicators
- Email notifications on completion
- Configuration migration tools
- Automated testing suite

---

## Version History

### Version 1.0.0 (2025-11-26)
- Initial public release
- Core automation features
- Safety mechanisms
- Documentation suite

---

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for information on how to contribute to this project.

## Support

For issues, questions, or contributions, please visit:
- GitHub Issues: [Report a bug or request a feature]
- Documentation: See README.md and TROUBLESHOOTING.md

