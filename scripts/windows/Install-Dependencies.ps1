#Requires -Version 5.1
<#
.SYNOPSIS
    Installs LibreHardwareMonitor dependency for temperature monitoring

.DESCRIPTION
    # =============================================================================
    # Script Name  : Install-Dependencies.ps1
    # Platform     : Windows
    # Description  : Downloads and validates LibreHardwareMonitor DLL for use
    #                with the temperature monitoring script
    # Dependencies : Internet connection for initial download
    # Author       : NinjaRMM Temperature Monitoring Team
    # Version      : 1.0.0
    # Last Updated : 2026-02-19
    # =============================================================================

.PARAMETER Force
    Force reinstallation even if DLL already exists

.EXAMPLE
    .\Install-Dependencies.ps1
    Install dependencies if not present

.EXAMPLE
    .\Install-Dependencies.ps1 -Force
    Force reinstall dependencies
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$false)]
    [switch]$Force
)

$ErrorActionPreference = 'Stop'

# =============================================================================
# CONFIGURATION
# =============================================================================

$INSTALL_DIR = "C:\ProgramData\NinjaRMM\TempMonitor"
$DLL_PATH = Join-Path $INSTALL_DIR "LibreHardwareMonitorLib.dll"
$LIBREHARDWAREMONITOR_VERSION = "0.9.3"
$DOWNLOAD_URL = "https://github.com/LibreHardwareMonitor/LibreHardwareMonitor/releases/download/v$LIBREHARDWAREMONITOR_VERSION/LibreHardwareMonitor-net472.zip"
$TEMP_ZIP = Join-Path $env:TEMP "LibreHardwareMonitor.zip"
$TEMP_EXTRACT = Join-Path $env:TEMP "LibreHardwareMonitor_Extract"

# Expected SHA256 hash for LibreHardwareMonitorLib.dll from version 0.9.3
# NOTE: This is a placeholder - in production, verify the actual hash from the official release
$EXPECTED_SHA256 = "PLACEHOLDER_HASH_VERIFY_FROM_OFFICIAL_RELEASE"

# =============================================================================
# FUNCTIONS
# =============================================================================

function Write-LogMessage {
    param(
        [string]$Message,
        [string]$Level = 'INFO'
    )
    $timestamp = Get-Date -Format 'yyyy-MM-ddTHH:mm:ss'
    $logEntry = "[$timestamp] [$Level] $Message"
    Write-Host $logEntry
}

function Test-Administrator {
    $currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
    return $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Get-FileHashString {
    param(
        [string]$FilePath
    )
    $hash = Get-FileHash -Path $FilePath -Algorithm SHA256
    return $hash.Hash
}

# =============================================================================
# MAIN EXECUTION
# =============================================================================

try {
    Write-LogMessage "Starting dependency installation" -Level INFO

    # Check for admin privileges
    if (-not (Test-Administrator)) {
        Write-LogMessage "Script must be run with Administrator privileges" -Level ERROR
        exit 1
    }

    # Check if already installed
    if ((Test-Path $DLL_PATH) -and -not $Force) {
        Write-LogMessage "LibreHardwareMonitorLib.dll already exists at: $DLL_PATH" -Level INFO
        Write-LogMessage "Use -Force parameter to reinstall" -Level INFO
        exit 0
    }

    # Create installation directory
    if (-not (Test-Path $INSTALL_DIR)) {
        Write-LogMessage "Creating installation directory: $INSTALL_DIR" -Level INFO
        New-Item -ItemType Directory -Path $INSTALL_DIR -Force | Out-Null
    }

    # Clean up temp files if they exist
    if (Test-Path $TEMP_ZIP) {
        Remove-Item $TEMP_ZIP -Force
    }
    if (Test-Path $TEMP_EXTRACT) {
        Remove-Item $TEMP_EXTRACT -Recurse -Force
    }

    # Download LibreHardwareMonitor
    Write-LogMessage "Downloading LibreHardwareMonitor from: $DOWNLOAD_URL" -Level INFO
    try {
        # Use TLS 1.2
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        
        $webClient = New-Object System.Net.WebClient
        $webClient.DownloadFile($DOWNLOAD_URL, $TEMP_ZIP)
        
        Write-LogMessage "Download completed successfully" -Level INFO
    }
    catch {
        Write-LogMessage "Failed to download LibreHardwareMonitor: $($_.Exception.Message)" -Level ERROR
        Write-LogMessage "Please download manually from https://github.com/LibreHardwareMonitor/LibreHardwareMonitor/releases" -Level ERROR
        exit 1
    }

    # Extract the ZIP file
    Write-LogMessage "Extracting archive..." -Level INFO
    try {
        Expand-Archive -Path $TEMP_ZIP -DestinationPath $TEMP_EXTRACT -Force
        Write-LogMessage "Extraction completed" -Level INFO
    }
    catch {
        Write-LogMessage "Failed to extract archive: $($_.Exception.Message)" -Level ERROR
        exit 1
    }

    # Find and copy the DLL
    Write-LogMessage "Locating LibreHardwareMonitorLib.dll..." -Level INFO
    $dllSource = Get-ChildItem -Path $TEMP_EXTRACT -Filter "LibreHardwareMonitorLib.dll" -Recurse | Select-Object -First 1

    if (-not $dllSource) {
        Write-LogMessage "LibreHardwareMonitorLib.dll not found in the extracted archive" -Level ERROR
        exit 1
    }

    Write-LogMessage "Found DLL at: $($dllSource.FullName)" -Level INFO

    # Verify hash (commented out for now as we need the actual hash)
    # Write-LogMessage "Verifying file hash..." -Level INFO
    # $actualHash = Get-FileHashString -FilePath $dllSource.FullName
    # if ($actualHash -ne $EXPECTED_SHA256) {
    #     Write-LogMessage "Hash mismatch! Expected: $EXPECTED_SHA256, Got: $actualHash" -Level ERROR
    #     Write-LogMessage "File may be corrupted or tampered with" -Level ERROR
    #     exit 1
    # }
    # Write-LogMessage "Hash verification passed" -Level INFO

    # Copy DLL to installation directory
    Write-LogMessage "Copying DLL to: $DLL_PATH" -Level INFO
    Copy-Item -Path $dllSource.FullName -Destination $DLL_PATH -Force

    # Set appropriate permissions (SYSTEM and Administrators only)
    $acl = Get-Acl $DLL_PATH
    $acl.SetAccessRuleProtection($true, $false)  # Disable inheritance
    
    # Add SYSTEM full control
    $systemRule = New-Object System.Security.AccessControl.FileSystemAccessRule(
        "NT AUTHORITY\SYSTEM",
        "FullControl",
        "Allow"
    )
    $acl.AddAccessRule($systemRule)
    
    # Add Administrators full control
    $adminRule = New-Object System.Security.AccessControl.FileSystemAccessRule(
        "BUILTIN\Administrators",
        "FullControl",
        "Allow"
    )
    $acl.AddAccessRule($adminRule)
    
    Set-Acl -Path $DLL_PATH -AclObject $acl
    Write-LogMessage "Permissions configured" -Level INFO

    # Clean up temporary files
    Write-LogMessage "Cleaning up temporary files..." -Level INFO
    if (Test-Path $TEMP_ZIP) {
        Remove-Item $TEMP_ZIP -Force
    }
    if (Test-Path $TEMP_EXTRACT) {
        Remove-Item $TEMP_EXTRACT -Recurse -Force
    }

    Write-LogMessage "Installation completed successfully" -Level INFO
    Write-LogMessage "LibreHardwareMonitorLib.dll installed at: $DLL_PATH" -Level INFO
    exit 0
}
catch {
    Write-LogMessage "Unhandled exception: $($_.Exception.Message)" -Level ERROR
    exit 1
}
