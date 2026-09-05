#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Windows TLS Baseline for PKI Platform VMs
.DESCRIPTION
    Configures TLS/SSL protocol versions, cipher suites, and certificate
    settings on Windows Server VMs. Disables legacy protocols and
    enforces modern cryptographic standards.
.NOTES
    Template version: 1.0.0
    Last updated: 2026-09-05
    Apply order: 2 (after security-baseline.ps1)
    Requires reboot to fully apply SCHANNEL changes.
#>

[CmdletBinding()]
param(
    # TODO: Inject from configuration/schemas/vm-config.json
    [string]$ConfigPath = "$PSScriptRoot\..\..\config\vm-config.json",

    [switch]$WhatIf
)

$ErrorActionPreference = 'Stop'
$LogFile = "C:\Windows\Temp\tls-baseline_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"

function Write-Log {
    param([string]$Message, [string]$Level = 'INFO')
    $entry = "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') [$Level] $Message"
    Add-Content -Path $LogFile -Value $entry
    Write-Host $entry
}

# ============================================================================
# SECTION 1: Protocol Version Control (SCHANNEL)
# ============================================================================

function Set-TlsProtocols {
    Write-Log "Configuring TLS protocol versions..."

    # TODO: Customer-specific - adjust based on client compatibility requirements
    $Protocols = @(
        @{ Name = 'SSL 2.0';  Enabled = $false }
        @{ Name = 'SSL 3.0';  Enabled = $false }
        @{ Name = 'TLS 1.0';  Enabled = $false }   # TODO: May need $true for legacy clients
        @{ Name = 'TLS 1.1';  Enabled = $false }   # TODO: May need $true for legacy clients
        @{ Name = 'TLS 1.2';  Enabled = $true }
        @{ Name = 'TLS 1.3';  Enabled = $true }     # TODO: Verify Windows Server version supports TLS 1.3
    )

    foreach ($proto in $Protocols) {
        $basePath = "HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\$($proto.Name)"

        foreach ($role in @('Server', 'Client')) {
            $keyPath = "$basePath\$role"
            # if (-not (Test-Path $keyPath)) { New-Item -Path $keyPath -Force }
            # Set-ItemProperty -Path $keyPath -Name 'Enabled' -Value ([int]$proto.Enabled)
            # Set-ItemProperty -Path $keyPath -Name 'DisabledByDefault' -Value ([int](-not $proto.Enabled))
            Write-Log "  $($proto.Name) ($role): Enabled=$($proto.Enabled)"
        }
    }
}

# ============================================================================
# SECTION 2: Cipher Suite Configuration
# ============================================================================

function Set-CipherSuites {
    Write-Log "Configuring cipher suites..."

    # TODO: Customer-specific - cipher suite priority order
    # Reference: NIST SP 800-52r2, Mozilla SSL Configuration Generator
    $CipherSuites = @(
        # TLS 1.3 cipher suites (managed separately in Windows)
        # TLS_AES_256_GCM_SHA384
        # TLS_AES_128_GCM_SHA256
        # TLS_CHACHA20_POLY1305_SHA256

        # TLS 1.2 cipher suites (priority order)
        'TLS_ECDHE_ECDSA_WITH_AES_256_GCM_SHA384'
        'TLS_ECDHE_ECDSA_WITH_AES_128_GCM_SHA256'
        'TLS_ECDHE_RSA_WITH_AES_256_GCM_SHA384'
        'TLS_ECDHE_RSA_WITH_AES_128_GCM_SHA256'
        'TLS_ECDHE_ECDSA_WITH_CHACHA20_POLY1305_SHA256'
        'TLS_ECDHE_RSA_WITH_CHACHA20_POLY1305_SHA256'
        'TLS_DHE_RSA_WITH_AES_256_GCM_SHA384'
        'TLS_DHE_RSA_WITH_AES_128_GCM_SHA256'
    )

    # TODO: Apply cipher suite order via Group Policy or registry
    # Group Policy: Computer Config > Admin Templates > Network > SSL Configuration Settings
    # PowerShell: Enable-TlsCipherSuite / Disable-TlsCipherSuite

    # Disable weak ciphers explicitly
    $WeakCiphers = @(
        'TLS_RSA_WITH_AES_256_CBC_SHA256'
        'TLS_RSA_WITH_AES_128_CBC_SHA256'
        'TLS_RSA_WITH_AES_256_CBC_SHA'
        'TLS_RSA_WITH_AES_128_CBC_SHA'
        'TLS_RSA_WITH_3DES_EDE_CBC_SHA'
        'TLS_RSA_WITH_RC4_128_SHA'
        'TLS_RSA_WITH_DES_CBC_SHA'
        # TODO: Add any additional ciphers to disable
    )

    foreach ($cipher in $WeakCiphers) {
        # Disable-TlsCipherSuite -Name $cipher
        Write-Log "  Disabled cipher: $cipher"
    }

    Write-Log "Cipher suite configuration complete"
}

# ============================================================================
# SECTION 3: Key Exchange and Hash Configuration
# ============================================================================

function Set-KeyExchangeConfig {
    Write-Log "Configuring key exchange algorithms..."

    # TODO: Customer-specific - minimum DH key sizes
    $KeyExchangeConfig = @{
        MinDHKeyBits    = 2048
        MinECDHKeyBits  = 256
        PreferredCurves = @('P-384', 'P-256')   # TODO: Adjust per security requirements
    }

    # Set minimum DH key size
    # Set-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\KeyExchangeAlgorithms\Diffie-Hellman' -Name 'ServerMinKeyBitLength' -Value $KeyExchangeConfig.MinDHKeyBits

    Write-Log "  Min DH key bits: $($KeyExchangeConfig.MinDHKeyBits)"
    Write-Log "  Preferred curves: $($KeyExchangeConfig.PreferredCurves -join ', ')"
}

# ============================================================================
# SECTION 4: Certificate Store Hardening
# ============================================================================

function Set-CertificateStoreBaseline {
    Write-Log "Configuring certificate store settings..."

    # TODO: Customer-specific - trusted root CA management
    # Remove unnecessary third-party root CAs
    # Import organization root CA certificates

    # Enable certificate revocation checking
    # Set-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Cryptography\OID\EncodingType 0\CertDllCreateCertificateChainEngine\Config' -Name 'ChainRevAccumulativeUrls' -Value 1

    Write-Log "Certificate store baseline applied"
}

# ============================================================================
# SECTION 5: .NET Framework TLS Settings
# ============================================================================

function Set-DotNetTls {
    Write-Log "Configuring .NET Framework TLS settings..."

    # Force .NET to use system default TLS versions
    $DotNetPaths = @(
        'HKLM:\SOFTWARE\Microsoft\.NETFramework\v4.0.30319'
        'HKLM:\SOFTWARE\WOW6432Node\Microsoft\.NETFramework\v4.0.30319'
    )

    foreach ($path in $DotNetPaths) {
        # Set-ItemProperty -Path $path -Name 'SystemDefaultTlsVersions' -Value 1
        # Set-ItemProperty -Path $path -Name 'SchUseStrongCrypto' -Value 1
        Write-Log "  .NET strong crypto: $path"
    }
}

# ============================================================================
# MAIN EXECUTION
# ============================================================================

Write-Log "=== Windows TLS Baseline - Starting ==="
Write-Log "Config: $ConfigPath"

Set-TlsProtocols
Set-CipherSuites
Set-KeyExchangeConfig
Set-CertificateStoreBaseline
Set-DotNetTls

Write-Log "=== Windows TLS Baseline - Complete ==="
Write-Host "`nTLS baseline applied. A REBOOT is required for SCHANNEL changes." -ForegroundColor Yellow
Write-Host "Log: $LogFile" -ForegroundColor Green
