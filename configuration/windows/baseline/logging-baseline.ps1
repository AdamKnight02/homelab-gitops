#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Windows Logging Baseline for PKI Platform VMs
.DESCRIPTION
    Configures Windows Event Log sizes, retention, forwarding (if applicable),
    and PowerShell logging for PKI platform VMs.
.NOTES
    Template version: 1.0.0
    Last updated: 2026-09-05
    Apply order: 3 (after security-baseline.ps1 and tls-baseline.ps1)
#>

[CmdletBinding()]
param(
    # TODO: Inject from configuration/schemas/vm-config.json
    [string]$ConfigPath = "$PSScriptRoot\..\..\config\vm-config.json",

    [switch]$WhatIf
)

$ErrorActionPreference = 'Stop'
$LogFile = "C:\Windows\Temp\logging-baseline_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"

function Write-Log {
    param([string]$Message, [string]$Level = 'INFO')
    $entry = "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') [$Level] $Message"
    Add-Content -Path $LogFile -Value $entry
    Write-Host $entry
}

# ============================================================================
# SECTION 1: Event Log Configuration
# ============================================================================

function Set-EventLogSizes {
    Write-Log "Configuring event log sizes and retention..."

    # TODO: Customer-specific - log sizes based on retention requirements
    $LogConfig = @(
        @{ LogName = 'Security';       MaxSizeMB = 1024; RetentionDays = 90 }   # TODO: Adjust per SIEM/compliance
        @{ LogName = 'System';         MaxSizeMB = 256;  RetentionDays = 30 }
        @{ LogName = 'Application';    MaxSizeMB = 256;  RetentionDays = 30 }
        @{ LogName = 'Microsoft-Windows-PowerShell/Operational'; MaxSizeMB = 128; RetentionDays = 30 }
        @{ LogName = 'Windows PowerShell'; MaxSizeMB = 64; RetentionDays = 30 }
    )

    foreach ($log in $LogConfig) {
        $maxBytes = $log.MaxSizeMB * 1MB
        # Limit-EventLog -LogName $log.LogName -MaximumSize $maxBytes
        # wevtutil sl "$($log.LogName)" /ms:$maxBytes
        Write-Log "  $($log.LogName): MaxSize=$($log.MaxSizeMB)MB, Retention=$($log.RetentionDays)d"
    }
}

# ============================================================================
# SECTION 2: PowerShell Logging
# ============================================================================

function Set-PowerShellLogging {
    Write-Log "Configuring PowerShell logging..."

    # Script Block Logging
    $scriptBlockPath = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\PowerShell\ScriptBlockLogging'
    # if (-not (Test-Path $scriptBlockPath)) { New-Item -Path $scriptBlockPath -Force }
    # Set-ItemProperty -Path $scriptBlockPath -Name 'EnableScriptBlockLogging' -Value 1
    # Set-ItemProperty -Path $scriptBlockPath -Name 'EnableScriptBlockInvocationLogging' -Value 1
    Write-Log "  Script Block Logging: Enabled"

    # Module Logging
    $modulePath = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\PowerShell\ModuleLogging'
    # if (-not (Test-Path $modulePath)) { New-Item -Path $modulePath -Force }
    # Set-ItemProperty -Path $modulePath -Name 'EnableModuleLogging' -Value 1
    # TODO: Customer-specific - module names to log
    # New-ItemProperty -Path "$modulePath\ModuleNames" -Name '*' -Value '*' -PropertyType String
    Write-Log "  Module Logging: Enabled (all modules)"

    # Transcription
    $transcriptionPath = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\PowerShell\Transcription'
    # if (-not (Test-Path $transcriptionPath)) { New-Item -Path $transcriptionPath -Force }
    # Set-ItemProperty -Path $transcriptionPath -Name 'EnableTranscripting' -Value 1
    # Set-ItemProperty -Path $transcriptionPath -Name 'OutputDirectory' -Value 'C:\PSTranscripts'  # TODO: Centralize
    # Set-ItemProperty -Path $transcriptionPath -Name 'EnableInvocationHeader' -Value 1
    Write-Log "  Transcription: Enabled"
}

# ============================================================================
# SECTION 3: Windows Event Forwarding (WEF) - Optional
# ============================================================================

function Set-EventForwarding {
    Write-Log "Configuring Windows Event Forwarding..."

    # TODO: Customer-specific - WEF collector configuration
    $WEFConfig = @{
        Enabled          = $false   # TODO: Set to $true if using WEF
        CollectorFQDN    = 'TODO_WEF_COLLECTOR_FQDN'
        CollectorPort    = 5985
        SubscriptionID   = 'TODO_SUBSCRIPTION_ID'
    }

    if ($WEFConfig.Enabled) {
        # Configure WinRM for event forwarding
        # winrm quickconfig -q
        # Add machine to Event Log Readers group or configure source-initiated subscription
        Write-Log "  WEF configured -> $($WEFConfig.CollectorFQDN):$($WEFConfig.CollectorPort)"
    } else {
        Write-Log "  WEF: Disabled (TODO: Enable when collector is available)"
    }
}

# ============================================================================
# SECTION 4: Sysmon (Optional)
# ============================================================================

function Install-SysmonConfig {
    Write-Log "Configuring Sysmon..."

    # TODO: Customer-specific - Sysmon deployment and configuration
    $SysmonConfig = @{
        Enabled       = $false   # TODO: Set to $true when Sysmon is approved
        BinaryPath    = 'TODO_SYSMON_BINARY_PATH'
        ConfigPath    = 'TODO_SYSMON_CONFIG_PATH'   # e.g., SwiftOnSecurity sysmon config
        ServiceName   = 'Sysmon64'
    }

    if ($SysmonConfig.Enabled) {
        # & "$($SysmonConfig.BinaryPath)" -accepteula -i "$($SysmonConfig.ConfigPath)"
        Write-Log "  Sysmon installed with config: $($SysmonConfig.ConfigPath)"
    } else {
        Write-Log "  Sysmon: Not enabled (TODO: Deploy when approved)"
    }
}

# ============================================================================
# SECTION 5: Time Synchronization
# ============================================================================

function Set-TimeSync {
    Write-Log "Configuring time synchronization..."

    # TODO: Customer-specific - NTP source configuration
    $NTPConfig = @{
        Servers = @('TODO_NTP_SERVER_1', 'TODO_NTP_SERVER_2')
        Type    = 'NTP'
    }

    # w32tm /config /manualpeerlist:"$($NTPConfig.Servers -join ' ')" /syncfromflags:manual /update
    # Restart-Service w32time
    # w32tm /resync

    Write-Log "  NTP servers: $($NTPConfig.Servers -join ', ')"
}

# ============================================================================
# MAIN EXECUTION
# ============================================================================

Write-Log "=== Windows Logging Baseline - Starting ==="
Write-Log "Config: $ConfigPath"

Set-EventLogSizes
Set-PowerShellLogging
Set-EventForwarding
Install-SysmonConfig
Set-TimeSync

Write-Log "=== Windows Logging Baseline - Complete ==="
Write-Host "`nLogging baseline applied. Log: $LogFile" -ForegroundColor Green
