# GitHub Copilot Instructions - NinjaRMM Temperature Monitoring

## Project Purpose

Cross-platform temperature monitoring extension for NinjaRMM that:
- Collects CPU/GPU temperatures on Windows, macOS, and Linux
- Writes data to NinjaRMM custom fields via `ninjarmm-cli`
- Triggers tiered alerts (OK, WARNING, CRITICAL)
- Executes automated remediation (process termination) on critical temperatures
- Runs safely every 15 minutes as NinjaRMM automation policy

## Key Design Principles

1. **Platform-Specific Implementation**: Separate scripts for Windows (PowerShell), macOS (Bash), Linux (Bash)
2. **Tiered Response**: OK → WARNING → CRITICAL with escalating actions
3. **Safety First**: Process exclusion lists protect system-critical processes
4. **Idempotent**: Safe to run repeatedly every 15 minutes
5. **Minimal Changes**: Make surgical, targeted edits only
6. **Security-Conscious**: Verify dependencies, hardcode paths, restrict log permissions

## Temperature Thresholds

Default values (configurable at top of each script):
```
CPU_WARNING_THRESHOLD  = 80°C
CPU_CRITICAL_THRESHOLD = 90°C
GPU_WARNING_THRESHOLD  = 85°C
GPU_CRITICAL_THRESHOLD = 95°C
```

## Platform-Specific Tools

### Windows (PowerShell)
- **Primary**: LibreHardwareMonitor (`LibreHardwareMonitorLib.dll` loaded via reflection)
- **Fallback**: WMI `MSAcpi_ThermalZoneTemperature` (convert: `($value / 10) - 273.15`)
- **Requirements**: PowerShell 5.1+, Administrator privileges
- **Path**: `C:\Program Files\NinjaRMM\ninjarmm-cli.exe`

### macOS (Bash)
- **Primary**: `sudo powermetrics --samplers smc -n 1 -i 1000` (parse "CPU die temperature")
- **Fallback**: `osx-cpu-temp` (if installed via Homebrew)
- **Requirements**: Bash, root privileges
- **Path**: `/opt/NinjaRMM/ninjarmm-cli`

### Linux (Bash)
- **Primary**: `sensors` command from lm-sensors (prefer `sensors -j` JSON output)
- **Fallback**: `/sys/class/thermal/thermal_zone*/temp` (millidegrees, divide by 1000)
- **GPU**: `nvidia-smi` (NVIDIA), `/sys/class/drm/card*/device/hwmon/hwmon*/temp1_input` (AMD)
- **Requirements**: Bash, root privileges
- **Path**: `/opt/NinjaRMM/ninjarmm-cli`

## NinjaRMM Custom Fields

All scripts write to these 7 fields (case-sensitive names):
1. `cpuTemperatureCelsius` (Decimal)
2. `gpuTemperatureCelsius` (Decimal)
3. `temperatureStatus` (Text: OK, WARNING, CRITICAL, ERROR)
4. `lastTemperatureCheck` (Date/Time: ISO 8601)
5. `temperatureAlertDetail` (Text: human-readable summary)
6. `cpuTemperatureHistory` (Text: last 5 readings, comma-separated)
7. `remediationActionTaken` (Text: process termination details)

## Exit Codes

- `0`: OK (temperature within safe range)
- `1`: WARNING (threshold breached, alert only)
- `2`: CRITICAL (threshold breached, remediation attempted)
- `3`: ERROR (unable to read temperature or script failure)

## Remediation Logic

On CRITICAL status:
1. Get top 3 CPU-consuming processes
2. Check against exclusion list
3. Kill first non-excluded process
4. Log action to `remediationActionTaken` field

### Process Exclusion Lists

**Windows**: `System, svchost, lsass, winlogon, csrss, smss, wininit, services, NinjaRMM, NinjaRMMMaintenance`

**macOS**: `kernel_task, launchd, loginwindow, WindowServer, ninjarmm, osquery`

**Linux**: `systemd, init, kthreadd, kworker, ksoftirqd, ninjarmm, sshd, cron`

## Script Standards

### PowerShell
```powershell
#Requires -Version 5.1
[CmdletBinding()]
param(...)
$ErrorActionPreference = 'Stop'

# Header comment block with script metadata
# Configuration section with threshold variables
# Functions with comment blocks
# Main execution with try/catch/finally
```

### Bash
```bash
#!/usr/bin/env bash
set -euo pipefail

# Header comment block with script metadata
# Configuration section with threshold variables
# Functions for logical blocks
# Main execution at bottom
```

## Coding Guidelines

### All Platforms
- **Timestamps**: ISO 8601 format (`YYYY-MM-DDTHH:MM:SS`)
- **Logging**: Write to local file with rotation at 1MB
- **Error Handling**: Catch all errors, log, exit with appropriate code
- **Validation**: Check for required tools/files before use
- **Verbosity**: Support DEBUG mode for troubleshooting
- **Comments**: Document sensor APIs, expected output formats

### Windows Specific
- Use `[CmdletBinding()]` and proper parameters
- Use `Write-Log` for logging, not `Write-Host`
- Load LibreHardwareMonitor with `[System.Reflection.Assembly]::LoadFile()`
- Check for Administrator privileges
- Use `try/catch/finally` for all external calls

### Bash Specific
- Quote all variables: `"$variable"`
- Use functions for all logic blocks
- Check for root: `[[ "$EUID" -ne 0 ]]`
- Use `command -v` to check for binaries
- Prefix log messages: `[timestamp] [LEVEL] message`

## Testing

Each platform has test scripts:
- **Windows**: `Get-Temperature.Tests.ps1` (Pester framework)
- **macOS**: `get_temperature_test.sh` (bash test framework)
- **Linux**: `get_temperature_test.sh` (bash test framework)

Test coverage includes:
- Threshold logic
- Process exclusion list
- Exit codes
- Temperature history
- Unit conversions
- Sensor parsing

## File Locations

### Scripts
- `scripts/windows/Get-Temperature.ps1` - Main Windows script
- `scripts/windows/Install-Dependencies.ps1` - Dependency installer
- `scripts/windows/Get-Temperature.Tests.ps1` - Pester tests
- `scripts/macos/get_temperature.sh` - Main macOS script
- `scripts/macos/install_dependencies.sh` - Dependency installer
- `scripts/macos/get_temperature_test.sh` - Tests
- `scripts/linux/get_temperature.sh` - Main Linux script
- `scripts/linux/install_dependencies.sh` - Dependency installer
- `scripts/linux/get_temperature_test.sh` - Tests

### Documentation
- `docs/README.md` - Project overview and quick start
- `docs/CUSTOM_FIELDS_SETUP.md` - Field creation guide
- `docs/THRESHOLDS.md` - Threshold tuning guide
- `docs/REMEDIATION.md` - Remediation behavior documentation
- `docs/DEPLOYMENT.md` - NinjaRMM policy setup

### Configuration
- `config/thresholds.json` - Reference threshold configuration

### Logs
- Windows: `C:\ProgramData\NinjaRMM\TempMonitor\tempmonitor.log`
- macOS: `/var/log/ninjarmm_tempmonitor.log`
- Linux: `/var/log/ninjarmm_tempmonitor.log`

## When Making Changes

1. **Check platform first**: Don't mix PowerShell and Bash syntax
2. **Include header block**: Every new script needs full metadata header
3. **Define thresholds as constants**: Never inline magic numbers
4. **Add error handling**: Wrap external calls in try/catch or conditionals
5. **Write tests**: Add test cases for new functionality
6. **Update docs**: Keep documentation synchronized with code
7. **Prefer readability**: Code will be maintained by IT admins, not developers
8. **Document sensor APIs**: Explain command output formats
9. **Never hardcode secrets**: Use environment variables or script parameters
10. **Validate tool existence**: Check for binaries before calling them

## Security Requirements

- **Hash Verification**: Verify LibreHardwareMonitor DLL before loading
- **Path Hardcoding**: Use hardcoded paths for `ninjarmm-cli` (prevent injection)
- **Process Protection**: Never kill system-critical processes
- **Log Permissions**: Restrict log files to root/SYSTEM only (chmod 600)
- **No Sensitive Data**: Don't log credentials or sensitive system info

## Common Tasks

### To Adjust Thresholds
Edit configuration section at top of respective script file.

### To Disable Remediation
- Windows: Add parameter `-EnableRemediation $false`
- macOS/Linux: Set environment variable `ENABLE_REMEDIATION=false`

### To Add Process to Exclusion List
Edit the exclusion list variable in respective script file.

### To Enable Debug Mode
- Windows: Add parameter `-Debug`
- macOS/Linux: Set environment variable `DEBUG=true`

## Future Enhancements (Do Not Implement Yet)

- Trend analysis for rapid temperature increases
- Per-device threshold overrides from custom fields
- Email/webhook notifications
- Historical temperature graphing
- IPMI/BMC sensor support
- Automatic ticketing integration

---

**Remember**: Make minimal, surgical changes. Test thoroughly. Document everything. Safety and reliability over features.
