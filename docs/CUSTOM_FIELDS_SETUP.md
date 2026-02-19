# NinjaRMM Custom Fields Setup Guide

This guide provides step-by-step instructions for creating the required custom fields in your NinjaRMM instance.

## Overview

The temperature monitoring scripts write data to **7 custom fields** that must be created at the **Device level** before deploying the scripts.

⚠️ **Important**: Field names are case-sensitive and must match exactly as shown below.

## Required Custom Fields

| Field Name | Type | Scope | Description |
|------------|------|-------|-------------|
| `cpuTemperatureCelsius` | Decimal | Device | Highest CPU temperature in °C at last check |
| `gpuTemperatureCelsius` | Decimal | Device | Highest GPU temperature in °C at last check |
| `temperatureStatus` | Text | Device | Current status: OK, WARNING, CRITICAL, or ERROR |
| `lastTemperatureCheck` | Date/Time | Device | Timestamp of last successful reading (ISO 8601) |
| `temperatureAlertDetail` | Text or Wysiwyg | Device | Human-readable summary of last alert event |
| `cpuTemperatureHistory` | Text | Device | Last 5 readings as comma-separated list |
| `remediationActionTaken` | Text | Device | Description of any remediation action taken |

## Step-by-Step Field Creation

### Step 1: Access Custom Fields

1. Log in to your NinjaRMM dashboard
2. Navigate to **Administration** → **Devices** → **Custom Fields**
3. Click **+ Add Custom Field** button

### Step 2: Create cpuTemperatureCelsius

**Field Configuration:**
- **Field Name**: `cpuTemperatureCelsius`
- **Technical Name**: `cpuTemperatureCelsius` (auto-generated, do not change)
- **Field Type**: `Decimal`
- **Scope**: `Device`
- **Description**: "CPU temperature in degrees Celsius"
- **Decimal Places**: 1 or 2 (recommended: 1)
- **Required**: No
- **Visible in Device Details**: Yes

**Screenshot Placeholder**: `[Screenshot: Creating cpuTemperatureCelsius field]`

Click **Save**.

### Step 3: Create gpuTemperatureCelsius

**Field Configuration:**
- **Field Name**: `gpuTemperatureCelsius`
- **Technical Name**: `gpuTemperatureCelsius`
- **Field Type**: `Decimal`
- **Scope**: `Device`
- **Description**: "GPU temperature in degrees Celsius"
- **Decimal Places**: 1 or 2 (recommended: 1)
- **Required**: No
- **Visible in Device Details**: Yes

**Screenshot Placeholder**: `[Screenshot: Creating gpuTemperatureCelsius field]`

Click **Save**.

### Step 4: Create temperatureStatus

**Field Configuration:**
- **Field Name**: `temperatureStatus`
- **Technical Name**: `temperatureStatus`
- **Field Type**: `Text`
- **Scope**: `Device`
- **Description**: "Temperature monitoring status (OK, WARNING, CRITICAL, ERROR)"
- **Max Length**: 50
- **Required**: No
- **Visible in Device Details**: Yes

**Screenshot Placeholder**: `[Screenshot: Creating temperatureStatus field]`

Click **Save**.

### Step 5: Create lastTemperatureCheck

**Field Configuration:**
- **Field Name**: `lastTemperatureCheck`
- **Technical Name**: `lastTemperatureCheck`
- **Field Type**: `Date/Time`
- **Scope**: `Device`
- **Description**: "Timestamp of last temperature check (ISO 8601)"
- **Required**: No
- **Visible in Device Details**: Yes

**Screenshot Placeholder**: `[Screenshot: Creating lastTemperatureCheck field]`

Click **Save**.

### Step 6: Create temperatureAlertDetail

**Field Configuration:**
- **Field Name**: `temperatureAlertDetail`
- **Technical Name**: `temperatureAlertDetail`
- **Field Type**: `Text` or `Wysiwyg` (Text recommended)
- **Scope**: `Device`
- **Description**: "Detailed information about temperature alerts and top processes"
- **Max Length**: 2000 (if using Text field type)
- **Required**: No
- **Visible in Device Details**: Yes
- **Searchable**: Yes (recommended)

**Screenshot Placeholder**: `[Screenshot: Creating temperatureAlertDetail field]`

Click **Save**.

### Step 7: Create cpuTemperatureHistory

**Field Configuration:**
- **Field Name**: `cpuTemperatureHistory`
- **Technical Name**: `cpuTemperatureHistory`
- **Field Type**: `Text`
- **Scope**: `Device`
- **Description**: "Last 5 CPU temperature readings (comma-separated)"
- **Max Length**: 200
- **Required**: No
- **Visible in Device Details**: Yes

**Screenshot Placeholder**: `[Screenshot: Creating cpuTemperatureHistory field]`

Click **Save**.

### Step 8: Create remediationActionTaken

**Field Configuration:**
- **Field Name**: `remediationActionTaken`
- **Technical Name**: `remediationActionTaken`
- **Field Type**: `Text`
- **Scope**: `Device`
- **Description**: "Description of automatic remediation action (if any)"
- **Max Length**: 500
- **Required**: No
- **Visible in Device Details**: Yes

**Screenshot Placeholder**: `[Screenshot: Creating remediationActionTaken field]`

Click **Save**.

## Verification

After creating all 7 fields, verify your setup:

1. Navigate to **Administration** → **Devices** → **Custom Fields**
2. Confirm all 7 fields are listed
3. Check that all field names match exactly (case-sensitive)
4. Verify all fields have **Device** scope

**Screenshot Placeholder**: `[Screenshot: List of all 7 custom fields]`

## Creating a Dashboard Widget (Optional)

To visualize temperature data across all devices:

1. Navigate to **Dashboards** → **Create New Dashboard** (or edit existing)
2. Click **Add Widget**
3. Choose **Custom Field Widget** or **Device List Widget**
4. Configure columns to display:
   - Device Name
   - `cpuTemperatureCelsius`
   - `gpuTemperatureCelsius`
   - `temperatureStatus`
   - `lastTemperatureCheck`
5. Add filtering:
   - Filter by `temperatureStatus` = "WARNING" or "CRITICAL"
6. Save widget

**Screenshot Placeholder**: `[Screenshot: Temperature monitoring dashboard widget]`

## Field Name Reference

For use in scripts via `ninjarmm-cli`:

```bash
# Set CPU temperature
ninjarmm-cli set cpuTemperatureCelsius "75.5"

# Set GPU temperature
ninjarmm-cli set gpuTemperatureCelsius "82.3"

# Set status
ninjarmm-cli set temperatureStatus "WARNING"

# Set timestamp
ninjarmm-cli set lastTemperatureCheck "2026-02-19T14:32:00"

# Set alert detail
ninjarmm-cli set temperatureAlertDetail "WARNING: CPU at 83°C..."

# Set history
ninjarmm-cli set cpuTemperatureHistory "70.5, 72.1, 75.8, 78.2, 83.0"

# Set remediation action
ninjarmm-cli set remediationActionTaken "Killed process: chrome (PID: 12345)"
```

## Troubleshooting

### Field Names Not Recognized

**Problem**: Scripts report "Failed to set NinjaRMM field" errors.

**Solution**: 
- Verify field names match exactly (case-sensitive)
- Check that fields are scoped to **Device**, not Organization or Location
- Ensure `ninjarmm-cli` is updated to the latest version

### Fields Not Visible on Device Page

**Problem**: Custom fields don't appear on device detail pages.

**Solution**:
- Edit each custom field
- Ensure "Visible in Device Details" is enabled
- Refresh the device page or clear browser cache

### Data Not Updating

**Problem**: Field values remain empty or outdated after script execution.

**Solution**:
- Check script execution logs (`tempmonitor.log`)
- Verify NinjaRMM agent is online and communicating
- Run script manually with `-Debug` or `DEBUG=true` to see detailed output
- Confirm `ninjarmm-cli` exists at the expected path

## Next Steps

After completing custom field setup:

1. ✅ Install platform dependencies: See installation scripts in `scripts/` directory
2. ✅ Test scripts manually: Run with debug mode enabled
3. ✅ Configure NinjaRMM policies: See [DEPLOYMENT.md](DEPLOYMENT.md)
4. ✅ Set up condition-based alerts: See [DEPLOYMENT.md](DEPLOYMENT.md)

---

**Note**: Screenshots are placeholders. In a production deployment, replace these with actual screenshots from your NinjaRMM instance for easier reference by technicians.
