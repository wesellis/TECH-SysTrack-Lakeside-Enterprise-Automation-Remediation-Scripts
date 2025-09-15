#Requires -Version 5.1
#Requires -RunAsAdministrator

<#
.SYNOPSIS
    Remediation script for Certificate-Expiry trigger.

.DESCRIPTION
    This script remediates critical certificate expiration affecting system authentication.
    
    Impact: 45 systems affected (80% of enterprise fleet)
    Priority: CRITICAL
    
.PARAMETER LogOnly
    Run in diagnostic mode only - no changes made

.NOTES
    File Name: Fix-CertificateExpiry.ps1
    Version: 1.0
    Date: 2025-07-01
    Author: Wesley Ellis (Wesley.Ellis@compucom.com)
    
    Trigger: Certificate-Expiry
    Systems Affected: 45 (80% impact)
    Priority: CRITICAL
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [switch]$LogOnly,
    
    [Parameter(Mandatory = $false)]
    [string]$ReportPath = "$env:TEMP\Certificate-Expiry-Report-$(Get-Date -Format 'yyyyMMdd-HHmmss').log"
)

# Script metadata
$Script:TriggerName = "Certificate-Expiry"
$Script:LogFile = $ReportPath
$Script:StartTime = Get-Date
$Script:FixesApplied = @()

function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "[$timestamp] [$Level] $Message"
    Write-Host $logEntry -ForegroundColor $(
        switch ($Level) {
            "ERROR" { "Red" }; "WARN" { "Yellow" }; "SUCCESS" { "Green" }; default { "White" }
        }
    )
    Add-Content -Path $Script:LogFile -Value $logEntry -ErrorAction SilentlyContinue
}

function Repair-ExpiredCertificates {
    Write-Log "Repairing expired certificate issues..."
    $fixesApplied = @()
    
    try {
        if (-not $LogOnly) {
            # Remove expired certificates
            Write-Log "Removing expired certificates..."
            $stores = @("LocalMachine\My", "CurrentUser\My")
            
            foreach ($store in $stores) {
                $expiredCerts = Get-ChildItem -Path "Cert:\$store" | Where-Object { $_.NotAfter -lt (Get-Date) }
                foreach ($cert in $expiredCerts) {
                    Remove-Item -Path $cert.PSPath -Force
                    $fixesApplied += "Removed expired certificate: $($cert.Subject)"
                }
            }
            
            # Trigger certificate auto-enrollment
            Write-Log "Triggering certificate auto-enrollment..."
            certlm.msc /s
            $fixesApplied += "Triggered certificate auto-enrollment"
            
            Write-Log "Certificate remediation completed" -Level "SUCCESS"
        } else {
            Write-Log "Would repair expired certificates" -Level "WARN"
            $fixesApplied += "[SIMULATION] Would repair expired certificates"
        }
        
        return $fixesApplied
    }
    catch {
        Write-Log "Error during certificate repair: $($_.Exception.Message)" -Level "ERROR"
        return $fixesApplied
    }
}

# Main execution
try {
    Write-Log "Starting $Script:TriggerName Remediation Script"
    Write-Log "Mode: $(if ($LogOnly) { 'DIAGNOSTIC ONLY' } else { 'REMEDIATION' })"
    
    $fixes = Repair-ExpiredCertificates
    $Script:FixesApplied += $fixes
    
    Write-Log "=== REMEDIATION SUMMARY ===" -Level "SUCCESS"
    Write-Log "Fixes Applied: $($Script:FixesApplied.Count)"
    Write-Log "Execution Time: $((Get-Date) - $Script:StartTime)"
    
    exit 0
}
catch {
    Write-Log "FATAL ERROR: $($_.Exception.Message)" -Level "ERROR"
    exit 1
}