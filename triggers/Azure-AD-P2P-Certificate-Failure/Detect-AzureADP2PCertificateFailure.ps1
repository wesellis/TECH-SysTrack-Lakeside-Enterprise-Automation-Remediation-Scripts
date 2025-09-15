#Requires -Version 5.1
#Requires -RunAsAdministrator

<#
.SYNOPSIS
    Detection script for Azure-AD-P2P-Certificate-Failure trigger.

.DESCRIPTION
    This script detects Azure AD P2P certificate authentication failure.
    
    Impact: 85 systems affected (75% of enterprise fleet)
    Priority: CRITICAL
    
.EXAMPLE
    .\Detect-AzureADP2PCertificateFailure.ps1

.NOTES
    File Name: Detect-AzureADP2PCertificateFailure.ps1
    Version: 1.0
    Date: 2025-07-01
    Author: Wesley Ellis (Wesley.Ellis@compucom.com)
    Company: CompuCom - SysTrack Automation Team
    
    Trigger: Azure-AD-P2P-Certificate-Failure
    Systems Affected: 85 (75% impact)
    Priority: CRITICAL
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$ReportPath = "$env:TEMP\Azure-AD-P2P-Certificate-Failure-Report-$(Get-Date -Format 'yyyyMMdd-HHmmss').log"
)

# Script metadata
$Script:ScriptVersion = "1.0"
$Script:ScriptDate = "2025-07-01"
$Script:ScriptAuthor = "Wesley Ellis (Wesley.Ellis@compucom.com)"
$Script:TriggerName = "Azure-AD-P2P-Certificate-Failure"
$Script:SystemsAffected = 85
$Script:ImpactPercentage = 75
$Script:Priority = "CRITICAL"

# Initialize logging
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

function Test-AzureADCertificates {
    Write-Log "Checking Azure AD P2P certificates..."
    
    try {
        $certificateIssues = @()
        
        # Check Azure AD device certificates
        $azureADCerts = Get-ChildItem -Path "Cert:\LocalMachine\My" | Where-Object { 
            $_.Subject -like "*CN=*" -and ($_.Issuer -like "*Microsoft*" -or $_.Subject -like "*Azure*")
        }
        
        foreach ($cert in $azureADCerts) {
            $daysUntilExpiry = ($cert.NotAfter - (Get-Date)).Days
            
            if ($daysUntilExpiry -lt 0) {
                $certificateIssues += [PSCustomObject]@{
                    Subject = $cert.Subject
                    Issuer = $cert.Issuer
                    Expiry = $cert.NotAfter
                    DaysOverdue = [Math]::Abs($daysUntilExpiry)
                    Issue = "Certificate expired"
                    Severity = "CRITICAL"
                }
                Write-Log "CRITICAL: Azure AD certificate expired: $($cert.Subject)" -Level "ERROR"
            } elseif ($daysUntilExpiry -lt 30) {
                $certificateIssues += [PSCustomObject]@{
                    Subject = $cert.Subject
                    Issuer = $cert.Issuer  
                    Expiry = $cert.NotAfter
                    DaysRemaining = $daysUntilExpiry
                    Issue = "Certificate expiring soon"
                    Severity = "HIGH"
                }
                Write-Log "WARNING: Azure AD certificate expiring in $daysUntilExpiry days: $($cert.Subject)" -Level "WARN"
            }
        }
        
        # Check Azure AD join status
        try {
            $azureAdStatus = dsregcmd /status
            $isAzureAdJoined = $azureAdStatus -match "AzureAdJoined\s*:\s*YES"
            
            if (-not $isAzureAdJoined) {
                $certificateIssues += [PSCustomObject]@{
                    Component = "AzureADJoin"
                    Issue = "Device not joined to Azure AD"
                    Severity = "CRITICAL"
                }
                Write-Log "CRITICAL: Device not joined to Azure AD" -Level "ERROR"
            } else {
                Write-Log "Device is Azure AD joined" -Level "SUCCESS"
            }
        } catch {
            Write-Log "Could not check Azure AD join status: $($_.Exception.Message)" -Level "WARN"
        }
        
        $Script:IssuesFound = $certificateIssues
        return $certificateIssues.Count -gt 0
    }
    catch {
        Write-Log "Error checking Azure AD certificates: $($_.Exception.Message)" -Level "ERROR"
        return $false
    }
}

# Main execution
try {
    Write-Log "Starting $Script:TriggerName Detection Script v$Script:ScriptVersion"
    Write-Log "Priority: $Script:Priority | Impact: $Script:ImpactPercentage% | Systems: $Script:SystemsAffected"
    
    $detected = Test-AzureADCertificates
    
    if ($detected) {
        Write-Log "Issues detected for $Script:TriggerName" -Level "WARN"
        Write-Log "Found $($Script:IssuesFound.Count) certificate issues requiring attention"
        exit 1
    } else {
        Write-Log "No Azure AD certificate issues detected" -Level "SUCCESS"
        exit 0
    }
}
catch {
    Write-Log "FATAL ERROR: $($_.Exception.Message)" -Level "ERROR"
    exit 2
}