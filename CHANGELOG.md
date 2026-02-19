# Changelog

All notable changes to the NinjaRMM Temperature Monitoring Extension will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] - 2026-02-19

### Added

#### Core Features
- Cross-platform temperature monitoring for Windows, macOS, and Linux
- Tiered alerting system (OK, WARNING, CRITICAL, ERROR)
- Automatic remediation with process termination on CRITICAL events
- Process exclusion lists to protect system-critical processes
- Temperature history tracking (last 5 readings)
- ISO 8601 timestamp logging
- Configurable temperature thresholds

#### Windows Implementation
- PowerShell 5.1+ compatible temperature monitoring script
- LibreHardwareMonitor integration for hardware sensor access
- WMI fallback for thermal zone temperature reading
- Pester unit test suite
- Automatic dependency installation script
- Administrator privilege validation

#### macOS Implementation
- Bash-based temperature monitoring using powermetrics (primary)
- osx-cpu-temp fallback support
- Apple Silicon (arm64) and Intel (x86_64) compatibility
- Architecture detection and logging
- Shell script test suite
- Homebrew-based dependency installation

#### Linux Implementation
- Bash-based temperature monitoring using lm-sensors (primary)
- Thermal zone fallback (`/sys/class/thermal`)
- NVIDIA GPU temperature support via nvidia-smi
- AMD GPU temperature support via sysfs
- Multi-distro support (Ubuntu, Debian, RHEL, CentOS, Fedora, Amazon Linux)
- Shell script test suite
- Auto-detected package manager support (apt, yum, dnf)

#### NinjaRMM Integration
- 7 custom fields for comprehensive data tracking:
  - `cpuTemperatureCelsius`: CPU temperature value
  - `gpuTemperatureCelsius`: GPU temperature value
  - `temperatureStatus`: Current alert status
  - `lastTemperatureCheck`: Timestamp of last check
  - `temperatureAlertDetail`: Human-readable alert description
  - `cpuTemperatureHistory`: Last 5 temperature readings
  - `remediationActionTaken`: Remediation action log
- Direct integration with `ninjarmm-cli` tool
- Exit codes aligned with condition-based alerting (0=OK, 1=WARNING, 2=CRITICAL, 3=ERROR)

#### Logging and Monitoring
- Local log files with automatic rotation (1MB threshold)
- Structured logging with timestamps and severity levels
- Debug mode for verbose sensor output
- Per-platform log file locations

#### Documentation
- Comprehensive README with quick start guide
- Step-by-step custom fields setup guide
- Threshold tuning and configuration guide
- Remediation behavior and exclusion list documentation
- Complete NinjaRMM deployment guide with policy setup
- Security considerations and best practices

#### Configuration
- JSON reference configuration file for thresholds
- In-script configurable thresholds
- Optional remediation enable/disable flag
- Extensible process exclusion lists

#### Testing
- Windows: Pester test suite with 30+ test cases
- macOS: Bash test suite with comprehensive coverage
- Linux: Bash test suite with comprehensive coverage
- Test coverage for:
  - Threshold logic validation
  - Process exclusion list behavior
  - Exit code verification
  - Temperature history management
  - Sensor data parsing
  - Unit conversion accuracy

### Security
- SHA256 hash verification for LibreHardwareMonitor DLL (placeholder)
- Hardcoded `ninjarmm-cli` paths to prevent path injection
- System-critical process protection via exclusion lists
- Log file permission restrictions (chmod 600 on Unix)
- No secrets or credentials stored in scripts
- Elevated privilege validation before execution

### Technical Details
- PowerShell: ErrorActionPreference set to Stop for proper error handling
- Bash: Strict mode enabled (`set -euo pipefail`)
- All shell scripts made executable
- Proper try/catch/finally blocks for error handling
- Graceful degradation when sensors unavailable
- Idempotent script design for safe repeated execution

### Development Tools
- GitHub Copilot instructions for AI-assisted development
- Comprehensive inline documentation
- Standardized header comment blocks on all scripts
- Function-level documentation with parameter descriptions

## [Unreleased]

### Planned Features (Future Enhancements)
- Trend analysis for detecting rapid temperature increases
- Per-device threshold overrides stored as NinjaRMM custom fields
- Email/webhook notification integration
- Historical temperature graphing via dashboard widgets
- IPMI/BMC sensor support for server hardware
- Automatic ticket creation integration
- Multi-language support for alert messages
- Mobile app notifications
- Temperature anomaly detection using machine learning
- Integration with environmental monitoring systems

---

## Version History

### Version Numbering Scheme

- **MAJOR.MINOR.PATCH** (e.g., 1.0.0)
  - **MAJOR**: Incompatible API changes, major feature overhauls
  - **MINOR**: New functionality in a backwards-compatible manner
  - **PATCH**: Backwards-compatible bug fixes

### Release Notes Format

Each release includes:
- **Added**: New features
- **Changed**: Changes to existing functionality
- **Deprecated**: Soon-to-be removed features
- **Removed**: Removed features
- **Fixed**: Bug fixes
- **Security**: Security vulnerability fixes

---

## Contributing

When contributing changes:
1. Update this CHANGELOG.md file
2. Follow the [Keep a Changelog](https://keepachangelog.com/) format
3. Add entries under the [Unreleased] section
4. Maintainers will move entries to versioned sections upon release

---

## Links

- [Repository](https://github.com/PTA-Wine-Step-Mom/NinjaRMM-Temperature-Reporting)
- [Documentation](docs/README.md)
- [Issue Tracker](https://github.com/PTA-Wine-Step-Mom/NinjaRMM-Temperature-Reporting/issues)
