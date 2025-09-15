#Requires -Version 5.1
#Requires -RunAsAdministrator

<#
.SYNOPSIS
    Detection script for Windows-Defender-Signature-Failed trigger.

.DESCRIPTION
    This script detects Windows Defender signature update failure leaving systems vulnerable.
    
    Impact: 35 systems affected (85% of enterprise fleet)
    Priority: CRITICAL

.NOTES
    File Name: Detect-WindowsDefenderSignatureFailed.ps1
    Version: 1.0
    Date: 2025-07-01
    Author: Wesley Ellis (Wesley.Ellis@compucom.com)
    
    Trigger: Windows-Defender-Signature-Failed
    Systems Affected: 35 (85% impact)
    Priority: CRITICAL
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$ReportPath = "$env:TEMP\Windows-Defender-Signature-Failed-Report-$(Get-Date -Format 'yyyyMMdd-HHmmss').log"
)

# Script metadata
$Script:TriggerName = "Windows-Defender-Signature-Failed"
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

function Test-WindowsDefenderSignatures {
    Write-Log "Checking Windows Defender signature status..."
    
    try {
        $defenderIssues = @()
        
        # Get Windows Defender status
        $mpPreference = Get-MpPreference -ErrorAction SilentlyContinue
        $mpStatus = Get-MpComputerStatus -ErrorAction SilentlyContinue
        
        if ($mpStatus) {
            # Check signature age
            $signatureAge = (Get-Date) - $mpStatus.AntivirusSignatureLastUpdated
            
            if ($signatureAge.Days -gt 7) {
                $defenderIssues += [PSCustomObject]@{
                    Component = "AntivirusSignatures"
                    Issue = "Antivirus signatures outdated"
                    LastUpdate = $mpStatus.AntivirusSignatureLastUpdated
                    DaysOld = $signatureAge.Days
                    Severity = "CRITICAL"
                }
                Write-Log "CRITICAL: Antivirus signatures are $($signatureAge.Days) days old" -Level "ERROR"
            }
            
            # Check if real-time protection is enabled
            if (-not $mpStatus.RealTimeProtectionEnabled) {
                $defenderIssues += [PSCustomObject]@{
                    Component = "RealTimeProtection"
                    Issue = "Real-time protection disabled"
                    Status = $mpStatus.RealTimeProtectionEnabled
                    Severity = "CRITICAL"
                }
                Write-Log "CRITICAL: Windows Defender real-time protection disabled" -Level "ERROR"
            }
            
            # Check if antivirus is enabled
            if (-not $mpStatus.AntivirusEnabled) {
                $defenderIssues += [PSCustomObject]@{
                    Component = "AntivirusEngine"
                    Issue = "Antivirus engine disabled"
                    Status = $mpStatus.AntivirusEnabled
                    Severity = "CRITICAL"
                }
                Write-Log "CRITICAL: Windows Defender antivirus engine disabled" -Level "ERROR"
            }
            
        } else {
            $defenderIssues += [PSCustomObject]@{
                Component = "WindowsDefender"
                Issue = "Cannot retrieve Windows Defender status"
                Severity = "CRITICAL"
            }
            Write-Log "CRITICAL: Cannot retrieve Windows Defender status" -Level "ERROR"
        }
        
        $Script:IssuesFound = $defenderIssues
        return $defenderIssues.Count -gt 0
    }
    catch {
        Write-Log "Error checking Windows Defender: $($_.Exception.Message)" -Level "ERROR"
        return $false
    }
}

# Main execution
try {
    Write-Log "Starting $Script:TriggerName Detection Script"
    
    $detected = Test-WindowsDefenderSignatures
    
    if ($detected) {
        Write-Log "Windows Defender signature issues detected" -Level "WARN"
        Write-Log "Found $($Script:IssuesFound.Count) issues requiring attention"
        exit 1
    } else {
        Write-Log "No Windows Defender signature issues detected" -Level "SUCCESS"
        exit 0
    }
}
catch {
    Write-Log "FATAL ERROR: $($_.Exception.Message)" -Level "ERROR"
    exit 2
}