#!/usr/bin/env bash
# =============================================================================
# Script Name  : install_dependencies.sh
# Platform     : macOS
# Description  : Installs temperature monitoring dependencies (osx-cpu-temp)
# Dependencies : Homebrew (optional)
# Author       : NinjaRMM Temperature Monitoring Team
# Version      : 1.0.0
# Last Updated : 2026-02-19
# =============================================================================

set -euo pipefail

# =============================================================================
# FUNCTIONS
# =============================================================================

log_message() {
    local level="$1"
    shift
    local message="$*"
    local timestamp
    timestamp=$(date -u +"%Y-%m-%dT%H:%M:%S")
    echo "[$timestamp] [$level] $message"
}

check_root() {
    if [[ "$EUID" -ne 0 ]]; then
        log_message ERROR "This script must be run as root"
        exit 1
    fi
}

check_powermetrics() {
    if command -v powermetrics &> /dev/null; then
        log_message INFO "powermetrics is available (built-in macOS tool)"
        return 0
    else
        log_message WARNING "powermetrics not found (unexpected on macOS)"
        return 1
    fi
}

check_homebrew() {
    if command -v brew &> /dev/null; then
        log_message INFO "Homebrew is installed"
        return 0
    else
        log_message WARNING "Homebrew is not installed"
        return 1
    fi
}

check_osx_cpu_temp() {
    if command -v /usr/local/bin/osx-cpu-temp &> /dev/null || \
       command -v /opt/homebrew/bin/osx-cpu-temp &> /dev/null || \
       command -v osx-cpu-temp &> /dev/null; then
        log_message INFO "osx-cpu-temp is already installed"
        return 0
    else
        log_message INFO "osx-cpu-temp is not installed"
        return 1
    fi
}

install_osx_cpu_temp() {
    log_message INFO "Attempting to install osx-cpu-temp via Homebrew..."
    
    if ! check_homebrew; then
        log_message WARNING "Homebrew is not installed. Cannot install osx-cpu-temp automatically."
        log_message INFO "To install Homebrew, run: /bin/bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\""
        return 1
    fi
    
    # Install osx-cpu-temp
    if sudo -u "$(stat -f%Su /dev/console)" brew install osx-cpu-temp; then
        log_message INFO "osx-cpu-temp installed successfully"
        return 0
    else
        log_message ERROR "Failed to install osx-cpu-temp"
        return 1
    fi
}

# =============================================================================
# MAIN EXECUTION
# =============================================================================

main() {
    log_message INFO "Starting macOS dependency installation"
    
    check_root
    
    # Check for powermetrics (primary method)
    check_powermetrics
    
    # Check for osx-cpu-temp (fallback method)
    if ! check_osx_cpu_temp; then
        log_message INFO "osx-cpu-temp not found, attempting installation..."
        if ! install_osx_cpu_temp; then
            log_message WARNING "Could not install osx-cpu-temp. The script will rely on powermetrics only."
        fi
    fi
    
    log_message INFO "Dependency check completed"
    log_message INFO "Note: The temperature monitoring script will work with powermetrics (built-in)"
    log_message INFO "osx-cpu-temp is an optional fallback"
    
    exit 0
}

main "$@"
