# NinjaRMM Temperature Monitoring Extension

Cross-platform temperature monitoring solution for NinjaRMM that collects CPU and GPU temperatures from managed endpoints, writes data to custom fields, triggers tiered alerts, and executes automated remediation actions.

## Features

- **Multi-Platform Support**: Windows, macOS, and Linux
- **Comprehensive Monitoring**: CPU and GPU temperature collection
- **Tiered Alerting**: OK, WARNING, and CRITICAL thresholds
- **Automated Remediation**: Automatic process termination on critical temperatures
- **NinjaRMM Integration**: Direct write to custom fields via `ninjarmm-cli`
- **Safe Execution**: Process exclusion list protects system-critical processes
- **Scheduled Monitoring**: Designed to run every 15 minutes
- **Detailed Logging**: Local log files with automatic rotation

## Prerequisites

- **NinjaRMM Agent**: Installed and configured on all target systems
- **Custom Fields**: Created in NinjaRMM (see [Custom Fields Setup](docs/CUSTOM_FIELDS_SETUP.md))
- **Administrator/Root Access**: Scripts must run with elevated privileges
- **Platform-Specific Tools**:
  - **Windows**: PowerShell 5.1+ (LibreHardwareMonitor installed automatically)
  - **macOS**: powermetrics (built-in) or osx-cpu-temp (optional)
  - **Linux**: lm-sensors (installed automatically)

## Quick Start

### 1. Set Up Custom Fields

Follow the step-by-step instructions in [docs/CUSTOM_FIELDS_SETUP.md](docs/CUSTOM_FIELDS_SETUP.md) to create the required custom fields in your NinjaRMM instance.

### 2. Install Dependencies

Run the appropriate installation script for your platform:

**Windows (PowerShell as Administrator):**
```powershell
.\scripts\windows\Install-Dependencies.ps1
```

**macOS (as root):**
```bash
sudo ./scripts/macos/install_dependencies.sh
```

**Linux (as root):**
```bash
sudo ./scripts/linux/install_dependencies.sh
```

### 3. Test the Script

Run the temperature monitoring script manually to verify functionality:

**Windows:**
```powershell
.\scripts\windows\Get-Temperature.ps1 -Debug
```

**macOS:**
```bash
DEBUG=true sudo ./scripts/macos/get_temperature.sh
```

**Linux:**
```bash
DEBUG=true sudo ./scripts/linux/get_temperature.sh
```

### 4. Deploy to NinjaRMM

Follow the deployment instructions in [docs/DEPLOYMENT.md](docs/DEPLOYMENT.md) to configure NinjaRMM automation policies.

## Supported Platforms and OS Versions

### Windows
- Windows 10 (1809+)
- Windows 11
- Windows Server 2016+
- Windows Server 2019+
- Windows Server 2022+

**Requirements**: PowerShell 5.1 or PowerShell 7+

### macOS
- macOS 11 Big Sur and later
- macOS 12 Monterey
- macOS 13 Ventura
- macOS 14 Sonoma
- macOS 15 Sequoia

**Architectures**: Intel (x86_64) and Apple Silicon (arm64)

### Linux
- Ubuntu 20.04+, 22.04+, 24.04+
- Debian 10+, 11+, 12+
- RHEL/CentOS 7+, 8+, 9+
- Rocky Linux 8+, 9+
- AlmaLinux 8+, 9+
- Amazon Linux 2 and 2023
- Fedora 36+

## Temperature Thresholds (Defaults)

| Component | Warning | Critical |
|-----------|---------|----------|
| CPU       | 80°C    | 90°C     |
| GPU       | 85°C    | 95°C     |

**To customize thresholds**, edit the configuration variables at the top of each platform script. See [docs/THRESHOLDS.md](docs/THRESHOLDS.md) for detailed tuning guidance.

## Alert Levels and Actions

### OK (Exit Code: 0)
- Temperature below warning thresholds
- Data written to NinjaRMM custom fields
- No alert generated

### WARNING (Exit Code: 1)
- Temperature >= warning threshold but < critical threshold
- Alert detail logged
- Temperature history updated
- Script exits with non-zero code (triggers NinjaRMM condition alert)

### CRITICAL (Exit Code: 2)
- Temperature >= critical threshold
- Top 3 CPU processes logged
- **Automatic remediation**: Top CPU-consuming process terminated (excluding system-critical processes)
- Remediation action logged to custom field
- Script exits with non-zero code

### ERROR (Exit Code: 3)
- Unable to read temperature sensors
- Script execution error
- Error details logged

See [docs/REMEDIATION.md](docs/REMEDIATION.md) for complete details on remediation actions and process exclusion list.

## Security Considerations

- **Verified Dependencies**: LibreHardwareMonitor DLL should be hash-verified before use (placeholder included in installation script)
- **Path Hardcoding**: `ninjarmm-cli` path is hardcoded to prevent path injection
- **Process Protection**: System-critical processes protected by exclusion list
- **Log Permissions**: Log files are restricted to root/SYSTEM access (chmod 600)
- **No Secrets**: Scripts do not contain or log sensitive system information

## Debug Mode

Enable verbose output for troubleshooting:

**Windows:**
```powershell
.\scripts\windows\Get-Temperature.ps1 -Debug
```

**macOS/Linux:**
```bash
DEBUG=true sudo ./scripts/macos/get_temperature.sh
DEBUG=true sudo ./scripts/linux/get_temperature.sh
```

Debug mode logs:
- Sensor detection details
- Individual sensor readings
- Process enumeration details
- NinjaRMM field write operations

## Log Files

Platform-specific log file locations:

- **Windows**: `C:\ProgramData\NinjaRMM\TempMonitor\tempmonitor.log`
- **macOS**: `/var/log/ninjarmm_tempmonitor.log`
- **Linux**: `/var/log/ninjarmm_tempmonitor.log`

Logs automatically rotate when they exceed 1MB.

## Testing

Each platform includes a test script to validate core functionality:

**Windows (Pester required):**
```powershell
Invoke-Pester .\scripts\windows\Get-Temperature.Tests.ps1
```

**macOS:**
```bash
./scripts/macos/get_temperature_test.sh
```

**Linux:**
```bash
./scripts/linux/get_temperature_test.sh
```

## Documentation

- **[Custom Fields Setup](docs/CUSTOM_FIELDS_SETUP.md)**: Step-by-step field creation guide
- **[Threshold Configuration](docs/THRESHOLDS.md)**: How to tune temperature thresholds
- **[Remediation Guide](docs/REMEDIATION.md)**: Process termination logic and exclusions
- **[Deployment Guide](docs/DEPLOYMENT.md)**: NinjaRMM policy configuration

## Exit Code Reference

| Code | Status   | Description |
|------|----------|-------------|
| 0    | OK       | Temperature within normal range |
| 1    | WARNING  | Temperature threshold breached (warning level) |
| 2    | CRITICAL | Temperature threshold breached (critical level), remediation attempted |
| 3    | ERROR    | Script error or unable to read temperature |

Use these exit codes in NinjaRMM condition policies to trigger alerts and notifications.

## Contributing

Contributions are welcome! When submitting changes:

1. Follow the existing code style and standards
2. Test on all supported platforms
3. Update documentation as needed
4. Add/update tests for new functionality
5. Ensure security best practices are followed

## License

See [LICENSE](LICENSE) file for details.

## Support

For issues, questions, or feature requests, please refer to your NinjaRMM support channels or internal IT documentation.

## Project Structure

```
/
├── .github/
│   └── copilot-instructions.md    # GitHub Copilot instructions
├── scripts/
│   ├── windows/
│   │   ├── Get-Temperature.ps1
│   │   ├── Get-Temperature.Tests.ps1
│   │   └── Install-Dependencies.ps1
│   ├── macos/
│   │   ├── get_temperature.sh
│   │   ├── get_temperature_test.sh
│   │   └── install_dependencies.sh
│   └── linux/
│       ├── get_temperature.sh
│       ├── get_temperature_test.sh
│       └── install_dependencies.sh
├── docs/
│   ├── README.md
│   ├── CUSTOM_FIELDS_SETUP.md
│   ├── THRESHOLDS.md
│   ├── REMEDIATION.md
│   └── DEPLOYMENT.md
├── config/
│   └── thresholds.json
├── CHANGELOG.md
├── LICENSE
└── README.md
```

## Future Enhancements

Potential future features (not yet implemented):

- Trend analysis for detecting rapid temperature increases
- Per-device threshold overrides stored in NinjaRMM custom fields
- Email/webhook notifications in addition to NinjaRMM alerts
- Historical temperature graphing via dashboard widgets
- IPMI/BMC sensor support for server hardware
- Automatic ticketing integration for CRITICAL events

## Disabling Remediation

To disable automatic process termination while keeping alerting:

**Windows:**
```powershell
.\scripts\windows\Get-Temperature.ps1 -EnableRemediation $false
```

**macOS/Linux:**
```bash
ENABLE_REMEDIATION=false sudo ./scripts/macos/get_temperature.sh
ENABLE_REMEDIATION=false sudo ./scripts/linux/get_temperature.sh
```

---

**Version**: 1.0.0  
**Last Updated**: 2026-02-19
