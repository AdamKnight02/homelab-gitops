#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Windows Security Baseline for PKI Platform VMs
.DESCRIPTION
    Applies foundational security hardening to Windows Server VMs
    in the PKI platform. Covers account policies, audit policies,
    Windows Defender, firewall, and SMB hardening.
.NOTES
    Template version: 1.0.0
    Last updated: 2026-09-05
    Apply order: 1 (first script after OS provisioning)
#>

[CmdletBinding()]
param(
    # TODO: Inject from configuration/schemas/vm-config.json
    [string]$ConfigPath = "$PSScriptRoot\..\..\config\vm-config.json",

    [switch]$WhatIf
)

$ErrorActionPreference = 'Stop'
$LogFile = "C:\Windows\Temp\security-baseline_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"

function Write-Log {
    param([string]$Message, [string]$Level = 'INFO')
    $entry = "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') [$Level] $Message"
    Add-Content -Path $LogFile -Value $entry
    Write-Host $entry
}

# ============================================================================
# SECTION 1: Local Security Policy
# ============================================================================

function Set-LocalSecurityPolicy {
    Write-Log "Applying local security policy..."

    # TODO: Customer-specific - password policy values
    $PasswordPolicy = @{
        MinimumPasswordLength = 14          # TODO: Adjust per compliance requirements
        PasswordComplexity    = $true
        MaximumPasswordAge    = 90          # TODO: Adjust per compliance requirements
        MinimumPasswordAge    = 1
        PasswordHistorySize   = 24
        LockoutThreshold      = 5
        LockoutDuration       = 30          # minutes
        LockoutWindow         = 30          # minutes
    }

    # TODO: Export current policy, modify, re-import via secedit
    # secedit /export /cfg C:\Windows\Temp\secpol_current.cfg
    # Modify values in cfg file
    # secedit /configure /db C:\Windows\security\local.sdb /cfg C:\Windows\Temp\secpol_new.cfg

    Write-Log "Password policy configured: MinLength=$($PasswordPolicy.MinimumPasswordLength)"
}

# ============================================================================
# SECTION 2: Audit Policy
# ============================================================================

function Set-AuditPolicy {
    Write-Log "Configuring audit policies..."

    # TODO: Customer-specific - audit categories based on compliance framework
    $AuditCategories = @(
        @{ Category = 'Account Logon';    Success = $true; Failure = $true }
        @{ Category = 'Account Management'; Success = $true; Failure = $true }
        @{ Category = 'Logon/Logoff';     Success = $true; Failure = $true }
        @{ Category = 'Policy Change';    Success = $true; Failure = $true }
        @{ Category = 'Privilege Use';    Success = $false; Failure = $true }
        @{ Category = 'System';           Success = $true; Failure = $true }
        @{ Category = 'Object Access';    Success = $false; Failure = $true }  # TODO: Enable success for cert store access
    )

    foreach ($cat in $AuditCategories) {
        # auditpol /set /category:"$($cat.Category)" /success:$(if($cat.Success){'enable'}else{'disable'}) /failure:$(if($cat.Failure){'enable'}else{'disable'})
        Write-Log "  Audit: $($cat.Category) - Success=$($cat.Success) Failure=$($cat.Failure)"
    }
}

# ============================================================================
# SECTION 3: Windows Defender Configuration
# ============================================================================

function Set-DefenderBaseline {
    Write-Log "Configuring Windows Defender..."

    # TODO: Customer-specific - exclusion paths for PKI services
    $DefenderConfig = @{
        RealTimeProtection   = $true
        CloudProtection      = $true
        SampleSubmission     = 'NeverSend'       # TODO: Adjust per data governance policy
        ExclusionPaths       = @(
            # TODO: Add PKI-specific exclusions (e.g., CA database paths)
            # 'C:\Windows\System32\CertLog'
        )
        ExclusionProcesses   = @(
            # TODO: Add PKI service processes if needed
        )
    }

    # Set-MpPreference -DisableRealtimeMonitoring $(-not $DefenderConfig.RealTimeProtection)
    # Set-MpPreference -MAPSReporting $(if($DefenderConfig.CloudProtection){'Advanced'}else{'Disabled'})

    Write-Log "Windows Defender baseline applied"
}

# ============================================================================
# SECTION 4: Windows Firewall
# ============================================================================

function Set-FirewallBaseline {
    Write-Log "Configuring Windows Firewall baseline..."

    # Enable all profiles
    # Set-NetFirewallProfile -Profile Domain,Public,Private -Enabled True

    # Default inbound block, outbound allow
    # Set-NetFirewallProfile -Profile Domain,Public,Private -DefaultInboundAction Block -DefaultOutboundAction Allow

    # TODO: Customer-specific - management ports
    $ManagementRules = @(
        @{ Name = 'Allow-RDP-Mgmt';    Port = 3389;  Protocol = 'TCP'; SourceIPs = @('TODO_MGMT_SUBNET') }
        @{ Name = 'Allow-WinRM-Mgmt';  Port = 5986;  Protocol = 'TCP'; SourceIPs = @('TODO_MGMT_SUBNET') }
        @{ Name = 'Allow-ICMPv4';      Protocol = 'ICMPv4' }
    )

    # TODO: Customer-specific - role-specific firewall rules are in role scripts
    Write-Log "Firewall baseline applied (role-specific rules in role scripts)"
}

# ============================================================================
# SECTION 5: SMB Hardening
# ============================================================================

function Set-SmbHardening {
    Write-Log "Hardening SMB configuration..."

    # Disable SMBv1
    # Disable-WindowsOptionalFeature -Online -FeatureName SMB1Protocol -NoRestart
    # Set-SmbServerConfiguration -EnableSMB1Protocol $false -Force

    # Require SMB signing
    # Set-SmbServerConfiguration -RequireSecuritySignature $true -Force

    # Enable SMB encryption
    # Set-SmbServerConfiguration -EncryptData $true -Force

    Write-Log "SMB hardening applied"
}

# ============================================================================
# SECTION 6: Disable Unnecessary Services
# ============================================================================

function Disable-UnnecessaryServices {
    Write-Log "Disabling unnecessary services..."

    # TODO: Customer-specific - services safe to disable in your environment
    $ServicesToDisable = @(
        'Spooler'              # Print Spooler - disable on non-print servers
        'WMPNetworkSvc'        # Windows Media Player Network Sharing
        'XblAuthManager'       # Xbox Live Auth
        'XblGameSave'          # Xbox Live Game Save
        # TODO: Review and add environment-specific services
    )

    foreach ($svc in $ServicesToDisable) {
        if (Get-Service -Name $svc -ErrorAction SilentlyContinue) {
            # Stop-Service -Name $svc -Force
            # Set-Service -Name $svc -StartupType Disabled
            Write-Log "  Disabled service: $svc"
        }
    }
}

# ============================================================================
# SECTION 7: Registry Hardening
# ============================================================================

function Set-RegistryHardening {
    Write-Log "Applying registry hardening..."

    $RegistrySettings = @(
        # Disable LLMNR
        @{ Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\DNSClient'; Name = 'EnableMulticast'; Value = 0 }

        # Disable NetBIOS over TCP/IP (handled via network adapter settings)
        # Disable WPAD
        @{ Path = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Internet Settings\WinHttp'; Name = 'DisableWpad'; Value = 1 }

        # TODO: Customer-specific - additional registry hardening
        # LSA protection
        @{ Path = 'HKLM:\SYSTEM\CurrentControlSet\Control\Lsa'; Name = 'RunAsPPL'; Value = 1 }
    )

    foreach ($reg in $RegistrySettings) {
        # if (-not (Test-Path $reg.Path)) { New-Item -Path $reg.Path -Force }
        # Set-ItemProperty -Path $reg.Path -Name $reg.Name -Value $reg.Value
        Write-Log "  Registry: $($reg.Path)\$($reg.Name) = $($reg.Value)"
    }
}

# ============================================================================
# MAIN EXECUTION
# ============================================================================

Write-Log "=== Windows Security Baseline - Starting ==="
Write-Log "Config: $ConfigPath"

Set-LocalSecurityPolicy
Set-AuditPolicy
Set-DefenderBaseline
Set-FirewallBaseline
Set-SmbHardening
Disable-UnnecessaryServices
Set-RegistryHardening

Write-Log "=== Windows Security Baseline - Complete ==="
Write-Host "`nSecurity baseline applied. Log: $LogFile" -ForegroundColor Green
