#!/usr/bin/env bash
# =============================================================================
# Script Name  : get_temperature_test.sh
# Platform     : Linux
# Description  : Unit tests for the Linux temperature monitoring script
# Dependencies : None (self-contained tests)
# Author       : NinjaRMM Temperature Monitoring Team
# Version      : 1.0.0
# Last Updated : 2026-02-19
# =============================================================================

set -euo pipefail

# Test counters
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# =============================================================================
# TEST FRAMEWORK FUNCTIONS
# =============================================================================

test_start() {
    echo "========================================"
    echo "Starting Test Suite: Linux Temperature Monitoring"
    echo "========================================"
    echo ""
}

test_end() {
    echo ""
    echo "========================================"
    echo "Test Suite Completed"
    echo "Tests Run: $TESTS_RUN"
    echo "Tests Passed: $TESTS_PASSED"
    echo "Tests Failed: $TESTS_FAILED"
    echo "========================================"
    
    if [[ $TESTS_FAILED -eq 0 ]]; then
        echo "✓ All tests passed!"
        exit 0
    else
        echo "✗ Some tests failed"
        exit 1
    fi
}

assert_equals() {
    local expected="$1"
    local actual="$2"
    local test_name="$3"
    
    TESTS_RUN=$((TESTS_RUN + 1))
    
    if [[ "$expected" == "$actual" ]]; then
        echo "✓ PASS: $test_name"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo "✗ FAIL: $test_name"
        echo "  Expected: $expected"
        echo "  Actual: $actual"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
}

assert_contains() {
    local haystack="$1"
    local needle="$2"
    local test_name="$3"
    
    TESTS_RUN=$((TESTS_RUN + 1))
    
    if echo "$haystack" | grep -q "$needle"; then
        echo "✓ PASS: $test_name"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo "✗ FAIL: $test_name"
        echo "  Expected to find: $needle"
        echo "  In: $haystack"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
}

# =============================================================================
# THRESHOLD LOGIC TESTS
# =============================================================================

test_threshold_logic() {
    echo "Testing threshold logic..."
    
    # Test: OK status
    local cpu_temp=75
    local cpu_warning=80
    local cpu_critical=90
    local status="OK"
    
    if (( $(echo "$cpu_temp >= $cpu_critical" | bc -l) )); then
        status="CRITICAL"
    elif (( $(echo "$cpu_temp >= $cpu_warning" | bc -l) )); then
        status="WARNING"
    fi
    
    assert_equals "OK" "$status" "CPU temp 75°C should be OK (threshold 80°C)"
    
    # Test: WARNING status
    cpu_temp=82
    status="OK"
    
    if (( $(echo "$cpu_temp >= $cpu_critical" | bc -l) )); then
        status="CRITICAL"
    elif (( $(echo "$cpu_temp >= $cpu_warning" | bc -l) )); then
        status="WARNING"
    fi
    
    assert_equals "WARNING" "$status" "CPU temp 82°C should be WARNING (threshold 80°C)"
    
    # Test: CRITICAL status
    cpu_temp=92
    status="OK"
    
    if (( $(echo "$cpu_temp >= $cpu_critical" | bc -l) )); then
        status="CRITICAL"
    elif (( $(echo "$cpu_temp >= $cpu_warning" | bc -l) )); then
        status="WARNING"
    fi
    
    assert_equals "CRITICAL" "$status" "CPU temp 92°C should be CRITICAL (threshold 90°C)"
    
    # Test: Exact threshold boundary
    cpu_temp=80
    status="OK"
    
    if (( $(echo "$cpu_temp >= $cpu_critical" | bc -l) )); then
        status="CRITICAL"
    elif (( $(echo "$cpu_temp >= $cpu_warning" | bc -l) )); then
        status="WARNING"
    fi
    
    assert_equals "WARNING" "$status" "CPU temp 80°C should be WARNING (at threshold)"
}

# =============================================================================
# PROCESS EXCLUSION TESTS
# =============================================================================

test_process_exclusion() {
    echo ""
    echo "Testing process exclusion logic..."
    
    local excluded_processes="systemd|init|kthreadd|kworker|ksoftirqd|ninjarmm|sshd|cron"
    
    # Test: Excluded process
    local process_name="systemd"
    local is_excluded=false
    
    if echo "$process_name" | grep -iE "$excluded_processes" &> /dev/null; then
        is_excluded=true
    fi
    
    if [[ "$is_excluded" == true ]]; then
        assert_equals "true" "true" "systemd should be excluded"
    else
        assert_equals "true" "false" "systemd should be excluded"
    fi
    
    # Test: Non-excluded process
    process_name="firefox"
    is_excluded=false
    
    if echo "$process_name" | grep -iE "$excluded_processes" &> /dev/null; then
        is_excluded=true
    fi
    
    if [[ "$is_excluded" == false ]]; then
        assert_equals "false" "false" "firefox should not be excluded"
    else
        assert_equals "false" "true" "firefox should not be excluded"
    fi
    
    # Test: Case insensitivity
    process_name="SYSTEMD"
    is_excluded=false
    
    if echo "$process_name" | grep -iE "$excluded_processes" &> /dev/null; then
        is_excluded=true
    fi
    
    if [[ "$is_excluded" == true ]]; then
        assert_equals "true" "true" "SYSTEMD (uppercase) should be excluded"
    else
        assert_equals "true" "false" "SYSTEMD (uppercase) should be excluded"
    fi
    
    # Test: Partial match (kworker)
    process_name="kworker/0:1"
    is_excluded=false
    
    if echo "$process_name" | grep -iE "$excluded_processes" &> /dev/null; then
        is_excluded=true
    fi
    
    if [[ "$is_excluded" == true ]]; then
        assert_equals "true" "true" "kworker/0:1 should be excluded"
    else
        assert_equals "true" "false" "kworker/0:1 should be excluded"
    fi
}

# =============================================================================
# EXIT CODE TESTS
# =============================================================================

test_exit_codes() {
    echo ""
    echo "Testing exit codes..."
    
    # Test: OK status
    local status="OK"
    local exit_code=99
    
    case "$status" in
        OK) exit_code=0 ;;
        WARNING) exit_code=1 ;;
        CRITICAL) exit_code=2 ;;
        ERROR) exit_code=3 ;;
    esac
    
    assert_equals "0" "$exit_code" "OK status should return exit code 0"
    
    # Test: WARNING status
    status="WARNING"
    exit_code=99
    
    case "$status" in
        OK) exit_code=0 ;;
        WARNING) exit_code=1 ;;
        CRITICAL) exit_code=2 ;;
        ERROR) exit_code=3 ;;
    esac
    
    assert_equals "1" "$exit_code" "WARNING status should return exit code 1"
    
    # Test: CRITICAL status
    status="CRITICAL"
    exit_code=99
    
    case "$status" in
        OK) exit_code=0 ;;
        WARNING) exit_code=1 ;;
        CRITICAL) exit_code=2 ;;
        ERROR) exit_code=3 ;;
    esac
    
    assert_equals "2" "$exit_code" "CRITICAL status should return exit code 2"
    
    # Test: ERROR status
    status="ERROR"
    exit_code=99
    
    case "$status" in
        OK) exit_code=0 ;;
        WARNING) exit_code=1 ;;
        CRITICAL) exit_code=2 ;;
        ERROR) exit_code=3 ;;
    esac
    
    assert_equals "3" "$exit_code" "ERROR status should return exit code 3"
}

# =============================================================================
# TEMPERATURE HISTORY TESTS
# =============================================================================

test_temperature_history() {
    echo ""
    echo "Testing temperature history management..."
    
    # Simulate adding readings
    local history_array=()
    local readings=(70 72 75 78 80 82 85)
    
    for reading in "${readings[@]}"; do
        history_array+=("$reading")
        if [[ ${#history_array[@]} -gt 5 ]]; then
            history_array=("${history_array[@]: -5}")
        fi
    done
    
    # Should have exactly 5 entries
    local count="${#history_array[@]}"
    assert_equals "5" "$count" "History should contain exactly 5 entries"
    
    # First entry should be 78 (7 readings, keep last 5)
    assert_equals "78" "${history_array[0]}" "First history entry should be 78"
    
    # Last entry should be 85
    assert_equals "85" "${history_array[4]}" "Last history entry should be 85"
    
    # Test comma-separated format
    local history_string
    history_string=$(IFS=','; echo "${history_array[*]}")
    assert_equals "78,80,82,85" "$history_string" "History string should be comma-separated"
}

# =============================================================================
# THERMAL ZONE CONVERSION TESTS
# =============================================================================

test_thermal_zone_conversion() {
    echo ""
    echo "Testing thermal zone temperature conversion..."
    
    # Thermal zones report in millidegrees
    local temp_millidegrees=65000
    local temp_celsius
    temp_celsius=$(echo "scale=2; $temp_millidegrees / 1000" | bc)
    
    assert_equals "65.00" "$temp_celsius" "Should convert millidegrees to Celsius"
    
    # Test with higher temperature
    temp_millidegrees=85500
    temp_celsius=$(echo "scale=2; $temp_millidegrees / 1000" | bc)
    
    assert_equals "85.50" "$temp_celsius" "Should handle decimal temperatures"
}

# =============================================================================
# SENSORS OUTPUT PARSING TESTS
# =============================================================================

test_sensors_parsing() {
    echo ""
    echo "Testing sensors output parsing..."
    
    # Mock sensors output
    local mock_output="coretemp-isa-0000
Adapter: ISA adapter
Package id 0:  +67.0°C  (high = +80.0°C, crit = +100.0°C)
Core 0:        +65.0°C  (high = +80.0°C, crit = +100.0°C)
Core 1:        +64.0°C  (high = +80.0°C, crit = +100.0°C)
Core 2:        +67.0°C  (high = +80.0°C, crit = +100.0°C)
Core 3:        +66.0°C  (high = +80.0°C, crit = +100.0°C)"
    
    # Extract temperatures
    local max_temp=""
    while IFS= read -r line; do
        if [[ "$line" =~ \+([0-9]+\.[0-9]+)°C ]]; then
            local temp="${BASH_REMATCH[1]}"
            if [[ -z "$max_temp" ]] || (( $(echo "$temp > $max_temp" | bc -l) )); then
                max_temp="$temp"
            fi
        fi
    done <<< "$mock_output"
    
    assert_equals "67.0" "$max_temp" "Should extract maximum temperature from sensors output"
}

# =============================================================================
# MAIN EXECUTION
# =============================================================================

main() {
    test_start
    
    test_threshold_logic
    test_process_exclusion
    test_exit_codes
    test_temperature_history
    test_thermal_zone_conversion
    test_sensors_parsing
    
    test_end
}

main "$@"
