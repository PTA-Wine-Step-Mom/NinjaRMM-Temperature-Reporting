# Temperature Threshold Configuration Guide

This guide explains how temperature thresholds work, how to tune them for your environment, and best practices for threshold configuration.

## Default Thresholds

The following default thresholds are configured in all platform scripts:

| Component | Warning Threshold | Critical Threshold |
|-----------|-------------------|-------------------|
| **CPU**   | 80°C             | 90°C              |
| **GPU**   | 85°C             | 95°C              |

These defaults are based on typical safe operating temperatures for modern processors and GPUs.

## Understanding Temperature Ranges

### Normal Operating Temperatures

**Desktop CPUs:**
- Idle: 30-45°C
- Light Load: 45-65°C
- Heavy Load: 65-80°C
- Maximum Safe: 80-90°C

**Server CPUs:**
- Idle: 35-50°C
- Light Load: 50-70°C
- Heavy Load: 70-85°C
- Maximum Safe: 85-95°C

**GPUs:**
- Idle: 30-50°C
- Light Load: 50-70°C
- Heavy Load: 70-85°C
- Maximum Safe: 85-95°C

**Laptop CPUs/GPUs:**
- May run 5-10°C warmer than desktops due to compact design
- Modern laptops use thermal throttling to manage heat
- Consider raising thresholds by 5-10°C for laptops

## Customizing Thresholds

### Windows (PowerShell)

Edit `scripts/windows/Get-Temperature.ps1` and modify the configuration section at the top:

```powershell
# =============================================================================
# CONFIGURATION - Adjust thresholds here
# =============================================================================

$CPU_WARNING_THRESHOLD = 80    # Change this value
$CPU_CRITICAL_THRESHOLD = 90   # Change this value
$GPU_WARNING_THRESHOLD = 85    # Change this value
$GPU_CRITICAL_THRESHOLD = 95   # Change this value
```

### macOS (Bash)

Edit `scripts/macos/get_temperature.sh` and modify the configuration section at the top:

```bash
# =============================================================================
# CONFIGURATION - Adjust thresholds here
# =============================================================================

CPU_WARNING_THRESHOLD=80    # Change this value
CPU_CRITICAL_THRESHOLD=90   # Change this value
GPU_WARNING_THRESHOLD=85    # Change this value
GPU_CRITICAL_THRESHOLD=95   # Change this value
```

### Linux (Bash)

Edit `scripts/linux/get_temperature.sh` and modify the configuration section at the top:

```bash
# =============================================================================
# CONFIGURATION - Adjust thresholds here
# =============================================================================

CPU_WARNING_THRESHOLD=80    # Change this value
CPU_CRITICAL_THRESHOLD=90   # Change this value
GPU_WARNING_THRESHOLD=85    # Change this value
GPU_CRITICAL_THRESHOLD=95   # Change this value
```

## Threshold Tuning Guidelines

### 1. Conservative Approach (Recommended for Production)

**Use Case**: Mission-critical systems, servers, workstations with important workloads

**Recommended Values:**
```
CPU_WARNING_THRESHOLD = 75°C
CPU_CRITICAL_THRESHOLD = 85°C
GPU_WARNING_THRESHOLD = 80°C
GPU_CRITICAL_THRESHOLD = 90°C
```

**Benefits:**
- Earlier warning of potential issues
- More time to investigate before critical state
- Reduces risk of thermal-related hardware damage
- Allows for proactive intervention

### 2. Balanced Approach (Default)

**Use Case**: General office workstations, mixed environments

**Recommended Values:**
```
CPU_WARNING_THRESHOLD = 80°C
CPU_CRITICAL_THRESHOLD = 90°C
GPU_WARNING_THRESHOLD = 85°C
GPU_CRITICAL_THRESHOLD = 95°C
```

**Benefits:**
- Good balance between alerting and false positives
- Appropriate for most hardware
- Follows manufacturer recommendations

### 3. Aggressive Approach

**Use Case**: High-performance workstations, gaming systems, systems with excellent cooling

**Recommended Values:**
```
CPU_WARNING_THRESHOLD = 85°C
CPU_CRITICAL_THRESHOLD = 95°C
GPU_WARNING_THRESHOLD = 90°C
GPU_CRITICAL_THRESHOLD = 100°C
```

**Benefits:**
- Reduces alert frequency for systems that regularly run hot
- Appropriate for enthusiast-grade hardware designed for high temperatures
- Useful in environments where brief temperature spikes are expected

**Warning**: Only use aggressive thresholds if you're confident in your cooling infrastructure and have verified manufacturer specifications support these temperatures.

### 4. Laptop-Specific Tuning

**Use Case**: Laptop deployments

**Recommended Values:**
```
CPU_WARNING_THRESHOLD = 85°C
CPU_CRITICAL_THRESHOLD = 95°C
GPU_WARNING_THRESHOLD = 90°C
GPU_CRITICAL_THRESHOLD = 100°C
```

**Rationale:**
- Laptops naturally run warmer due to compact design
- Modern laptops use thermal throttling to protect hardware
- Lower thresholds may cause excessive false positives

## Device-Specific Threshold Overrides

### Option 1: NinjaRMM Script Variables (Recommended)

Create different script versions in NinjaRMM with different threshold values passed as parameters:

1. Create script: "Temperature Monitor - Conservative"
2. Create script: "Temperature Monitor - Standard"
3. Create script: "Temperature Monitor - Aggressive"
4. Assign appropriate script to device groups via policies

**Future Enhancement**: Support for per-device threshold overrides stored as additional NinjaRMM custom fields.

### Option 2: Organizational Device Groups

Create separate device groups in NinjaRMM:
- Servers (Conservative thresholds)
- Workstations (Standard thresholds)
- Laptops (Aggressive thresholds)
- Gaming/CAD Workstations (Aggressive thresholds)

Deploy appropriate script version to each group.

## Monitoring and Adjustment

### Step 1: Establish Baseline

After initial deployment:

1. Run scripts for 1-2 weeks with default thresholds
2. Monitor alert frequency in NinjaRMM
3. Review `cpuTemperatureHistory` field across devices
4. Identify patterns:
   - Devices that frequently hit WARNING but never CRITICAL
   - Devices that never come close to thresholds
   - Devices with erratic temperature readings

### Step 2: Analyze Data

Look for:
- **Consistently high temperatures**: May indicate cooling issues (clean fans, improve airflow)
- **Frequent WARNING alerts with no issues**: Consider raising WARNING threshold
- **Temperature spikes during specific hours**: May be normal during heavy processing tasks

### Step 3: Adjust Thresholds

Based on your analysis:
- Increase thresholds if getting too many false positives
- Decrease thresholds if you want earlier warnings
- Document your threshold rationale for future reference

### Step 4: Re-evaluate Regularly

- Review threshold effectiveness quarterly
- Adjust for seasonal temperature changes (summer vs. winter)
- Update after hardware upgrades or infrastructure changes

## Seasonal Considerations

### Summer Cooling Adjustments

During hot months, ambient temperature rises can affect system cooling:

**Option 1**: Lower thresholds by 5°C to account for reduced cooling efficiency
```
CPU_WARNING_THRESHOLD = 75°C  (instead of 80°C)
CPU_CRITICAL_THRESHOLD = 85°C  (instead of 90°C)
```

**Option 2**: Increase monitoring frequency (every 10 minutes instead of 15)

### Winter Considerations

In colder months, you may:
- Return to standard thresholds
- Focus on other environmental monitoring (humidity, condensation)

## Manufacturer Specifications

Always consult your hardware manufacturer's specifications:

### Common CPU Maximum Junction Temperatures (Tj Max)

- **Intel Core (12th-14th Gen)**: 100°C
- **Intel Xeon**: 95-100°C
- **AMD Ryzen (5000/7000 series)**: 95-100°C
- **AMD EPYC**: 95°C

### Common GPU Maximum Temperatures

- **NVIDIA RTX 30-series**: 93°C
- **NVIDIA RTX 40-series**: 90°C
- **AMD Radeon RX 6000-series**: 110°C
- **AMD Radeon RX 7000-series**: 110°C

**Rule of Thumb**: Set CRITICAL threshold 5-10°C below manufacturer maximum.

## Threshold Testing

Before deploying new thresholds to production:

1. **Test on a single device**:
   ```bash
   # Linux/macOS
   CPU_WARNING_THRESHOLD=70 DEBUG=true sudo ./get_temperature.sh
   
   # Windows
   .\Get-Temperature.ps1 -Debug
   ```

2. **Generate artificial load** (optional):
   - Use stress-testing tools (Prime95, AIDA64, stress-ng)
   - Observe threshold behavior under load
   - Verify remediation actions trigger appropriately

3. **Monitor for 24-48 hours** on test device

4. **Deploy gradually** to device groups

## Best Practices

**DO:**
- Document your threshold decisions and rationale
- Test threshold changes on non-critical systems first
- Monitor alert frequency after changes
- Review manufacturer specifications before adjusting
- Consider device type (server, workstation, laptop) when setting thresholds
- Set WARNING threshold 5-10°C below CRITICAL threshold

**DON'T:**
- Set thresholds above manufacturer maximum temperatures
- Make dramatic threshold changes without testing
- Ignore repeated WARNING alerts without investigation
- Disable monitoring because of high alert volume (adjust thresholds instead)
- Use the same thresholds for all device types

## Troubleshooting Threshold Issues

### Too Many WARNING Alerts

**Problem**: Constant WARNING alerts on specific devices

**Solutions:**
1. Check device cooling (dust, fan operation)
2. Review workload patterns (is this expected?)
3. If hardware and workload are normal, consider raising WARNING threshold by 5°C
4. Verify temperature readings are accurate (compare with BIOS/UEFI readings)

### No Alerts Despite High Temperatures

**Problem**: Users report hot devices but no alerts are triggered

**Solutions:**
1. Verify script is running (check `lastTemperatureCheck` field)
2. Lower thresholds if current values are too permissive
3. Check that NinjaRMM condition policies are configured correctly
4. Review log files for script execution errors

### Erratic Temperature Readings

**Problem**: Temperature jumps dramatically between readings

**Solutions:**
1. This may be normal for brief workload spikes
2. Check `cpuTemperatureHistory` to see patterns
3. Consider using average temperature instead of instantaneous (requires script modification)
4. Verify sensor hardware is functioning correctly

## Reference Configuration File

The repository includes `config/thresholds.json` as a reference:

```json
{
  "cpu": {
    "warning": 80,
    "critical": 90
  },
  "gpu": {
    "warning": 85,
    "critical": 95
  }
}
```

This file is for documentation purposes only. Thresholds must be set within each script file.

---

**Remember**: The goal is to catch temperature issues early while minimizing false positives. Finding the right balance for your environment may take some iteration.
