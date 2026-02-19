#!/usr/bin/env bash
# =============================================================================
# Script Name  : install_dependencies.sh
# Platform     : Linux
# Description  : Installs lm-sensors for temperature monitoring
# Dependencies : apt or yum/dnf package manager
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

detect_distro() {
    if [[ -f /etc/os-release ]]; then
        . /etc/os-release
        echo "$ID"
    else
        echo "unknown"
    fi
}

detect_package_manager() {
    local distro="$1"
    
    case "$distro" in
        ubuntu|debian|pop|linuxmint)
            echo "apt"
            ;;
        rhel|centos|fedora|rocky|almalinux|amzn)
            if command -v dnf &> /dev/null; then
                echo "dnf"
            else
                echo "yum"
            fi
            ;;
        *)
            if command -v apt-get &> /dev/null; then
                echo "apt"
            elif command -v dnf &> /dev/null; then
                echo "dnf"
            elif command -v yum &> /dev/null; then
                echo "yum"
            else
                echo "unknown"
            fi
            ;;
    esac
}

check_lm_sensors() {
    if command -v sensors &> /dev/null; then
        log_message INFO "lm-sensors is already installed"
        return 0
    else
        log_message INFO "lm-sensors is not installed"
        return 1
    fi
}

install_lm_sensors_apt() {
    log_message INFO "Installing lm-sensors using apt..."
    
    # Update package list
    apt-get update -qq
    
    # Install lm-sensors
    DEBIAN_FRONTEND=noninteractive apt-get install -y lm-sensors
    
    log_message INFO "lm-sensors installed successfully"
}

install_lm_sensors_yum() {
    log_message INFO "Installing lm-sensors using yum..."
    
    # Install lm_sensors (note: package name is lm_sensors on RHEL/CentOS)
    yum install -y lm_sensors
    
    log_message INFO "lm-sensors installed successfully"
}

install_lm_sensors_dnf() {
    log_message INFO "Installing lm-sensors using dnf..."
    
    # Install lm_sensors
    dnf install -y lm_sensors
    
    log_message INFO "lm-sensors installed successfully"
}

configure_lm_sensors() {
    log_message INFO "Configuring lm-sensors..."
    
    # Run sensors-detect with all 'yes' responses
    # This is safe and will detect available sensors
    if command -v sensors-detect &> /dev/null; then
        yes "" | sensors-detect --auto || true
        log_message INFO "lm-sensors configuration completed"
    else
        log_message WARNING "sensors-detect not found, skipping configuration"
    fi
}

# =============================================================================
# MAIN EXECUTION
# =============================================================================

main() {
    log_message INFO "Starting Linux dependency installation"
    
    check_root
    
    # Check if already installed
    if check_lm_sensors; then
        log_message INFO "Dependencies already installed"
        exit 0
    fi
    
    # Detect distribution and package manager
    local distro
    distro=$(detect_distro)
    log_message INFO "Detected distribution: $distro"
    
    local pkg_manager
    pkg_manager=$(detect_package_manager "$distro")
    log_message INFO "Package manager: $pkg_manager"
    
    # Install based on package manager
    case "$pkg_manager" in
        apt)
            install_lm_sensors_apt
            ;;
        yum)
            install_lm_sensors_yum
            ;;
        dnf)
            install_lm_sensors_dnf
            ;;
        *)
            log_message ERROR "Unsupported package manager: $pkg_manager"
            log_message ERROR "Please install lm-sensors manually"
            exit 1
            ;;
    esac
    
    # Configure sensors
    configure_lm_sensors
    
    # Verify installation
    if check_lm_sensors; then
        log_message INFO "Installation completed successfully"
        exit 0
    else
        log_message ERROR "Installation completed but sensors command not found"
        exit 1
    fi
}

main "$@"
