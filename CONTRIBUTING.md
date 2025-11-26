# Contributing to Windows Automation

Thank you for considering contributing to this project! This document provides guidelines and instructions for contributing.

## 🤝 How to Contribute

### Reporting Bugs

If you find a bug, please create an issue with:

1. **Clear title** describing the issue
2. **Steps to reproduce** the problem
3. **Expected behavior** vs actual behavior
4. **Your environment:**
   - Windows version
   - PowerShell version
   - Script version
5. **Log files** (remove sensitive information)
6. **Configuration** (sanitized)

### Suggesting Enhancements

Enhancement suggestions are welcome! Please include:

1. **Use case** - Why is this needed?
2. **Proposed solution** - How should it work?
3. **Alternatives considered** - What other approaches did you think about?
4. **Examples** - Show how it would be used

### Pull Requests

1. **Fork** the repository
2. **Create a branch** for your feature (`git checkout -b feature/amazing-feature`)
3. **Make your changes**
4. **Test thoroughly**
5. **Commit** with clear messages
6. **Push** to your fork
7. **Create a Pull Request**

## 📝 Development Guidelines

### Code Style

**PowerShell:**
- Use PascalCase for function names
- Use camelCase for variables
- Include comment-based help for functions
- Use proper error handling with try/catch
- Add logging for important operations

**YAML:**
- Use 2 spaces for indentation
- Use lowercase with underscores for keys
- Include comments for complex configurations
- Validate YAML syntax before committing

### Configuration Files

When adding new configuration options:

1. Add to `config.yaml` with sensible defaults
2. Document in README.md
3. Add example to relevant profile configs
4. Update QUICKSTART.md if user-facing

### Testing

Before submitting:

1. **Test in dry run mode:**
   ```powershell
   .\Install-WindowsAutomation.ps1 -DryRun
   ```

2. **Test with actual execution** (in a VM if possible)

3. **Test with different configurations:**
   - Minimal config
   - Full config
   - Edge cases

4. **Verify logging** works correctly

5. **Check error handling** with invalid inputs

### Documentation

Update documentation when:
- Adding new features
- Changing existing behavior
- Fixing bugs that affect usage
- Adding configuration options

Files to update:
- `README.md` - Main documentation
- `QUICKSTART.md` - If user-facing
- `TROUBLESHOOTING.md` - If fixing common issues
- `CHANGELOG.md` - Always update this
- Inline comments in code

## 🏗️ Project Structure

```
windoze-automation/
├── Install-WindowsAutomation.ps1  # Main script
├── bootstrap.ps1                   # Bootstrap installer
├── config.yaml                     # Default configuration
├── configs/                        # Configuration profiles
│   ├── gaming-pc.yaml
│   └── developer-setup.yaml
├── README.md                       # Main documentation
├── QUICKSTART.md                   # Quick start guide
├── TROUBLESHOOTING.md              # Troubleshooting guide
├── CHANGELOG.md                    # Version history
├── CONTRIBUTING.md                 # This file
└── LICENSE                         # MIT License
```

## 🎯 Areas for Contribution

### High Priority
- [ ] CTT WinUtil preset integration
- [ ] NVCleanstall automation
- [ ] Configuration validation
- [ ] More pre-built profiles
- [ ] Automated testing

### Medium Priority
- [ ] GUI configuration editor
- [ ] Rollback functionality
- [ ] Windows Update automation
- [ ] Chocolatey support
- [ ] Progress indicators

### Low Priority
- [ ] Email notifications
- [ ] Web-based config generator
- [ ] Remote configuration
- [ ] Multi-language support

## 🧪 Testing Checklist

- [ ] Script runs without errors
- [ ] Dry run mode works correctly
- [ ] Restore point is created
- [ ] Registry backup is created
- [ ] Logging works properly
- [ ] Error handling is graceful
- [ ] Configuration is validated
- [ ] Documentation is updated
- [ ] CHANGELOG is updated
- [ ] No sensitive data in commits

## 📋 Commit Message Guidelines

Use clear, descriptive commit messages:

**Format:**
```
<type>: <subject>

<body>

<footer>
```

**Types:**
- `feat:` New feature
- `fix:` Bug fix
- `docs:` Documentation changes
- `style:` Code style changes (formatting, etc.)
- `refactor:` Code refactoring
- `test:` Adding tests
- `chore:` Maintenance tasks

**Examples:**
```
feat: Add Chocolatey support for software installation

- Add chocolatey install method
- Update config.yaml with new option
- Add documentation for Chocolatey usage

Closes #123
```

```
fix: Restore point creation fails on some systems

- Add check for System Protection status
- Enable System Protection if disabled
- Add error handling for insufficient disk space

Fixes #456
```

## 🔒 Security Considerations

When contributing:

1. **Never commit sensitive data:**
   - API keys
   - Passwords
   - Personal information
   - System-specific paths

2. **Validate user input:**
   - Check file paths
   - Validate YAML syntax
   - Sanitize registry values

3. **Use safe defaults:**
   - Don't enable destructive operations by default
   - Require explicit confirmation for risky actions
   - Always create backups before modifications

4. **Document security implications:**
   - Warn about registry modifications
   - Explain service disabling consequences
   - Note when admin rights are required

## 🐛 Bug Fix Process

1. **Reproduce the bug** in your environment
2. **Identify the root cause**
3. **Write a fix** with proper error handling
4. **Test thoroughly** in multiple scenarios
5. **Update documentation** if needed
6. **Add to CHANGELOG.md**
7. **Submit PR** with clear description

## ✨ Feature Addition Process

1. **Discuss in an issue first** (for large features)
2. **Design the feature:**
   - Configuration schema
   - Function signatures
   - Error handling
3. **Implement incrementally**
4. **Add logging**
5. **Write documentation**
6. **Create examples**
7. **Test extensively**
8. **Update CHANGELOG.md**
9. **Submit PR**

## 📚 Resources

### PowerShell
- [PowerShell Documentation](https://docs.microsoft.com/en-us/powershell/)
- [PowerShell Best Practices](https://docs.microsoft.com/en-us/powershell/scripting/developer/cmdlet/cmdlet-development-guidelines)

### YAML
- [YAML Specification](https://yaml.org/spec/)
- [YAML Validator](https://www.yamllint.com/)

### Windows
- [Windows Registry Reference](https://docs.microsoft.com/en-us/windows/win32/sysinfo/registry)
- [Windows Services](https://docs.microsoft.com/en-us/windows/win32/services/services)

### Related Projects
- [CTT WinUtil](https://github.com/ChrisTitusTech/winutil)
- [Win11Debloat](https://github.com/Raphire/Win11Debloat)
- [Winget](https://github.com/microsoft/winget-cli)

## 💬 Communication

- **GitHub Issues:** Bug reports and feature requests
- **Pull Requests:** Code contributions
- **Discussions:** General questions and ideas

## 📄 License

By contributing, you agree that your contributions will be licensed under the MIT License.

## 🙏 Recognition

Contributors will be:
- Listed in the project README
- Mentioned in release notes
- Credited in relevant documentation

Thank you for contributing to Windows Automation! 🎉

