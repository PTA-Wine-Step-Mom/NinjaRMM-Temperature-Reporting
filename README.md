# NinjaRMM Temperature Monitoring Extension

🌡️ **Cross-platform temperature monitoring for NinjaRMM with automated alerting and remediation**

[![Platform](https://img.shields.io/badge/platform-Windows%20%7C%20macOS%20%7C%20Linux-blue)]()
[![License](https://img.shields.io/badge/license-MIT-green)]()
[![Version](https://img.shields.io/badge/version-1.0.0-orange)]()

## Overview

This repository provides a comprehensive temperature monitoring solution for NinjaRMM that:

- ✅ **Monitors** CPU and GPU temperatures across Windows, macOS, and Linux
- ✅ **Alerts** on WARNING and CRITICAL thresholds via NinjaRMM conditions
- ✅ **Remediates** by automatically terminating high-CPU processes on critical overheating
- ✅ **Protects** system-critical processes via configurable exclusion lists
- ✅ **Logs** all actions with automatic log rotation
- ✅ **Integrates** seamlessly with NinjaRMM custom fields and dashboard

## Quick Start

### 1. Set Up Custom Fields
Follow [docs/CUSTOM_FIELDS_SETUP.md](docs/CUSTOM_FIELDS_SETUP.md) to create 7 required custom fields in NinjaRMM.

### 2. Install Dependencies
```bash
# Windows (PowerShell as Administrator)
.\scripts\windows\Install-Dependencies.ps1

# macOS (as root)
sudo ./scripts/macos/install_dependencies.sh

# Linux (as root)
sudo ./scripts/linux/install_dependencies.sh
```

### 3. Deploy to NinjaRMM
Follow [docs/DEPLOYMENT.md](docs/DEPLOYMENT.md) for complete deployment instructions.

## Features

### Temperature Monitoring
- **CPU**: Monitors all cores/packages, reports highest temperature
- **GPU**: NVIDIA, AMD, and integrated graphics support
- **Sensors**: LibreHardwareMonitor (Windows), powermetrics (macOS), lm-sensors (Linux)
- **Fallbacks**: WMI thermal zones (Windows), osx-cpu-temp (macOS), sysfs (Linux)

### Tiered Alerting
| Status | CPU Threshold | GPU Threshold | Action |
|--------|---------------|---------------|--------|
| **OK** | < 80°C | < 85°C | Monitor only |
| **WARNING** | ≥ 80°C | ≥ 85°C | Alert technicians |
| **CRITICAL** | ≥ 90°C | ≥ 95°C | Alert + kill top CPU process |
| **ERROR** | N/A | N/A | Sensor read failure |

### Automatic Remediation
On CRITICAL threshold breach:
1. Identifies top 3 CPU-consuming processes
2. Skips system-critical processes (systemd, kernel_task, svchost, etc.)
3. Terminates highest CPU consumer
4. Logs action to NinjaRMM custom field

**Safety:** Configurable process exclusion list protects essential services.

## Documentation

- 📘 [Project Overview & Quick Start](docs/README.md)
- ⚙️ [Custom Fields Setup Guide](docs/CUSTOM_FIELDS_SETUP.md)
- 🌡️ [Threshold Configuration](docs/THRESHOLDS.md)
- 🚨 [Remediation Behavior](docs/REMEDIATION.md)
- 🚀 [NinjaRMM Deployment](docs/DEPLOYMENT.md)
- 📝 [Changelog](CHANGELOG.md)

## Platform Support

### Windows
- Windows 10 (1809+), Windows 11
- Windows Server 2016/2019/2022
- PowerShell 5.1+ or PowerShell 7+

### macOS
- macOS 11 Big Sur and later
- Intel (x86_64) and Apple Silicon (arm64)

### Linux
- Ubuntu 20.04+, Debian 10+
- RHEL/CentOS/Rocky/Alma 7+, 8+, 9+
- Amazon Linux 2/2023, Fedora 36+

## Architecture

```
┌─────────────────────────────────────────────────────────┐
│                   NinjaRMM Platform                     │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐  │
│  │   Dashboard  │  │ Conditions   │  │   Policies   │  │
│  │   Widgets    │  │  & Alerts    │  │  (15 min)    │  │
│  └──────┬───────┘  └───────┬──────┘  └──────┬───────┘  │
└─────────┼──────────────────┼─────────────────┼─────────┘
          │                  │                 │
          │ Custom Fields    │ Exit Codes      │ Scripts
          │                  │                 │
┌─────────▼──────────────────▼─────────────────▼─────────┐
│              Temperature Monitoring Scripts             │
│  ┌──────────────────────────────────────────────────┐  │
│  │  Windows (PowerShell) | macOS (Bash) | Linux    │  │
│  │  • LibreHardwareMonitor | powermetrics | lm-sensors │
│  │  • WMI fallback        | osx-cpu-temp | sysfs    │  │
│  └──────────────────────────────────────────────────┘  │
└──────────────────────────┬──────────────────────────────┘
                           │
          ┌────────────────┼────────────────┐
          │                │                │
      ┌───▼───┐        ┌───▼───┐       ┌───▼───┐
      │  CPU  │        │  GPU  │       │ Logs  │
      │Sensors│        │Sensors│       │ Files │
      └───────┘        └───────┘       └───────┘
```

## Testing

Each platform includes comprehensive test suites:

```bash
# Windows (requires Pester)
Invoke-Pester .\scripts\windows\Get-Temperature.Tests.ps1

# macOS
./scripts/macos/get_temperature_test.sh

# Linux
./scripts/linux/get_temperature_test.sh
```

## Configuration

### Customize Thresholds

Edit the configuration section at the top of each platform script:

```powershell
# Windows (PowerShell)
$CPU_WARNING_THRESHOLD = 80
$CPU_CRITICAL_THRESHOLD = 90
$GPU_WARNING_THRESHOLD = 85
$GPU_CRITICAL_THRESHOLD = 95
```

```bash
# macOS / Linux (Bash)
CPU_WARNING_THRESHOLD=80
CPU_CRITICAL_THRESHOLD=90
GPU_WARNING_THRESHOLD=85
GPU_CRITICAL_THRESHOLD=95
```

See [docs/THRESHOLDS.md](docs/THRESHOLDS.md) for tuning guidelines.

### Disable Remediation

```bash
# Windows
.\Get-Temperature.ps1 -EnableRemediation $false

# macOS / Linux
ENABLE_REMEDIATION=false sudo ./get_temperature.sh
```

## Contributing

Contributions welcome! Please:
1. Follow existing code style and standards
2. Test on all supported platforms
3. Update documentation
4. Add/update tests for new functionality

## License

MIT License - see [LICENSE](LICENSE) file for details.

## Disclaimer

⚠️ This software automatically terminates processes on critical temperature events. While safeguards are in place, use at your own risk. Test thoroughly in non-production environments before deployment.

This project is not affiliated with, endorsed by, or sponsored by NinjaRMM, LLC.

## Support

- 📚 **Documentation**: See [docs/](docs/) directory
- 🐛 **Issues**: Use GitHub Issues for bug reports
- 💡 **Feature Requests**: Submit via GitHub Issues
- 🤝 **Community**: Share your configurations and experiences

---

**Version**: 1.0.0 | **Last Updated**: 2026-02-19
