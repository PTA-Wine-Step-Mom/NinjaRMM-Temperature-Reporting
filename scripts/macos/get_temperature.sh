#!/usr/bin/env bash
# =============================================================================
# Script Name  : get_temperature.sh
# Platform     : macOS
# Description  : Collects CPU and GPU temperatures and writes results to
#                NinjaRMM custom fields. Triggers alerts and remediation
#                actions based on configurable thresholds.
# Dependencies : powermetrics (macOS built-in) / osx-cpu-temp (optional) /
#                ninjarmm-cli (all platforms)
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

set -euo pipefail

# =============================================================================
# CONFIGURATION - Adjust thresholds here
# =============================================================================

CPU_WARNING_THRESHOLD=80
CPU_CRITICAL_THRESHOLD=90
GPU_WARNING_THRESHOLD=85
GPU_CRITICAL_THRESHOLD=95

# Enable/disable remediation (process killing)
ENABLE_REMEDIATION="${ENABLE_REMEDIATION:-true}"

# Debug mode
DEBUG="${DEBUG:-false}"

# System process exclusion list (case-insensitive matching)
EXCLUDED_PROCESSES="kernel_task|launchd|loginwindow|WindowServer|ninjarmm|osquery"

# Paths
NINJARMM_CLI_PATH="/opt/NinjaRMM/ninjarmm-cli"
LOG_FILE="/var/log/ninjarmm_tempmonitor.log"
MAX_LOG_SIZE=1048576  # 1MB in bytes

# =============================================================================
# LOGGING FUNCTIONS
# =============================================================================

log() {
    local level="$1"
    shift
    local message="$*"
    local timestamp
    timestamp=$(date -u +"%Y-%m-%dT%H:%M:%S")
    local log_entry="[$timestamp] [$level] $message"
    
    # Write to log file
    echo "$log_entry" >> "$LOG_FILE" || true
    
    # Write to console based on level
    if [[ "$level" == "DEBUG" && "$DEBUG" == "true" ]]; then
        echo "$log_entry" >&2
    elif [[ "$level" != "DEBUG" ]]; then
        echo "$log_entry" >&2
    fi
}

rotate_log() {
    if [[ -f "$LOG_FILE" ]]; then
        local log_size
        log_size=$(stat -f%z "$LOG_FILE" 2>/dev/null || echo 0)
        if [[ "$log_size" -gt "$MAX_LOG_SIZE" ]]; then
            mv "$LOG_FILE" "$LOG_FILE.1" 2>/dev/null || true
        fi
    fi
}

# =============================================================================
# PRIVILEGE CHECK
# =============================================================================

check_root() {
    if [[ "$EUID" -ne 0 ]]; then
        log ERROR "This script must be run as root"
        exit 3
    fi
}

# =============================================================================
# NINJARMM CLI VALIDATION
# =============================================================================

check_ninjarmm_cli() {
    if ! command -v "$NINJARMM_CLI_PATH" &> /dev/null; then
        log ERROR "ninjarmm-cli not found at: $NINJARMM_CLI_PATH"
        return 1
    fi
    return 0
}

set_ninjarmm_field() {
    local field_name="$1"
    local value="$2"
    
    log DEBUG "Setting $field_name = $value"
    
    if ! "$NINJARMM_CLI_PATH" set "$field_name" "$value"; then
        log ERROR "Failed to set NinjaRMM field: $field_name"
    fi
}

# =============================================================================
# TEMPERATURE READING FUNCTIONS
# =============================================================================

get_architecture() {
    uname -m
}

get_temperature_from_powermetrics() {
    local cpu_temp=""
    local gpu_temp=""
    
    log DEBUG "Attempting to read temperature from powermetrics"
    
    # Run powermetrics with timeout
    local output
    if ! output=$(timeout 10 sudo powermetrics --samplers smc -n 1 -i 1000 2>/dev/null); then
        log WARNING "Failed to read from powermetrics"
        echo ""
        return 1
    fi
    
    # Extract CPU die temperature
    cpu_temp=$(echo "$output" | grep -i "CPU die temperature" | head -1 | awk '{print $4}' | tr -d '°C' || echo "")
    
    # Extract GPU die temperature (mainly for Apple Silicon)
    gpu_temp=$(echo "$output" | grep -i "GPU die temperature" | head -1 | awk '{print $4}' | tr -d '°C' || echo "")
    
    log DEBUG "powermetrics - CPU: ${cpu_temp:-N/A}, GPU: ${gpu_temp:-N/A}"
    
    echo "${cpu_temp}|${gpu_temp}"
    return 0
}

get_temperature_from_osx_cpu_temp() {
    local cpu_temp=""
    
    log DEBUG "Attempting to read temperature from osx-cpu-temp"
    
    # Try common installation paths
    local osx_cpu_temp_bin=""
    if command -v /usr/local/bin/osx-cpu-temp &> /dev/null; then
        osx_cpu_temp_bin="/usr/local/bin/osx-cpu-temp"
    elif command -v /opt/homebrew/bin/osx-cpu-temp &> /dev/null; then
        osx_cpu_temp_bin="/opt/homebrew/bin/osx-cpu-temp"
    elif command -v osx-cpu-temp &> /dev/null; then
        osx_cpu_temp_bin="osx-cpu-temp"
    else
        log WARNING "osx-cpu-temp not found"
        echo ""
        return 1
    fi
    
    # Read temperature
    local output
    if output=$("$osx_cpu_temp_bin" 2>/dev/null); then
        # Output format: "61.8°C"
        cpu_temp=$(echo "$output" | grep -oE '[0-9]+\.[0-9]+' | head -1 || echo "")
        log DEBUG "osx-cpu-temp - CPU: ${cpu_temp:-N/A}"
        echo "${cpu_temp}|"
        return 0
    else
        log WARNING "Failed to read from osx-cpu-temp"
        echo ""
        return 1
    fi
}

get_system_temperature() {
    local arch
    arch=$(get_architecture)
    log INFO "System architecture: $arch"
    
    # Try powermetrics first (works on both Intel and Apple Silicon)
    local temps
    if temps=$(get_temperature_from_powermetrics); then
        echo "$temps"
        return 0
    fi
    
    # Fallback to osx-cpu-temp
    if temps=$(get_temperature_from_osx_cpu_temp); then
        echo "$temps"
        return 0
    fi
    
    log ERROR "Failed to read temperature from any source"
    echo "|"
    return 1
}

# =============================================================================
# THRESHOLD EVALUATION
# =============================================================================

get_temperature_status() {
    local cpu_temp="$1"
    local gpu_temp="$2"
    
    # If no CPU temperature, return ERROR
    if [[ -z "$cpu_temp" ]]; then
        echo "ERROR"
        return
    fi
    
    # Check CRITICAL thresholds
    if (( $(echo "$cpu_temp >= $CPU_CRITICAL_THRESHOLD" | bc -l) )); then
        echo "CRITICAL"
        return
    fi
    
    if [[ -n "$gpu_temp" ]] && (( $(echo "$gpu_temp >= $GPU_CRITICAL_THRESHOLD" | bc -l) )); then
        echo "CRITICAL"
        return
    fi
    
    # Check WARNING thresholds
    if (( $(echo "$cpu_temp >= $CPU_WARNING_THRESHOLD" | bc -l) )); then
        echo "WARNING"
        return
    fi
    
    if [[ -n "$gpu_temp" ]] && (( $(echo "$gpu_temp >= $GPU_WARNING_THRESHOLD" | bc -l) )); then
        echo "WARNING"
        return
    fi
    
    echo "OK"
}

# =============================================================================
# PROCESS MANAGEMENT
# =============================================================================

get_top_cpu_processes() {
    local count="${1:-3}"
    
    # Get top CPU processes using ps, excluding header
    ps -Arco pid,comm,%cpu | sort -rn -k3 | head -n "$count" | tail -n +2
}

stop_top_cpu_process() {
    local top_processes
    top_processes=$(get_top_cpu_processes 3)
    
    if [[ -z "$top_processes" ]]; then
        echo "No processes found"
        return
    fi
    
    while IFS= read -r line; do
        local pid
        local comm
        local cpu
        
        pid=$(echo "$line" | awk '{print $1}')
        comm=$(echo "$line" | awk '{print $2}')
        cpu=$(echo "$line" | awk '{print $3}')
        
        # Check if process is in exclusion list (case-insensitive)
        if echo "$comm" | grep -iE "$EXCLUDED_PROCESSES" &> /dev/null; then
            log INFO "Process $comm (PID: $pid) is in exclusion list, skipping"
            continue
        fi
        
        # Kill the process
        log WARNING "Terminating process: $comm (PID: $pid, CPU: $cpu%)"
        if kill -9 "$pid" 2>/dev/null; then
            echo "Killed process: $comm (PID: $pid, CPU: $cpu%)"
            return
        else
            log ERROR "Failed to kill process: $comm (PID: $pid)"
        fi
    done <<< "$top_processes"
    
    echo "All top CPU processes are system-critical (excluded from termination)"
}

# =============================================================================
# HISTORY MANAGEMENT
# =============================================================================

update_temperature_history() {
    local current_temp="$1"
    local existing_history="${2:-}"
    
    local history_array=()
    
    # Parse existing history
    if [[ -n "$existing_history" && "$existing_history" != "N/A" ]]; then
        IFS=',' read -ra history_array <<< "$existing_history"
    fi
    
    # Add current reading
    history_array+=("$current_temp")
    
    # Keep only last 5
    if [[ ${#history_array[@]} -gt 5 ]]; then
        history_array=("${history_array[@]: -5}")
    fi
    
    # Join with commas
    local result
    result=$(IFS=','; echo "${history_array[*]}")
    echo "$result"
}

# =============================================================================
# MAIN EXECUTION
# =============================================================================

main() {
    log INFO "========== Temperature Monitoring Script Started =========="
    
    # Rotate log if needed
    rotate_log
    
    # Check for root privileges
    check_root
    
    # Validate NinjaRMM CLI
    if ! check_ninjarmm_cli; then
        log ERROR "Cannot proceed without ninjarmm-cli"
        exit 3
    fi
    
    # Get temperature readings
    log INFO "Reading system temperatures..."
    local temps
    temps=$(get_system_temperature)
    
    local cpu_temp
    local gpu_temp
    cpu_temp=$(echo "$temps" | cut -d'|' -f1)
    gpu_temp=$(echo "$temps" | cut -d'|' -f2)
    
    # Log readings
    if [[ -n "$cpu_temp" ]]; then
        log INFO "CPU Temperature: ${cpu_temp}°C"
    else
        log ERROR "CPU Temperature: Unable to read"
    fi
    
    if [[ -n "$gpu_temp" ]]; then
        log INFO "GPU Temperature: ${gpu_temp}°C"
    else
        log INFO "GPU Temperature: Not available or unable to read"
    fi
    
    # Determine status
    local status
    status=$(get_temperature_status "$cpu_temp" "$gpu_temp")
    log INFO "Temperature Status: $status"
    
    # Get timestamp
    local timestamp
    timestamp=$(date -u +"%Y-%m-%dT%H:%M:%S")
    
    # Write base fields to NinjaRMM
    if [[ -n "$cpu_temp" ]]; then
        set_ninjarmm_field "cpuTemperatureCelsius" "$cpu_temp"
    else
        set_ninjarmm_field "cpuTemperatureCelsius" "N/A"
    fi
    
    if [[ -n "$gpu_temp" ]]; then
        set_ninjarmm_field "gpuTemperatureCelsius" "$gpu_temp"
    else
        set_ninjarmm_field "gpuTemperatureCelsius" "N/A"
    fi
    
    set_ninjarmm_field "temperatureStatus" "$status"
    set_ninjarmm_field "lastTemperatureCheck" "$timestamp"
    
    # Handle different status levels
    local exit_code=0
    local alert_detail=""
    local remediation_action=""
    
    case "$status" in
        OK)
            alert_detail="OK: CPU at ${cpu_temp}°C"
            if [[ -n "$gpu_temp" ]]; then
                alert_detail="$alert_detail, GPU at ${gpu_temp}°C"
            fi
            alert_detail="$alert_detail. Timestamp: $timestamp"
            exit_code=0
            ;;
            
        WARNING)
            alert_detail="WARNING: CPU at ${cpu_temp}°C (threshold: ${CPU_WARNING_THRESHOLD}°C)"
            if [[ -n "$gpu_temp" ]]; then
                alert_detail="$alert_detail, GPU at ${gpu_temp}°C (threshold: ${GPU_WARNING_THRESHOLD}°C)"
            fi
            alert_detail="$alert_detail. Timestamp: $timestamp"
            log WARNING "$alert_detail"
            exit_code=1
            ;;
            
        CRITICAL)
            alert_detail="CRITICAL: CPU at ${cpu_temp}°C (threshold: ${CPU_CRITICAL_THRESHOLD}°C)"
            if [[ -n "$gpu_temp" ]]; then
                alert_detail="$alert_detail, GPU at ${gpu_temp}°C (threshold: ${GPU_CRITICAL_THRESHOLD}°C)"
            fi
            alert_detail="$alert_detail. Timestamp: $timestamp"
            
            # Get top processes
            local top_processes
            top_processes=$(get_top_cpu_processes 3)
            if [[ -n "$top_processes" ]]; then
                alert_detail="$alert_detail"$'\n'"Top CPU processes: "
                local process_list=""
                while IFS= read -r line; do
                    local pid comm cpu
                    pid=$(echo "$line" | awk '{print $1}')
                    comm=$(echo "$line" | awk '{print $2}')
                    cpu=$(echo "$line" | awk '{print $3}')
                    if [[ -n "$process_list" ]]; then
                        process_list="$process_list; "
                    fi
                    process_list="$process_list$comm (PID: $pid, CPU: $cpu%)"
                done <<< "$top_processes"
                alert_detail="$alert_detail$process_list"
            fi
            
            log ERROR "$alert_detail"
            
            # Attempt remediation if enabled
            if [[ "$ENABLE_REMEDIATION" == "true" ]]; then
                log WARNING "Remediation enabled, attempting to stop top CPU process"
                remediation_action=$(stop_top_cpu_process)
                log WARNING "Remediation action: $remediation_action"
            else
                remediation_action="Remediation disabled - no action taken"
                log INFO "$remediation_action"
            fi
            
            exit_code=2
            ;;
            
        ERROR)
            alert_detail="ERROR: Unable to read CPU temperature. Timestamp: $timestamp"
            log ERROR "$alert_detail"
            exit_code=3
            ;;
    esac
    
    # Update alert detail and remediation fields
    set_ninjarmm_field "temperatureAlertDetail" "$alert_detail"
    
    if [[ -n "$remediation_action" ]]; then
        set_ninjarmm_field "remediationActionTaken" "$remediation_action"
    fi
    
    # Update history if we have a CPU temperature
    if [[ -n "$cpu_temp" ]]; then
        local history
        history=$(update_temperature_history "$cpu_temp" "")
        set_ninjarmm_field "cpuTemperatureHistory" "$history"
    fi
    
    log INFO "========== Temperature Monitoring Script Completed =========="
    exit "$exit_code"
}

# Run main function
main "$@"
