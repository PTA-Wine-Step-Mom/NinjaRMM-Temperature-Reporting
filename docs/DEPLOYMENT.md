# NinjaRMM Deployment Guide

This comprehensive guide walks you through deploying the temperature monitoring scripts as NinjaRMM automation policies.

## Prerequisites Checklist

Before deploying, ensure:

- ✅ Custom fields are created (see [CUSTOM_FIELDS_SETUP.md](CUSTOM_FIELDS_SETUP.md))
- ✅ Dependencies are installed on test devices
- ✅ Scripts have been tested manually with `-Debug` flag
- ✅ Threshold values are configured appropriately
- ✅ You have NinjaRMM administrator access

## Deployment Overview

You will create **3 separate scripts and policies** in NinjaRMM:
1. **Windows Temperature Monitor** (PowerShell)
2. **macOS Temperature Monitor** (Bash)
3. **Linux Temperature Monitor** (Bash)

Each policy will:
- Run every 15 minutes
- Execute with elevated privileges (SYSTEM/root)
- Write results to custom fields
- Trigger condition-based alerts on threshold breach

---

## Part 1: Creating NinjaRMM Scripts

### Step 1: Create Windows Script

1. Navigate to **Administration** → **Library** → **Scripting**
2. Click **+ New** → **New Script**
3. Configure script properties:

   **General Settings:**
   - **Name**: `Temperature Monitor - Windows`
   - **Description**: `Monitors CPU and GPU temperatures on Windows devices. Alerts on WARNING (80°C) and CRITICAL (90°C) thresholds. Automatically terminates high-CPU processes on CRITICAL events.`
   - **Category**: Create or select category: `Monitoring`
   - **Platform**: `Windows`
   - **Script Type**: `PowerShell`
   - **Language Version**: `PowerShell 5.1+` (or `PowerShell 7+` if preferred)

4. **Script Content**: Copy the entire contents of `scripts/windows/Get-Temperature.ps1` into the script editor

5. **Script Settings**:
   - **Timeout**: `300 seconds` (5 minutes)
   - **Enabled**: ✅ Yes
   - **Parameters**: (Optional) Add parameter for disabling remediation:
     ```
     -EnableRemediation $true
     ```

6. **Success Criteria**:
   - **Exit Code**: `0-2` (0=OK, 1=WARNING, 2=CRITICAL)
   - Note: Exit code 3 (ERROR) is a failure

7. Click **Save**

**Screenshot Placeholder**: `[Screenshot: Windows script configuration]`

---

### Step 2: Create macOS Script

1. Navigate to **Administration** → **Library** → **Scripting**
2. Click **+ New** → **New Script**
3. Configure script properties:

   **General Settings:**
   - **Name**: `Temperature Monitor - macOS`
   - **Description**: `Monitors CPU and GPU temperatures on macOS devices using powermetrics. Alerts on WARNING (80°C) and CRITICAL (90°C) thresholds. Automatically terminates high-CPU processes on CRITICAL events.`
   - **Category**: `Monitoring`
   - **Platform**: `Mac`
   - **Script Type**: `Bash`

4. **Script Content**: Copy the entire contents of `scripts/macos/get_temperature.sh` into the script editor

5. **Script Settings**:
   - **Timeout**: `300 seconds` (5 minutes)
   - **Enabled**: ✅ Yes
   - **Run As**: `root` (required for powermetrics access)
   - **Environment Variables**: (Optional)
     ```
     ENABLE_REMEDIATION=true
     DEBUG=false
     ```

6. **Success Criteria**:
   - **Exit Code**: `0-2`

7. Click **Save**

**Screenshot Placeholder**: `[Screenshot: macOS script configuration]`

---

### Step 3: Create Linux Script

1. Navigate to **Administration** → **Library** → **Scripting**
2. Click **+ New** → **New Script**
3. Configure script properties:

   **General Settings:**
   - **Name**: `Temperature Monitor - Linux`
   - **Description**: `Monitors CPU and GPU temperatures on Linux devices using lm-sensors. Alerts on WARNING (80°C) and CRITICAL (90°C) thresholds. Automatically terminates high-CPU processes on CRITICAL events.`
   - **Category**: `Monitoring`
   - **Platform**: `Linux`
   - **Script Type**: `Bash`

4. **Script Content**: Copy the entire contents of `scripts/linux/get_temperature.sh` into the script editor

5. **Script Settings**:
   - **Timeout**: `300 seconds` (5 minutes)
   - **Enabled**: ✅ Yes
   - **Run As**: `root` (required for sensor access)
   - **Environment Variables**: (Optional)
     ```
     ENABLE_REMEDIATION=true
     DEBUG=false
     ```

6. **Success Criteria**:
   - **Exit Code**: `0-2`

7. Click **Save**

**Screenshot Placeholder**: `[Screenshot: Linux script configuration]`

---

## Part 2: Creating Automation Policies

### Step 4: Create Windows Policy

1. Navigate to **Administration** → **Policies** → **Automation**
2. Click **+ New Policy** or edit an existing policy
3. Configure policy:

   **General:**
   - **Name**: `Temperature Monitoring - Windows`
   - **Description**: `Runs temperature monitoring every 15 minutes on Windows devices`
   - **Status**: ✅ Active
   
   **Conditions:**
   - Click **+ Add Condition**
   - **Type**: `Device OS`
   - **Operator**: `is`
   - **Value**: `Windows`

4. **Add Automation Task**:
   - Click **+ Add Task** in the Tasks section
   - **Task Type**: `Run Script`
   - **Script**: Select `Temperature Monitor - Windows`
   - **Schedule**: `Recurring`
   - **Frequency**: `Every 15 minutes`
   - **Run As**: `System` (automatic on Windows)
   - **Enabled**: ✅ Yes

5. **Target Devices**:
   - **Apply To**: 
     - Option A: `All Windows devices` (global deployment)
     - Option B: Specific organizations, locations, or device groups

6. Click **Save Policy**

**Screenshot Placeholder**: `[Screenshot: Windows automation policy]`

---

### Step 5: Create macOS Policy

1. Navigate to **Administration** → **Policies** → **Automation**
2. Click **+ New Policy**
3. Configure policy:

   **General:**
   - **Name**: `Temperature Monitoring - macOS`
   - **Description**: `Runs temperature monitoring every 15 minutes on macOS devices`
   - **Status**: ✅ Active
   
   **Conditions:**
   - Click **+ Add Condition**
   - **Type**: `Device OS`
   - **Operator**: `is`
   - **Value**: `Mac`

4. **Add Automation Task**:
   - Click **+ Add Task**
   - **Task Type**: `Run Script`
   - **Script**: Select `Temperature Monitor - macOS`
   - **Schedule**: `Recurring`
   - **Frequency**: `Every 15 minutes`
   - **Run As**: `root` (automatic on Mac)
   - **Enabled**: ✅ Yes

5. **Target Devices**:
   - **Apply To**: All Mac devices or specific groups

6. Click **Save Policy**

**Screenshot Placeholder**: `[Screenshot: macOS automation policy]`

---

### Step 6: Create Linux Policy

1. Navigate to **Administration** → **Policies** → **Automation**
2. Click **+ New Policy**
3. Configure policy:

   **General:**
   - **Name**: `Temperature Monitoring - Linux`
   - **Description**: `Runs temperature monitoring every 15 minutes on Linux devices`
   - **Status**: ✅ Active
   
   **Conditions:**
   - Click **+ Add Condition**
   - **Type**: `Device OS`
   - **Operator**: `is`
   - **Value**: `Linux`

4. **Add Automation Task**:
   - Click **+ Add Task**
   - **Task Type**: `Run Script`
   - **Script**: Select `Temperature Monitor - Linux`
   - **Schedule**: `Recurring`
   - **Frequency**: `Every 15 minutes`
   - **Run As**: `root` (automatic on Linux)
   - **Enabled**: ✅ Yes

5. **Target Devices**:
   - **Apply To**: All Linux devices or specific groups

6. Click **Save Policy**

**Screenshot Placeholder**: `[Screenshot: Linux automation policy]`

---

## Part 3: Setting Up Condition-Based Alerts

Conditions allow NinjaRMM to trigger alerts when script exit codes indicate WARNING or CRITICAL status.

### Step 7: Create WARNING Condition

1. Navigate to **Administration** → **Conditions** → **+ New Condition**

2. **General Settings**:
   - **Name**: `Temperature WARNING`
   - **Description**: `Triggers when device temperature reaches WARNING threshold`
   - **Severity**: `Warning` (yellow)
   - **Category**: `Device Health`

3. **Condition Logic**:
   - **Type**: `Script Exit Code`
   - **Script**: Select `Temperature Monitor - Windows` (or create separate conditions for each platform)
   - **Operator**: `equals`
   - **Value**: `1`
   - **Duration**: `Immediately` (trigger on first occurrence)

4. **Actions** (optional):
   - **Send Email**: ✅ Enable if desired
   - **Create Ticket**: ⬜ Usually not needed for WARNING
   - **Notification**: ✅ Send notification to technician dashboard

5. **Target**: Apply to same devices as the automation policy

6. Click **Save**

**Repeat for macOS and Linux** scripts or use a combined approach if NinjaRMM supports it.

---

### Step 8: Create CRITICAL Condition

1. Navigate to **Administration** → **Conditions** → **+ New Condition**

2. **General Settings**:
   - **Name**: `Temperature CRITICAL`
   - **Description**: `Triggers when device temperature reaches CRITICAL threshold (remediation action taken)`
   - **Severity**: `Critical` (red)
   - **Category**: `Device Health`

3. **Condition Logic**:
   - **Type**: `Script Exit Code`
   - **Script**: Select `Temperature Monitor - Windows`
   - **Operator**: `equals`
   - **Value**: `2`
   - **Duration**: `Immediately`

4. **Actions**:
   - **Send Email**: ✅ Enable (send to senior technicians)
   - **Create Ticket**: ✅ Consider enabling for automatic ticket creation
   - **Notification**: ✅ High-priority notification
   - **SMS/Push**: ✅ Consider for after-hours alerts

5. **Target**: Apply to same devices as the automation policy

6. Click **Save**

**Repeat for macOS and Linux** scripts.

---

### Step 9: Create ERROR Condition

1. Navigate to **Administration** → **Conditions** → **+ New Condition**

2. **General Settings**:
   - **Name**: `Temperature Monitor ERROR`
   - **Description**: `Triggers when temperature monitoring script fails`
   - **Severity**: `Warning` (yellow) or `Error` (orange)
   - **Category**: `Script Failure`

3. **Condition Logic**:
   - **Type**: `Script Exit Code`
   - **Script**: Select `Temperature Monitor - Windows`
   - **Operator**: `equals`
   - **Value**: `3`
   - **Duration**: `Persists for 1 hour` (avoid alerts for transient issues)

4. **Actions**:
   - **Send Email**: ✅ Enable
   - **Create Ticket**: ⬜ Optional
   - **Notification**: ✅ Send notification

5. Click **Save**

**Screenshot Placeholder**: `[Screenshot: Condition configurations]`

---

## Part 4: Creating Dashboard Widgets

### Step 10: Temperature Status Widget

1. Navigate to **Dashboards** → Select or create a dashboard
2. Click **+ Add Widget**
3. Configure widget:

   **Widget Settings:**
   - **Type**: `Device List` or `Custom Field Widget`
   - **Name**: `Temperature Status Overview`
   - **Columns to Display**:
     - Device Name
     - Organization (if MSP)
     - `cpuTemperatureCelsius`
     - `gpuTemperatureCelsius`
     - `temperatureStatus`
     - `lastTemperatureCheck`

4. **Filters**:
   - Option A: Show all devices
   - Option B: Filter by `temperatureStatus` != "OK" (show only issues)

5. **Sorting**: Sort by `temperatureStatus` (CRITICAL first) or by `cpuTemperatureCelsius` (highest first)

6. **Refresh**: Set auto-refresh to 5 minutes

7. Click **Save Widget**

**Screenshot Placeholder**: `[Screenshot: Temperature dashboard widget]`

---

### Step 11: Critical Temperature Alert Widget

1. Add another widget to the same dashboard
2. **Widget Type**: `Device List`
3. **Name**: `Critical Temperature Devices`
4. **Filters**:
   - `temperatureStatus` equals `CRITICAL`
5. **Columns**:
   - Device Name
   - `cpuTemperatureCelsius`
   - `lastTemperatureCheck`
   - `remediationActionTaken`
6. **Sorting**: By `lastTemperatureCheck` (most recent first)
7. **Alerts**: Enable alert indicator on widget
8. Click **Save Widget**

---

## Part 5: Testing and Validation

### Step 12: Pilot Testing

Before full deployment:

1. **Select Test Devices** (3-5 devices per platform):
   - Create a device group: `Temperature Monitoring - Pilot`
   - Include: 1 desktop, 1 laptop, 1 server per platform

2. **Apply Policies** to pilot group only:
   - Edit each automation policy
   - Set **Target Devices** to pilot group
   - Save policy

3. **Monitor for 48 Hours**:
   - Check that scripts run successfully every 15 minutes
   - Verify custom fields are being updated
   - Check log files on devices
   - Review any alerts generated

4. **Validation Checklist**:
   - ✅ `lastTemperatureCheck` updates every 15 minutes
   - ✅ Temperature values are reasonable
   - ✅ Status changes appropriately based on thresholds
   - ✅ Alerts trigger when expected
   - ✅ Log files are created and rotated properly
   - ✅ No script timeout errors

---

### Step 13: Gradual Rollout

After successful pilot:

1. **Phase 1**: Deploy to 25% of devices
   - Expand policy targets
   - Monitor for 1 week

2. **Phase 2**: Deploy to 50% of devices
   - Monitor for 1 week

3. **Phase 3**: Deploy to 75% of devices
   - Monitor for 1 week

4. **Phase 4**: Full deployment to all devices
   - Continue monitoring
   - Adjust thresholds based on real-world data

---

## Part 6: Ongoing Maintenance

### Regular Reviews

**Weekly:**
- Review devices with frequent CRITICAL alerts
- Check for patterns in `remediationActionTaken` field
- Investigate devices with ERROR status

**Monthly:**
- Review threshold effectiveness
- Analyze false positive rate
- Update exclusion lists if needed
- Check for devices with no recent readings

**Quarterly:**
- Review overall alert volume
- Adjust thresholds for seasonal changes
- Update documentation based on lessons learned
- Review and optimize dashboard widgets

### Script Updates

When updating scripts:

1. Test new version in pilot environment first
2. Update script content in NinjaRMM
3. Deploy during maintenance window
4. Monitor closely for first 24 hours

---

## Troubleshooting Common Deployment Issues

### Scripts Not Running

**Symptoms**: `lastTemperatureCheck` not updating

**Possible Causes:**
1. Policy not applied to device
2. NinjaRMM agent offline
3. Script timeout
4. Permissions issue

**Resolution:**
- Check device policy assignments
- Verify agent status
- Review script execution history in NinjaRMM
- Check device log files

---

### Custom Fields Not Updating

**Symptoms**: Script runs but fields stay empty

**Possible Causes:**
1. Field names don't match exactly (case-sensitive)
2. `ninjarmm-cli` not found
3. Permissions issue

**Resolution:**
- Verify custom field names match exactly
- Check `ninjarmm-cli` path on device
- Review script logs for errors
- Run script manually with `-Debug` flag

---

### Too Many Alerts

**Symptoms**: Constant WARNING/CRITICAL alerts

**Possible Causes:**
1. Thresholds set too low for environment
2. Cooling issues across fleet
3. Seasonal temperature increase

**Resolution:**
- Review temperature history across devices
- Adjust thresholds upward if appropriate
- Investigate cooling infrastructure
- Check for dust/obstructions

---

### No Alerts on High Temperatures

**Symptoms**: Devices running hot but no alerts

**Possible Causes:**
1. Conditions not configured correctly
2. Notification settings incorrect
3. Scripts returning wrong exit codes

**Resolution:**
- Verify condition configurations
- Check notification channels
- Test script manually and check exit code
- Review condition history in NinjaRMM

---

## Advanced Configurations

### Per-Device-Type Thresholds

Create separate scripts with different thresholds:

1. **Conservative** (Servers):
   - WARNING: 75°C, CRITICAL: 85°C
   - Apply to server device group

2. **Standard** (Workstations):
   - WARNING: 80°C, CRITICAL: 90°C
   - Apply to desktop device group

3. **Aggressive** (Laptops):
   - WARNING: 85°C, CRITICAL: 95°C
   - Apply to laptop device group

### Disable Remediation for Specific Devices

For mission-critical systems where process termination is unacceptable:

1. Create a separate script with `EnableRemediation = false`
2. Create a device group for critical systems
3. Apply the non-remediation policy to this group

---

## Security Considerations

- Scripts run with elevated privileges (SYSTEM/root)
- Store scripts in NinjaRMM (not on endpoints)
- Restrict access to script editing in NinjaRMM
- Log all remediation actions for audit trail
- Regularly review remediation history

---

## Next Steps

After successful deployment:

1. ✅ Configure dashboard widgets for visibility
2. ✅ Document your specific threshold decisions
3. ✅ Train technicians on alert response procedures
4. ✅ Schedule regular review meetings
5. ✅ Integrate with existing incident management processes

---

**Remember**: Start small (pilot group), monitor closely, and expand gradually. Temperature monitoring is most effective when tuned to your specific environment and hardware.
