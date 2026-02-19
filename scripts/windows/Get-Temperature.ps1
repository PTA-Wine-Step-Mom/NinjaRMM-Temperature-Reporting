#Requires -Version 5.1
<#
.SYNOPSIS
    Collects CPU and GPU temperatures and writes results to NinjaRMM custom fields.

.DESCRIPTION
    # =============================================================================
    # Script Name  : Get-Temperature.ps1
    # Platform     : Windows
    # Description  : Collects CPU and GPU temperatures and writes results to
    #                NinjaRMM custom fields. Triggers alerts and remediation
    #                actions based on configurable thresholds.
    # Dependencies : LibreHardwareMonitor (Windows) / ninjarmm-cli (all platforms)
    # NinjaRMM Fields Used:
    #   - cpuTemperatureCelsius
    #   - gpuTemperatureCelsius
    #   - temperatureStatus
    #   - lastTemperatureCheck
    #   - temperatureAlertDetail
    #   - cpuTemperatureHistory
    #   - remediationActionTaken
    # Thresholds   : CPU Warning: 80°C | CPU Critical: 90°C
    #                GPU Warning: 85°C | GPU Critical: 95°C
    # Schedule     : Every 15 minutes via NinjaRMM Automation Policy
    # Author       : NinjaRMM Temperature Monitoring Team
    # Version      : 1.0.0
    # Last Updated : 2026-02-19
    # =============================================================================

.PARAMETER Debug
    Enable verbose debug output

.PARAMETER EnableRemediation
    Enable process termination on critical threshold breach (default: true)

.EXAMPLE
    .\Get-Temperature.ps1
    Run with default settings

.EXAMPLE
    .\Get-Temperature.ps1 -Debug
    Run with verbose debug output

.EXAMPLE
    .\Get-Temperature.ps1 -EnableRemediation $false
    Run without remediation (alerting only)
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$false)]
    [switch]$Debug,

    [Parameter(Mandatory=$false)]
    [bool]$EnableRemediation = $true
)

$ErrorActionPreference = 'Stop'

# =============================================================================
# CONFIGURATION - Adjust thresholds here
# =============================================================================

$CPU_WARNING_THRESHOLD = 80
$CPU_CRITICAL_THRESHOLD = 90
$GPU_WARNING_THRESHOLD = 85
$GPU_CRITICAL_THRESHOLD = 95

# System process exclusion list (case-insensitive)
$EXCLUDED_PROCESSES = @(
    'System', 'svchost', 'lsass', 'winlogon', 'csrss', 'smss',
    'wininit', 'services', 'NinjaRMM', 'NinjaRMMMaintenance'
)

# Paths
$NINJARMM_CLI_PATH = "C:\Program Files\NinjaRMM\ninjarmm-cli.exe"
$LOG_DIR = "C:\ProgramData\NinjaRMM\TempMonitor"
$LOG_FILE = Join-Path $LOG_DIR "tempmonitor.log"
$LIBREHARDWAREMONITOR_DLL = Join-Path $LOG_DIR "LibreHardwareMonitorLib.dll"
$MAX_LOG_SIZE = 1MB

# =============================================================================
# LOGGING FUNCTIONS
# =============================================================================

function Write-Log {
    <#
    .SYNOPSIS
        Writes a timestamped log entry to the log file and console
    .PARAMETER Message
        The message to log
    .PARAMETER Level
        Log level (INFO, WARNING, ERROR, DEBUG)
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$Message,
        
        [Parameter(Mandatory=$false)]
        [ValidateSet('INFO', 'WARNING', 'ERROR', 'DEBUG')]
        [string]$Level = 'INFO'
    )

    $timestamp = Get-Date -Format 'yyyy-MM-ddTHH:mm:ss'
    $logEntry = "[$timestamp] [$Level] $Message"

    # Create log directory if it doesn't exist
    if (-not (Test-Path $LOG_DIR)) {
        New-Item -ItemType Directory -Path $LOG_DIR -Force | Out-Null
    }

    # Rotate log if too large
    if (Test-Path $LOG_FILE) {
        $logSize = (Get-Item $LOG_FILE).Length
        if ($logSize -gt $MAX_LOG_SIZE) {
            $rotatedLog = "$LOG_FILE.1"
            if (Test-Path $rotatedLog) {
                Remove-Item $rotatedLog -Force
            }
            Move-Item $LOG_FILE $rotatedLog -Force
        }
    }

    # Write to log file
    Add-Content -Path $LOG_FILE -Value $logEntry

    # Write to console based on level
    switch ($Level) {
        'ERROR' { Write-Error $Message }
        'WARNING' { Write-Warning $Message }
        'DEBUG' { if ($Debug) { Write-Host $logEntry } }
        default { Write-Output $logEntry }
    }
}

# =============================================================================
# PRIVILEGE CHECK
# =============================================================================

function Test-Administrator {
    <#
    .SYNOPSIS
        Checks if the script is running with Administrator privileges
    .OUTPUTS
        Boolean indicating if running as Administrator
    #>
    $currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
    return $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

if (-not (Test-Administrator)) {
    Write-Log "Script must be run with Administrator privileges" -Level ERROR
    exit 3
}

# =============================================================================
# NINJARMM CLI VALIDATION
# =============================================================================

function Test-NinjaRMMCli {
    <#
    .SYNOPSIS
        Validates that ninjarmm-cli.exe exists
    .OUTPUTS
        Boolean indicating if ninjarmm-cli.exe is available
    #>
    if (-not (Test-Path $NINJARMM_CLI_PATH)) {
        Write-Log "ninjarmm-cli.exe not found at: $NINJARMM_CLI_PATH" -Level ERROR
        return $false
    }
    return $true
}

function Set-NinjaRMMField {
    <#
    .SYNOPSIS
        Sets a NinjaRMM custom field value
    .PARAMETER FieldName
        The name of the custom field
    .PARAMETER Value
        The value to set
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$FieldName,
        
        [Parameter(Mandatory=$true)]
        [string]$Value
    )

    try {
        Write-Log "Setting $FieldName = $Value" -Level DEBUG
        & $NINJARMM_CLI_PATH set $FieldName $Value
        if ($LASTEXITCODE -ne 0) {
            Write-Log "Failed to set NinjaRMM field $FieldName" -Level ERROR
        }
    }
    catch {
        Write-Log "Exception setting NinjaRMM field ${FieldName}: $($_.Exception.Message)" -Level ERROR
    }
}

# =============================================================================
# TEMPERATURE READING FUNCTIONS
# =============================================================================

function Get-TemperatureFromLibreHardwareMonitor {
    <#
    .SYNOPSIS
        Reads temperature data using LibreHardwareMonitor
    .OUTPUTS
        Hashtable with CPUTemp and GPUTemp keys (values in Celsius or $null)
    #>
    param()

    $result = @{
        CPUTemp = $null
        GPUTemp = $null
    }

    try {
        if (-not (Test-Path $LIBREHARDWAREMONITOR_DLL)) {
            Write-Log "LibreHardwareMonitorLib.dll not found at: $LIBREHARDWAREMONITOR_DLL" -Level WARNING
            return $result
        }

        Write-Log "Loading LibreHardwareMonitor DLL" -Level DEBUG
        [System.Reflection.Assembly]::LoadFile($LIBREHARDWAREMONITOR_DLL) | Out-Null

        $computer = New-Object LibreHardwareMonitor.Hardware.Computer
        $computer.IsCpuEnabled = $true
        $computer.IsGpuEnabled = $true
        $computer.Open()

        $maxCpuTemp = $null
        $maxGpuTemp = $null

        foreach ($hardware in $computer.Hardware) {
            $hardware.Update()
            
            Write-Log "Hardware: $($hardware.Name) | Type: $($hardware.HardwareType)" -Level DEBUG

            # Check for CPU temperatures
            if ($hardware.HardwareType -eq 'CPU') {
                foreach ($sensor in $hardware.Sensors) {
                    if ($sensor.SensorType -eq 'Temperature' -and $sensor.Value) {
                        $temp = [float]$sensor.Value
                        Write-Log "CPU Sensor: $($sensor.Name) = ${temp}°C" -Level DEBUG
                        if ($null -eq $maxCpuTemp -or $temp -gt $maxCpuTemp) {
                            $maxCpuTemp = $temp
                        }
                    }
                }
            }

            # Check for GPU temperatures
            if ($hardware.HardwareType -match 'Gpu') {
                foreach ($sensor in $hardware.Sensors) {
                    if ($sensor.SensorType -eq 'Temperature' -and $sensor.Value) {
                        $temp = [float]$sensor.Value
                        Write-Log "GPU Sensor: $($sensor.Name) = ${temp}°C" -Level DEBUG
                        if ($null -eq $maxGpuTemp -or $temp -gt $maxGpuTemp) {
                            $maxGpuTemp = $temp
                        }
                    }
                }
            }

            # Check sub-hardware
            foreach ($subHardware in $hardware.SubHardware) {
                $subHardware.Update()
                foreach ($sensor in $subHardware.Sensors) {
                    if ($sensor.SensorType -eq 'Temperature' -and $sensor.Value) {
                        $temp = [float]$sensor.Value
                        Write-Log "Sub-Hardware Sensor: $($sensor.Name) = ${temp}°C" -Level DEBUG
                        
                        if ($subHardware.HardwareType -eq 'CPU') {
                            if ($null -eq $maxCpuTemp -or $temp -gt $maxCpuTemp) {
                                $maxCpuTemp = $temp
                            }
                        }
                        elseif ($subHardware.HardwareType -match 'Gpu') {
                            if ($null -eq $maxGpuTemp -or $temp -gt $maxGpuTemp) {
                                $maxGpuTemp = $temp
                            }
                        }
                    }
                }
            }
        }

        $computer.Close()

        $result.CPUTemp = $maxCpuTemp
        $result.GPUTemp = $maxGpuTemp

        Write-Log "LibreHardwareMonitor results - CPU: $maxCpuTemp, GPU: $maxGpuTemp" -Level INFO

    }
    catch {
        Write-Log "Error reading from LibreHardwareMonitor: $($_.Exception.Message)" -Level ERROR
    }

    return $result
}

function Get-TemperatureFromWMI {
    <#
    .SYNOPSIS
        Reads temperature data from WMI (MSAcpi_ThermalZoneTemperature)
    .OUTPUTS
        Hashtable with CPUTemp key (value in Celsius or $null)
    #>
    param()

    $result = @{
        CPUTemp = $null
        GPUTemp = $null
    }

    try {
        $thermalZones = Get-WmiObject -Namespace "root/wmi" -Class MSAcpi_ThermalZoneTemperature -ErrorAction SilentlyContinue

        if ($thermalZones) {
            $maxTemp = $null
            foreach ($zone in $thermalZones) {
                # Convert from tenths of Kelvin to Celsius
                $tempCelsius = ($zone.CurrentTemperature / 10) - 273.15
                Write-Log "Thermal Zone: $($zone.InstanceName) = ${tempCelsius}°C" -Level DEBUG
                
                if ($null -eq $maxTemp -or $tempCelsius -gt $maxTemp) {
                    $maxTemp = $tempCelsius
                }
            }
            $result.CPUTemp = $maxTemp
            Write-Log "WMI Thermal Zone maximum temperature: $maxTemp" -Level INFO
        }
        else {
            Write-Log "No WMI thermal zones found" -Level WARNING
        }
    }
    catch {
        Write-Log "Error reading from WMI: $($_.Exception.Message)" -Level ERROR
    }

    return $result
}

function Get-SystemTemperature {
    <#
    .SYNOPSIS
        Gets system temperature using available methods (LibreHardwareMonitor, then WMI fallback)
    .OUTPUTS
        Hashtable with CPUTemp and GPUTemp keys
    #>
    param()

    # Try LibreHardwareMonitor first
    $temps = Get-TemperatureFromLibreHardwareMonitor

    # If CPU temp is null, try WMI fallback
    if ($null -eq $temps.CPUTemp) {
        Write-Log "LibreHardwareMonitor did not return CPU temperature, trying WMI fallback" -Level WARNING
        $wmiTemps = Get-TemperatureFromWMI
        $temps.CPUTemp = $wmiTemps.CPUTemp
    }

    return $temps
}

# =============================================================================
# THRESHOLD EVALUATION
# =============================================================================

function Get-TemperatureStatus {
    <#
    .SYNOPSIS
        Evaluates temperature readings against thresholds
    .PARAMETER CPUTemp
        CPU temperature in Celsius
    .PARAMETER GPUTemp
        GPU temperature in Celsius
    .OUTPUTS
        String: OK, WARNING, CRITICAL, or ERROR
    #>
    param(
        [Parameter(Mandatory=$false)]
        [float]$CPUTemp,
        
        [Parameter(Mandatory=$false)]
        [float]$GPUTemp
    )

    # If we have no readings at all, return ERROR
    if ($null -eq $CPUTemp) {
        return 'ERROR'
    }

    # Check CRITICAL thresholds first
    if ($CPUTemp -ge $CPU_CRITICAL_THRESHOLD) {
        return 'CRITICAL'
    }
    if ($null -ne $GPUTemp -and $GPUTemp -ge $GPU_CRITICAL_THRESHOLD) {
        return 'CRITICAL'
    }

    # Check WARNING thresholds
    if ($CPUTemp -ge $CPU_WARNING_THRESHOLD) {
        return 'WARNING'
    }
    if ($null -ne $GPUTemp -and $GPUTemp -ge $GPU_WARNING_THRESHOLD) {
        return 'WARNING'
    }

    return 'OK'
}

# =============================================================================
# PROCESS MANAGEMENT
# =============================================================================

function Get-TopCPUProcesses {
    <#
    .SYNOPSIS
        Gets the top 3 CPU-consuming processes
    .OUTPUTS
        Array of process objects sorted by CPU usage
    #>
    param(
        [Parameter(Mandatory=$false)]
        [int]$Count = 3
    )

    try {
        # Get processes with CPU usage (requires at least two samples)
        $processes = Get-Process | Where-Object { $_.CPU -gt 0 } | 
                     Sort-Object CPU -Descending | 
                     Select-Object -First $Count Name, Id, CPU

        return $processes
    }
    catch {
        Write-Log "Error getting top CPU processes: $($_.Exception.Message)" -Level ERROR
        return @()
    }
}

function Stop-TopCPUProcess {
    <#
    .SYNOPSIS
        Stops the top CPU-consuming process (excluding system processes)
    .OUTPUTS
        String describing the action taken
    #>
    param()

    try {
        $topProcesses = Get-TopCPUProcesses

        foreach ($process in $topProcesses) {
            $processName = $process.Name
            $processId = $process.Id
            $cpuUsage = $process.CPU

            # Check if process is in exclusion list (case-insensitive)
            $isExcluded = $false
            foreach ($excluded in $EXCLUDED_PROCESSES) {
                if ($processName -like $excluded) {
                    $isExcluded = $true
                    Write-Log "Process $processName (PID: $processId) is in exclusion list, skipping" -Level INFO
                    break
                }
            }

            if (-not $isExcluded) {
                Write-Log "Terminating process: $processName (PID: $processId, CPU: $cpuUsage)" -Level WARNING
                Stop-Process -Id $processId -Force
                return "Killed process: $processName (PID: $processId, CPU: $cpuUsage)"
            }
        }

        return "All top CPU processes are system-critical (excluded from termination)"
    }
    catch {
        $errorMsg = "Error terminating process: $($_.Exception.Message)"
        Write-Log $errorMsg -Level ERROR
        return $errorMsg
    }
}

# =============================================================================
# HISTORY MANAGEMENT
# =============================================================================

function Update-TemperatureHistory {
    <#
    .SYNOPSIS
        Updates the temperature history, keeping the last 5 readings
    .PARAMETER CurrentTemp
        Current CPU temperature
    .PARAMETER ExistingHistory
        Existing history string (comma-separated)
    .OUTPUTS
        Updated history string
    #>
    param(
        [Parameter(Mandatory=$true)]
        [float]$CurrentTemp,
        
        [Parameter(Mandatory=$false)]
        [string]$ExistingHistory = ""
    )

    $historyList = @()
    
    if ($ExistingHistory -and $ExistingHistory -ne "N/A" -and $ExistingHistory.Trim() -ne "") {
        $historyList = $ExistingHistory -split ',' | ForEach-Object { $_.Trim() }
    }

    # Add current reading
    $historyList += "$CurrentTemp"

    # Keep only last 5
    if ($historyList.Count -gt 5) {
        $historyList = $historyList[($historyList.Count - 5)..($historyList.Count - 1)]
    }

    return ($historyList -join ', ')
}

# =============================================================================
# MAIN EXECUTION
# =============================================================================

try {
    Write-Log "========== Temperature Monitoring Script Started ==========" -Level INFO

    # Validate NinjaRMM CLI
    if (-not (Test-NinjaRMMCli)) {
        Write-Log "Cannot proceed without ninjarmm-cli.exe" -Level ERROR
        exit 3
    }

    # Get temperature readings
    Write-Log "Reading system temperatures..." -Level INFO
    $temps = Get-SystemTemperature

    $cpuTemp = $temps.CPUTemp
    $gpuTemp = $temps.GPUTemp

    # Log readings
    if ($null -ne $cpuTemp) {
        Write-Log "CPU Temperature: ${cpuTemp}°C" -Level INFO
    }
    else {
        Write-Log "CPU Temperature: Unable to read" -Level ERROR
    }

    if ($null -ne $gpuTemp) {
        Write-Log "GPU Temperature: ${gpuTemp}°C" -Level INFO
    }
    else {
        Write-Log "GPU Temperature: Not available or unable to read" -Level INFO
    }

    # Determine status
    $status = Get-TemperatureStatus -CPUTemp $cpuTemp -GPUTemp $gpuTemp
    Write-Log "Temperature Status: $status" -Level INFO

    # Get timestamp
    $timestamp = Get-Date -Format 'yyyy-MM-ddTHH:mm:ss'

    # Write base fields to NinjaRMM
    if ($null -ne $cpuTemp) {
        Set-NinjaRMMField -FieldName "cpuTemperatureCelsius" -Value $cpuTemp.ToString("F1")
    }
    else {
        Set-NinjaRMMField -FieldName "cpuTemperatureCelsius" -Value "N/A"
    }

    if ($null -ne $gpuTemp) {
        Set-NinjaRMMField -FieldName "gpuTemperatureCelsius" -Value $gpuTemp.ToString("F1")
    }
    else {
        Set-NinjaRMMField -FieldName "gpuTemperatureCelsius" -Value "N/A"
    }

    Set-NinjaRMMField -FieldName "temperatureStatus" -Value $status
    Set-NinjaRMMField -FieldName "lastTemperatureCheck" -Value $timestamp

    # Handle different status levels
    $exitCode = 0
    $alertDetail = ""
    $remediationAction = ""

    switch ($status) {
        'OK' {
            $alertDetail = "OK: CPU at ${cpuTemp}°C"
            if ($null -ne $gpuTemp) {
                $alertDetail += ", GPU at ${gpuTemp}°C"
            }
            $alertDetail += ". Timestamp: $timestamp"
            $exitCode = 0
        }

        'WARNING' {
            $alertDetail = "WARNING: CPU at ${cpuTemp}°C (threshold: ${CPU_WARNING_THRESHOLD}°C)"
            if ($null -ne $gpuTemp) {
                $alertDetail += ", GPU at ${gpuTemp}°C (threshold: ${GPU_WARNING_THRESHOLD}°C)"
            }
            $alertDetail += ". Timestamp: $timestamp"
            
            Write-Log $alertDetail -Level WARNING
            $exitCode = 1
        }

        'CRITICAL' {
            $alertDetail = "CRITICAL: CPU at ${cpuTemp}°C (threshold: ${CPU_CRITICAL_THRESHOLD}°C)"
            if ($null -ne $gpuTemp) {
                $alertDetail += ", GPU at ${gpuTemp}°C (threshold: ${GPU_CRITICAL_THRESHOLD}°C)"
            }
            $alertDetail += ". Timestamp: $timestamp"
            
            # Get top processes
            $topProcesses = Get-TopCPUProcesses
            if ($topProcesses.Count -gt 0) {
                $alertDetail += "`nTop CPU processes: "
                $processList = @()
                foreach ($proc in $topProcesses) {
                    $processList += "$($proc.Name) (PID: $($proc.Id), CPU: $($proc.CPU))"
                }
                $alertDetail += ($processList -join '; ')
            }

            Write-Log $alertDetail -Level ERROR

            # Attempt remediation if enabled
            if ($EnableRemediation) {
                Write-Log "Remediation enabled, attempting to stop top CPU process" -Level WARNING
                $remediationAction = Stop-TopCPUProcess
                Write-Log "Remediation action: $remediationAction" -Level WARNING
            }
            else {
                $remediationAction = "Remediation disabled - no action taken"
                Write-Log $remediationAction -Level INFO
            }

            $exitCode = 2
        }

        'ERROR' {
            $alertDetail = "ERROR: Unable to read CPU temperature. Timestamp: $timestamp"
            Write-Log $alertDetail -Level ERROR
            $exitCode = 3
        }
    }

    # Update alert detail and remediation fields
    Set-NinjaRMMField -FieldName "temperatureAlertDetail" -Value $alertDetail
    
    if ($remediationAction) {
        Set-NinjaRMMField -FieldName "remediationActionTaken" -Value $remediationAction
    }

    # Update history if we have a CPU temperature
    if ($null -ne $cpuTemp) {
        # Note: We can't read the existing history from NinjaRMM, so we'll just set the current reading
        # In a real deployment, you might want to maintain history in a local file
        $history = Update-TemperatureHistory -CurrentTemp $cpuTemp
        Set-NinjaRMMField -FieldName "cpuTemperatureHistory" -Value $history
    }

    Write-Log "========== Temperature Monitoring Script Completed ==========" -Level INFO
    exit $exitCode
}
catch {
    Write-Log "Unhandled exception in main execution: $($_.Exception.Message)" -Level ERROR
    Write-Log "Stack trace: $($_.ScriptStackTrace)" -Level ERROR
    exit 3
}
