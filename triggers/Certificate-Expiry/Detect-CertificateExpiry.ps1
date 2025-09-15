#Requires -Version 5.1
#Requires -RunAsAdministrator

<#
.SYNOPSIS
    Detection script for Certificate-Expiry trigger.

.DESCRIPTION
    This script detects critical certificate expiration affecting system authentication.
    
    Impact: 45 systems affected (80% of enterprise fleet)
    Priority: CRITICAL

.NOTES
    File Name: Detect-CertificateExpiry.ps1
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
    [string]$ReportPath = "$env:TEMP\Certificate-Expiry-Report-$(Get-Date -Format 'yyyyMMdd-HHmmss').log"
)

# Script metadata
$Script:TriggerName = "Certificate-Expiry"
$Script:LogFile = $ReportPath
$Script:StartTime = Get-Date
$Script:IssuesFound = @()

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

function Test-CertificateExpiry {
    Write-Log "Checking for certificate expiration issues..."
    
    try {
        $certificateIssues = @()
        $stores = @("LocalMachine\My", "LocalMachine\Root", "CurrentUser\My")
        
        foreach ($store in $stores) {
            $certificates = Get-ChildItem -Path "Cert:\$store" -ErrorAction SilentlyContinue
            
            foreach ($cert in $certificates) {
                $daysUntilExpiry = ($cert.NotAfter - (Get-Date)).Days
                
                if ($daysUntilExpiry -lt 0) {
                    $certificateIssues += [PSCustomObject]@{
                        Subject = $cert.Subject
                        Issuer = $cert.Issuer
                        Store = $store
                        Expiry = $cert.NotAfter
                        DaysOverdue = [Math]::Abs($daysUntilExpiry)
                        Issue = "Certificate expired"
                        Severity = "CRITICAL"
                    }
                    Write-Log "CRITICAL: Certificate expired: $($cert.Subject)" -Level "ERROR"
                } elseif ($daysUntilExpiry -lt 30) {
                    $certificateIssues += [PSCustomObject]@{
                        Subject = $cert.Subject
                        Issuer = $cert.Issuer
                        Store = $store
                        Expiry = $cert.NotAfter
                        DaysRemaining = $daysUntilExpiry
                        Issue = "Certificate expiring soon"
                        Severity = "HIGH"
                    }
                    Write-Log "WARNING: Certificate expiring in $daysUntilExpiry days: $($cert.Subject)" -Level "WARN"
                }
            }
        }
        
        $Script:IssuesFound = $certificateIssues
        return $certificateIssues.Count -gt 0
    }
    catch {
        Write-Log "Error checking certificates: $($_.Exception.Message)" -Level "ERROR"
        return $false
    }
}

# Main execution
try {
    Write-Log "Starting $Script:TriggerName Detection Script"
    
    $detected = Test-CertificateExpiry
    
    if ($detected) {
        Write-Log "Certificate expiry issues detected" -Level "WARN"
        Write-Log "Found $($Script:IssuesFound.Count) certificate issues requiring attention"
        exit 1
    } else {
        Write-Log "No certificate expiry issues detected" -Level "SUCCESS"
        exit 0
    }
}
catch {
    Write-Log "FATAL ERROR: $($_.Exception.Message)" -Level "ERROR"
    exit 2
}