#!/usr/bin/env bash
# =============================================================================
# Script Name  : get_temperature.sh
# Platform     : Linux
# Description  : Collects CPU and GPU temperatures and writes results to
#                NinjaRMM custom fields. Triggers alerts and remediation
#                actions based on configurable thresholds.
# Dependencies : lm-sensors / nvidia-smi (optional) / ninjarmm-cli (all platforms)
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
EXCLUDED_PROCESSES="systemd|init|kthreadd|kworker|ksoftirqd|ninjarmm|sshd|cron"

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
        log_size=$(stat -c%s "$LOG_FILE" 2>/dev/null || echo 0)
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

get_temperature_from_sensors() {
    local cpu_temp=""
    local gpu_temp=""
    
    log DEBUG "Attempting to read temperature from lm-sensors"
    
    if ! command -v sensors &> /dev/null; then
        log WARNING "sensors command not found"
        echo "|"
        return 1
    fi
    
    # Try JSON output first
    local output
    if output=$(sensors -j 2>/dev/null); then
        log DEBUG "Parsing sensors JSON output"
        # Parse JSON to find highest CPU/core temp
        # This is simplified - in production you might use jq
        local max_temp=""
        while IFS= read -r line; do
            if [[ "$line" =~ \"temp[0-9]+_input\":[[:space:]]*([0-9]+\.[0-9]+) ]]; then
                local temp="${BASH_REMATCH[1]}"
                if [[ -z "$max_temp" ]] || (( $(echo "$temp > $max_temp" | bc -l) )); then
                    max_temp="$temp"
                fi
            fi
        done <<< "$output"
        cpu_temp="$max_temp"
    else
        # Fallback to plain text parsing
        log DEBUG "Parsing sensors plain text output"
        output=$(sensors 2>/dev/null || echo "")
        
        # Extract temperatures (look for lines with °C)
        local max_temp=""
        while IFS= read -r line; do
            if [[ "$line" =~ \+([0-9]+\.[0-9]+)°C ]]; then
                local temp="${BASH_REMATCH[1]}"
                if [[ -z "$max_temp" ]] || (( $(echo "$temp > $max_temp" | bc -l) )); then
                    max_temp="$temp"
                fi
            fi
        done <<< "$output"
        cpu_temp="$max_temp"
    fi
    
    log DEBUG "lm-sensors - CPU: ${cpu_temp:-N/A}"
    echo "${cpu_temp}|${gpu_temp}"
    return 0
}

get_temperature_from_thermal_zone() {
    local cpu_temp=""
    
    log DEBUG "Attempting to read temperature from thermal zones"
    
    local max_temp=""
    for zone in /sys/class/thermal/thermal_zone*/temp; do
        if [[ -f "$zone" ]]; then
            local temp_millidegrees
            temp_millidegrees=$(cat "$zone")
            # Convert millidegrees to degrees
            local temp
            temp=$(echo "scale=2; $temp_millidegrees / 1000" | bc)
            
            log DEBUG "Thermal zone $(basename "$(dirname "$zone")"): ${temp}°C"
            
            if [[ -z "$max_temp" ]] || (( $(echo "$temp > $max_temp" | bc -l) )); then
                max_temp="$temp"
            fi
        fi
    done
    
    cpu_temp="$max_temp"
    log DEBUG "Thermal zones - CPU: ${cpu_temp:-N/A}"
    echo "${cpu_temp}|"
    return 0
}

get_gpu_temperature_nvidia() {
    local gpu_temp=""
    
    if command -v nvidia-smi &> /dev/null; then
        log DEBUG "Attempting to read NVIDIA GPU temperature"
        gpu_temp=$(nvidia-smi --query-gpu=temperature.gpu --format=csv,noheader,nounits 2>/dev/null | head -1 || echo "")
        log DEBUG "NVIDIA GPU: ${gpu_temp:-N/A}"
    fi
    
    echo "$gpu_temp"
}

get_gpu_temperature_amd() {
    local gpu_temp=""
    
    log DEBUG "Attempting to read AMD GPU temperature"
    
    # Look for AMD GPU hwmon
    for hwmon in /sys/class/drm/card*/device/hwmon/hwmon*/temp1_input; do
        if [[ -f "$hwmon" ]]; then
            local temp_millidegrees
            temp_millidegrees=$(cat "$hwmon")
            # Convert millidegrees to degrees
            gpu_temp=$(echo "scale=2; $temp_millidegrees / 1000" | bc)
            log DEBUG "AMD GPU: ${gpu_temp}°C"
            break
        fi
    done
    
    echo "$gpu_temp"
}

get_system_temperature() {
    local cpu_temp=""
    local gpu_temp=""
    
    # Try lm-sensors first
    local temps
    if temps=$(get_temperature_from_sensors); then
        cpu_temp=$(echo "$temps" | cut -d'|' -f1)
        gpu_temp=$(echo "$temps" | cut -d'|' -f2)
    fi
    
    # If no CPU temp, try thermal zones
    if [[ -z "$cpu_temp" ]]; then
        log WARNING "lm-sensors did not return CPU temperature, trying thermal zones"
        if temps=$(get_temperature_from_thermal_zone); then
            cpu_temp=$(echo "$temps" | cut -d'|' -f1)
        fi
    fi
    
    # Try to get GPU temperature if not already found
    if [[ -z "$gpu_temp" ]]; then
        # Try NVIDIA
        gpu_temp=$(get_gpu_temperature_nvidia)
        
        # Try AMD if NVIDIA didn't work
        if [[ -z "$gpu_temp" ]]; then
            gpu_temp=$(get_gpu_temperature_amd)
        fi
    fi
    
    echo "${cpu_temp}|${gpu_temp}"
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
    
    # Get top CPU processes using ps
    ps aux --sort=-%cpu | head -n $((count + 1)) | tail -n +2 | awk '{print $2, $11, $3}'
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
        
        # Extract just the process name from the full command
        comm=$(basename "$comm")
        
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
                    comm=$(basename "$(echo "$line" | awk '{print $2}')")
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
