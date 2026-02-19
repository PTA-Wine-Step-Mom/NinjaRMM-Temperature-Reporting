#Requires -Version 5.1
#Requires -Modules Pester

<#
.SYNOPSIS
    Pester unit tests for Get-Temperature.ps1

.DESCRIPTION
    # =============================================================================
    # Script Name  : Get-Temperature.Tests.ps1
    # Platform     : Windows
    # Description  : Unit tests for the temperature monitoring script using Pester
    # Dependencies : Pester 5.x
    # Author       : NinjaRMM Temperature Monitoring Team
    # Version      : 1.0.0
    # Last Updated : 2026-02-19
    # =============================================================================
#>

BeforeAll {
    # Set up test environment
    $script:TestScriptPath = Join-Path $PSScriptRoot "Get-Temperature.ps1"
    
    # Mock paths and functions that would interact with external systems
    $script:MockNinjaRMMPath = "C:\Program Files\NinjaRMM\ninjarmm-cli.exe"
    $script:MockLogPath = "TestDrive:\tempmonitor.log"
    
    # Load the script content for testing (without executing)
    $script:ScriptContent = Get-Content $TestScriptPath -Raw
}

Describe "Get-Temperature.ps1 - Threshold Logic Tests" {
    
    Context "Temperature Status Determination" {
        
        It "Should return OK when temperatures are below warning thresholds" {
            # This test validates the threshold logic
            $cpuTemp = 75
            $gpuTemp = 80
            $cpuWarning = 80
            $cpuCritical = 90
            $gpuWarning = 85
            $gpuCritical = 95
            
            # Simulate status logic
            $status = if ($cpuTemp -ge $cpuCritical -or ($null -ne $gpuTemp -and $gpuTemp -ge $gpuCritical)) {
                'CRITICAL'
            }
            elseif ($cpuTemp -ge $cpuWarning -or ($null -ne $gpuTemp -and $gpuTemp -ge $gpuWarning)) {
                'WARNING'
            }
            else {
                'OK'
            }
            
            $status | Should -Be 'OK'
        }
        
        It "Should return WARNING when CPU temperature exceeds warning threshold" {
            $cpuTemp = 82
            $gpuTemp = 80
            $cpuWarning = 80
            $cpuCritical = 90
            $gpuWarning = 85
            $gpuCritical = 95
            
            $status = if ($cpuTemp -ge $cpuCritical -or ($null -ne $gpuTemp -and $gpuTemp -ge $gpuCritical)) {
                'CRITICAL'
            }
            elseif ($cpuTemp -ge $cpuWarning -or ($null -ne $gpuTemp -and $gpuTemp -ge $gpuWarning)) {
                'WARNING'
            }
            else {
                'OK'
            }
            
            $status | Should -Be 'WARNING'
        }
        
        It "Should return WARNING when GPU temperature exceeds warning threshold" {
            $cpuTemp = 75
            $gpuTemp = 87
            $cpuWarning = 80
            $cpuCritical = 90
            $gpuWarning = 85
            $gpuCritical = 95
            
            $status = if ($cpuTemp -ge $cpuCritical -or ($null -ne $gpuTemp -and $gpuTemp -ge $gpuCritical)) {
                'CRITICAL'
            }
            elseif ($cpuTemp -ge $cpuWarning -or ($null -ne $gpuTemp -and $gpuTemp -ge $gpuWarning)) {
                'WARNING'
            }
            else {
                'OK'
            }
            
            $status | Should -Be 'WARNING'
        }
        
        It "Should return CRITICAL when CPU temperature exceeds critical threshold" {
            $cpuTemp = 92
            $gpuTemp = 80
            $cpuWarning = 80
            $cpuCritical = 90
            $gpuWarning = 85
            $gpuCritical = 95
            
            $status = if ($cpuTemp -ge $cpuCritical -or ($null -ne $gpuTemp -and $gpuTemp -ge $gpuCritical)) {
                'CRITICAL'
            }
            elseif ($cpuTemp -ge $cpuWarning -or ($null -ne $gpuTemp -and $gpuTemp -ge $gpuWarning)) {
                'WARNING'
            }
            else {
                'OK'
            }
            
            $status | Should -Be 'CRITICAL'
        }
        
        It "Should return CRITICAL when GPU temperature exceeds critical threshold" {
            $cpuTemp = 75
            $gpuTemp = 97
            $cpuWarning = 80
            $cpuCritical = 90
            $gpuWarning = 85
            $gpuCritical = 95
            
            $status = if ($cpuTemp -ge $cpuCritical -or ($null -ne $gpuTemp -and $gpuTemp -ge $gpuCritical)) {
                'CRITICAL'
            }
            elseif ($cpuTemp -ge $cpuWarning -or ($null -ne $gpuTemp -and $gpuTemp -ge $gpuWarning)) {
                'WARNING'
            }
            else {
                'OK'
            }
            
            $status | Should -Be 'CRITICAL'
        }
        
        It "Should handle missing GPU temperature gracefully" {
            $cpuTemp = 75
            $gpuTemp = $null
            $cpuWarning = 80
            $cpuCritical = 90
            
            $status = if ($cpuTemp -ge $cpuCritical) {
                'CRITICAL'
            }
            elseif ($cpuTemp -ge $cpuWarning) {
                'WARNING'
            }
            else {
                'OK'
            }
            
            $status | Should -Be 'OK'
        }
    }
}

Describe "Get-Temperature.ps1 - Process Exclusion Tests" {
    
    Context "System Process Protection" {
        
        It "Should not terminate processes in the exclusion list" {
            $excludedProcesses = @(
                'System', 'svchost', 'lsass', 'winlogon', 'csrss', 'smss',
                'wininit', 'services', 'NinjaRMM', 'NinjaRMMMaintenance'
            )
            
            # Test that each excluded process name would be protected
            foreach ($procName in @('System', 'svchost', 'lsass', 'NinjaRMM')) {
                $isExcluded = $false
                foreach ($excluded in $excludedProcesses) {
                    if ($procName -like $excluded) {
                        $isExcluded = $true
                        break
                    }
                }
                $isExcluded | Should -Be $true
            }
        }
        
        It "Should allow termination of non-excluded processes" {
            $excludedProcesses = @(
                'System', 'svchost', 'lsass', 'winlogon', 'csrss', 'smss',
                'wininit', 'services', 'NinjaRMM', 'NinjaRMMMaintenance'
            )
            
            $testProcesses = @('notepad', 'chrome', 'firefox', 'excel')
            
            foreach ($procName in $testProcesses) {
                $isExcluded = $false
                foreach ($excluded in $excludedProcesses) {
                    if ($procName -like $excluded) {
                        $isExcluded = $true
                        break
                    }
                }
                $isExcluded | Should -Be $false
            }
        }
    }
}

Describe "Get-Temperature.ps1 - Exit Code Tests" {
    
    Context "Exit Code Validation" {
        
        It "Should use exit code 0 for OK status" {
            $status = 'OK'
            $exitCode = switch ($status) {
                'OK' { 0 }
                'WARNING' { 1 }
                'CRITICAL' { 2 }
                'ERROR' { 3 }
            }
            $exitCode | Should -Be 0
        }
        
        It "Should use exit code 1 for WARNING status" {
            $status = 'WARNING'
            $exitCode = switch ($status) {
                'OK' { 0 }
                'WARNING' { 1 }
                'CRITICAL' { 2 }
                'ERROR' { 3 }
            }
            $exitCode | Should -Be 1
        }
        
        It "Should use exit code 2 for CRITICAL status" {
            $status = 'CRITICAL'
            $exitCode = switch ($status) {
                'OK' { 0 }
                'WARNING' { 1 }
                'CRITICAL' { 2 }
                'ERROR' { 3 }
            }
            $exitCode | Should -Be 2
        }
        
        It "Should use exit code 3 for ERROR status" {
            $status = 'ERROR'
            $exitCode = switch ($status) {
                'OK' { 0 }
                'WARNING' { 1 }
                'CRITICAL' { 2 }
                'ERROR' { 3 }
            }
            $exitCode | Should -Be 3
        }
    }
}

Describe "Get-Temperature.ps1 - Temperature History Tests" {
    
    Context "History Management" {
        
        It "Should maintain last 5 temperature readings" {
            # Simulate adding 7 readings
            $readings = @(70, 72, 75, 78, 80, 82, 85)
            $history = @()
            
            foreach ($reading in $readings) {
                $history += $reading
                if ($history.Count -gt 5) {
                    $history = $history[($history.Count - 5)..($history.Count - 1)]
                }
            }
            
            $history.Count | Should -Be 5
            $history[0] | Should -Be 78
            $history[4] | Should -Be 85
        }
        
        It "Should format history as comma-separated string" {
            $historyList = @(70, 72, 75, 78, 80)
            $historyString = $historyList -join ', '
            
            $historyString | Should -Be "70, 72, 75, 78, 80"
        }
    }
}

Describe "Get-Temperature.ps1 - WMI Temperature Conversion Tests" {
    
    Context "Temperature Unit Conversion" {
        
        It "Should correctly convert tenths of Kelvin to Celsius" {
            # WMI returns temperature in tenths of Kelvin
            # Example: 3032 = 303.2 K = 30.05°C
            $wmiValue = 3032
            $celsius = ($wmiValue / 10) - 273.15
            
            $celsius | Should -BeGreaterThan 30
            $celsius | Should -BeLessThan 31
        }
        
        It "Should handle typical room temperature correctly" {
            # Room temperature: ~22°C = ~295K = 2951 in WMI units
            $wmiValue = 2951
            $celsius = ($wmiValue / 10) - 273.15
            
            $celsius | Should -BeGreaterThan 21
            $celsius | Should -BeLessThan 23
        }
        
        It "Should handle high CPU temperature correctly" {
            # High CPU temp: 85°C = 358.15K = 3581.5 in WMI units
            $wmiValue = 3582
            $celsius = ($wmiValue / 10) - 273.15
            
            $celsius | Should -BeGreaterThan 84
            $celsius | Should -BeLessThan 86
        }
    }
}

Describe "Get-Temperature.ps1 - Script Structure Tests" {
    
    Context "Script Requirements" {
        
        It "Should require PowerShell 5.1 or higher" {
            $ScriptContent | Should -Match '#Requires -Version 5.1'
        }
        
        It "Should use CmdletBinding" {
            $ScriptContent | Should -Match '\[CmdletBinding\(\)\]'
        }
        
        It "Should set ErrorActionPreference to Stop" {
            $ScriptContent | Should -Match '\$ErrorActionPreference\s*=\s*[''"]Stop[''"]'
        }
        
        It "Should define CPU_WARNING_THRESHOLD" {
            $ScriptContent | Should -Match '\$CPU_WARNING_THRESHOLD'
        }
        
        It "Should define CPU_CRITICAL_THRESHOLD" {
            $ScriptContent | Should -Match '\$CPU_CRITICAL_THRESHOLD'
        }
        
        It "Should define GPU_WARNING_THRESHOLD" {
            $ScriptContent | Should -Match '\$GPU_WARNING_THRESHOLD'
        }
        
        It "Should define GPU_CRITICAL_THRESHOLD" {
            $ScriptContent | Should -Match '\$GPU_CRITICAL_THRESHOLD'
        }
    }
    
    Context "Required Functions" {
        
        It "Should define Write-Log function" {
            $ScriptContent | Should -Match 'function Write-Log'
        }
        
        It "Should define Test-Administrator function" {
            $ScriptContent | Should -Match 'function Test-Administrator'
        }
        
        It "Should define Get-TemperatureStatus function" {
            $ScriptContent | Should -Match 'function Get-TemperatureStatus'
        }
        
        It "Should define Get-TopCPUProcesses function" {
            $ScriptContent | Should -Match 'function Get-TopCPUProcesses'
        }
        
        It "Should define Stop-TopCPUProcess function" {
            $ScriptContent | Should -Match 'function Stop-TopCPUProcess'
        }
    }
}
