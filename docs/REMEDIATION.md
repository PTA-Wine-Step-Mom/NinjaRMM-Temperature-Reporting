# Temperature Remediation Guide

This guide explains what happens when temperature thresholds are breached, how the automatic remediation system works, and how to configure it for your environment.

## Overview

The temperature monitoring scripts implement a **tiered response system** based on temperature thresholds:

- **OK**: Temperature within safe range → No action
- **WARNING**: Temperature elevated → Alert only
- **CRITICAL**: Temperature dangerous → Alert + Automatic remediation

## Response Actions by Status Level

### OK Status (Exit Code: 0)

**Temperature Condition:**
- CPU temperature < WARNING threshold
- GPU temperature < WARNING threshold (or GPU not present)

**Actions Taken:**
1. Temperature values written to NinjaRMM custom fields
2. Status set to "OK"
3. Timestamp updated
4. Alert detail field updated with current readings
5. Temperature history updated

**NinjaRMM Behavior:**
- No alert generated
- Script exits with code 0
- Condition policies do not trigger

---

### WARNING Status (Exit Code: 1)

**Temperature Condition:**
- CPU temperature >= WARNING threshold BUT < CRITICAL threshold
- OR GPU temperature >= WARNING threshold BUT < CRITICAL threshold

**Actions Taken:**
1. Temperature values written to NinjaRMM custom fields
2. Status set to "WARNING"
3. Timestamp updated
4. Detailed alert message written to `temperatureAlertDetail` field:
   ```
   WARNING: CPU at 83°C (threshold: 80°C), GPU at 82°C (threshold: 85°C). 
   Timestamp: 2026-02-19T14:32:00
   ```
5. Temperature history updated (last 5 readings maintained)
6. Logged to local log file

**NinjaRMM Behavior:**
- Script exits with code 1
- Condition policy triggers (if configured to alert on non-zero exit code)
- Technician receives alert notification
- Device appears in filtered alert views

**No Remediation:** Process termination is NOT performed at WARNING level.

---

### CRITICAL Status (Exit Code: 2)

**Temperature Condition:**
- CPU temperature >= CRITICAL threshold
- OR GPU temperature >= CRITICAL threshold

**Actions Taken:**

#### Phase 1: Data Collection and Alerting

1. Temperature values written to NinjaRMM custom fields
2. Status set to "CRITICAL"
3. Timestamp updated
4. **Top 3 CPU-consuming processes identified** using platform-specific tools:
   - Windows: `Get-Process | Sort-Object CPU -Descending`
   - macOS: `ps -Arco pid,comm,%cpu | sort -rn -k3`
   - Linux: `ps aux --sort=-%cpu`

5. Detailed alert message written to `temperatureAlertDetail` field:
   ```
   CRITICAL: CPU at 92°C (threshold: 90°C), GPU at 88°C. Timestamp: 2026-02-19T14:32:00
   Top CPU processes: chrome (PID: 12345, CPU: 45.2%); firefox (PID: 67890, CPU: 23.8%); code (PID: 54321, CPU: 18.5%)
   ```

6. Temperature history updated
7. All actions logged to local log file

#### Phase 2: Automatic Remediation

**If remediation is enabled** (default: enabled):

8. Script identifies the **top CPU-consuming process**
9. Process is checked against the **exclusion list**
10. If process is excluded, script moves to the next process (up to top 3)
11. First non-excluded process is **terminated immediately** using:
   - Windows: `Stop-Process -Id <PID> -Force`
   - macOS/Linux: `kill -9 <PID>`
12. Remediation action written to `remediationActionTaken` field:
   ```
   Killed process: chrome (PID: 12345, CPU: 45.2%)
   ```

**If all top 3 processes are excluded:**
```
All top CPU processes are system-critical (excluded from termination)
```

**NinjaRMM Behavior:**
- Script exits with code 2
- Condition policy triggers alert
- Critical alert notification sent to technicians
- Remediation action visible in device custom fields

---

### ERROR Status (Exit Code: 3)

**Condition:**
- Unable to read CPU temperature from any sensor
- Script execution error
- Required dependency not found

**Actions Taken:**
1. Status set to "ERROR"
2. Error message written to `temperatureAlertDetail`
3. Detailed error logged to local log file
4. No temperature values updated (previous values retained)

**NinjaRMM Behavior:**
- Script exits with code 3
- Condition policy triggers error alert
- Technician intervention required

---

## Process Exclusion Lists

The remediation system **never terminates** processes that are critical to system stability or NinjaRMM agent operation.

### Windows Exclusion List

```
System
svchost
lsass
winlogon
csrss
smss
wininit
services
NinjaRMM
NinjaRMMMaintenance
```

**Rationale:**
- **System/svchost/lsass/csrss**: Core Windows system processes
- **winlogon/smss/wininit**: Session management and initialization
- **services**: Windows Service Control Manager
- **NinjaRMM/NinjaRMMMaintenance**: RMM agent processes (killing these would disconnect monitoring)

### macOS Exclusion List

```
kernel_task
launchd
loginwindow
WindowServer
ninjarmm
osquery
```

**Rationale:**
- **kernel_task**: macOS kernel thread (not an actual process)
- **launchd**: macOS init system (PID 1)
- **loginwindow**: User session manager
- **WindowServer**: macOS display server
- **ninjarmm**: NinjaRMM agent
- **osquery**: Often used for security monitoring

### Linux Exclusion List

```
systemd
init
kthreadd
kworker
ksoftirqd
ninjarmm
sshd
cron
```

**Rationale:**
- **systemd/init**: System initialization (PID 1)
- **kthreadd/kworker/ksoftirqd**: Kernel threads
- **ninjarmm**: NinjaRMM agent
- **sshd**: Remote access (killing could lock out admins)
- **cron**: System task scheduler

---

## Customizing the Exclusion List

### Adding Processes to Exclusion List

**Use Cases:**
- Protect business-critical applications
- Prevent termination of database servers
- Exclude monitoring/security tools
- Protect custom applications

#### Windows

Edit `scripts/windows/Get-Temperature.ps1`:

```powershell
$EXCLUDED_PROCESSES = @(
    'System', 'svchost', 'lsass', 'winlogon', 'csrss', 'smss',
    'wininit', 'services', 'NinjaRMM', 'NinjaRMMMaintenance',
    # Add your custom exclusions below:
    'sqlservr',          # SQL Server
    'mysqld',            # MySQL
    'postgres',          # PostgreSQL
    'mongod',            # MongoDB
    'java',              # Java applications (be specific if possible)
    'YourBusinessApp'    # Your custom application
)
```

#### macOS

Edit `scripts/macos/get_temperature.sh`:

```bash
EXCLUDED_PROCESSES="kernel_task|launchd|loginwindow|WindowServer|ninjarmm|osquery|mysqld|postgres|YourApp"
```

#### Linux

Edit `scripts/linux/get_temperature.sh`:

```bash
EXCLUDED_PROCESSES="systemd|init|kthreadd|kworker|ksoftirqd|ninjarmm|sshd|cron|mysqld|postgres|httpd|nginx|YourDaemon"
```

### Exclusion List Matching

- **Case-insensitive**: Process names are matched without regard to case
- **Pattern matching**: 
  - Windows: Uses `-like` operator (supports wildcards)
  - macOS/Linux: Uses regex patterns with `grep -iE`

**Examples:**
- `sshd` matches `sshd`, `SSHD`, `Sshd`
- `kworker` matches `kworker/0:1`, `kworker/1:0`, etc. (Linux)

---

## Disabling Automatic Remediation

### Disable for Single Execution

**Windows:**
```powershell
.\Get-Temperature.ps1 -EnableRemediation $false
```

**macOS:**
```bash
ENABLE_REMEDIATION=false sudo ./get_temperature.sh
```

**Linux:**
```bash
ENABLE_REMEDIATION=false sudo ./get_temperature.sh
```

### Disable Permanently in NinjaRMM Policy

#### Option 1: Script Parameters (Recommended)

1. Edit your NinjaRMM script configuration
2. Add parameter for Windows: `-EnableRemediation $false`
3. Add environment variable for macOS/Linux: `ENABLE_REMEDIATION=false`

#### Option 2: Edit Script File

Change the default value in each script:

**Windows** (`Get-Temperature.ps1`):
```powershell
[Parameter(Mandatory=$false)]
[bool]$EnableRemediation = $false  # Changed from $true
```

**macOS/Linux** (`.sh` files):
```bash
ENABLE_REMEDIATION="${ENABLE_REMEDIATION:-false}"  # Changed from true
```

**Note**: Disabling remediation means you'll still get CRITICAL alerts, but no processes will be automatically terminated. Technicians must respond manually.

---

## Remediation Behavior Analysis

### What Gets Killed?

The script targets the **top CPU-consuming process** that is:
1. Currently running
2. Consuming significant CPU resources
3. NOT on the exclusion list

**Common processes that may be terminated:**
- Web browsers (Chrome, Firefox, Edge) with many tabs
- Video encoding/rendering applications
- Compilers during large builds
- Data processing scripts
- Cryptocurrency miners (legitimate or malicious)
- Runaway background services
- Memory leaks causing CPU thrashing

### Why Kill Only One Process?

**Design Rationale:**
- **Minimally invasive**: Kills only what's necessary to reduce thermal load
- **Reduces risk**: Avoids cascading failures from killing multiple processes
- **Allows recovery**: System can stabilize after single process termination
- **Prevents over-correction**: Killing multiple processes may cause more problems

If one termination doesn't resolve the issue, the script will:
1. Run again in 15 minutes (per schedule)
2. Re-evaluate temperatures
3. Terminate another process if still CRITICAL

### Force Kill Behavior

The scripts use **force termination**:
- Windows: `Stop-Process -Force`
- macOS/Linux: `kill -9` (SIGKILL)

**Implications:**
- Process is terminated immediately without cleanup
- No graceful shutdown sequence
- Unsaved data may be lost
- File locks released immediately

**Justification:** At CRITICAL temperatures, hardware protection takes priority over data preservation.

---

## Monitoring Remediation Actions

### View Remediation History

Check the `remediationActionTaken` custom field on devices to see:
- Which processes have been terminated
- When remediation occurred
- Frequency of remediation events

### Log File Analysis

Review local log files for detailed information:

**Windows:**
```
C:\ProgramData\NinjaRMM\TempMonitor\tempmonitor.log
```

**macOS/Linux:**
```
/var/log/ninjarmm_tempmonitor.log
```

Search for remediation events:
```bash
# Linux/macOS
grep "Terminating process" /var/log/ninjarmm_tempmonitor.log

# Windows PowerShell
Select-String -Path "C:\ProgramData\NinjaRMM\TempMonitor\tempmonitor.log" -Pattern "Terminating process"
```

### Create Remediation Alert Report

Use NinjaRMM reporting to:
1. Filter devices where `remediationActionTaken` is not empty
2. Group by process name to identify patterns
3. Schedule regular reports to review remediation frequency

---

## Best Practices

**DO:**
- Review remediation actions weekly to identify problem applications
- Add mission-critical applications to the exclusion list
- Investigate why processes are consuming excessive CPU
- Address root causes (malware, bugs, misconfigurations) rather than relying on remediation
- Test remediation behavior in a lab environment before deployment
- Document any changes to the exclusion list

**DON'T:**
- Disable remediation without understanding the risks
- Remove system processes from the exclusion list
- Ignore frequent remediation events (they indicate a problem)
- Add all processes to the exclusion list (defeats the purpose)
- Rely on remediation as a substitute for proper system maintenance

---

## Troubleshooting

### Remediation Not Occurring

**Problem**: CRITICAL status reached but no process terminated

**Possible Causes:**
1. Remediation disabled (`ENABLE_REMEDIATION=false`)
2. All top processes are on exclusion list
3. Permission issues (script not running as root/SYSTEM)
4. Process already terminated before script could act

**Solution:**
- Check `remediationActionTaken` field for details
- Review log files
- Verify script runs with elevated privileges

### Wrong Process Terminated

**Problem**: Important process was killed unexpectedly

**Solution:**
1. Add process to exclusion list immediately
2. Investigate why that process was consuming high CPU
3. If legitimate high CPU usage, consider:
   - Raising CRITICAL threshold
   - Disabling remediation for that device group
   - Scheduling intensive tasks during off-hours

### Repeated Remediation on Same Device

**Problem**: Same device requires remediation multiple times per day

**Root Causes:**
- Hardware cooling failure (dust, fan failure)
- Malware causing sustained high CPU usage
- Application bug causing CPU spike
- Undersized hardware for workload

**Solution:**
1. Investigate cooling hardware
2. Run malware scan
3. Review application logs
4. Consider hardware upgrade if undersized

---

## Security Considerations

### Malware Mitigation

Remediation can help contain malware that causes high CPU usage:
- Cryptocurrency miners
- Botnet activity
- Ransomware encryption processes

However, sophisticated malware may:
- Restart automatically after termination
- Run under protected system processes
- Use multiple low-CPU processes (evading top-3 detection)

**Recommendation**: Use remediation as a **temporary mitigation** while performing full security investigation and cleanup.

### Denial of Service Concerns

Killing processes could theoretically be abused, but risk is minimal:
- Scripts run as SYSTEM/root (already compromised if attacker has control)
- Only triggers on sustained high temperature (hard to artificially induce)
- Exclusion list protects critical processes
- Remediation events are logged and visible in NinjaRMM

---

**Remember**: Automatic remediation is a **last resort protection mechanism**. The goal is to prevent hardware damage, not to solve recurring problems. Always investigate and address root causes.
