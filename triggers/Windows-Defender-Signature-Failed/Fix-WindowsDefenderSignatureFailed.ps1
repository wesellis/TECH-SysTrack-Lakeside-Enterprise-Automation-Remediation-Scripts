#Requires -Version 5.1
#Requires -RunAsAdministrator

<#
.SYNOPSIS
    Remediation script for Windows-Defender-Signature-Failed trigger.

.DESCRIPTION
    This script remediates Windows Defender signature update failure leaving systems vulnerable.
    
    Impact: 35 systems affected (85% of enterprise fleet)
    Priority: CRITICAL
    
.PARAMETER LogOnly
    Run in diagnostic mode only - no changes made

.NOTES
    File Name: Fix-WindowsDefenderSignatureFailed.ps1
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
    [switch]$LogOnly,
    
    [Parameter(Mandatory = $false)]
    [string]$ReportPath = "$env:TEMP\Windows-Defender-Signature-Failed-Report-$(Get-Date -Format 'yyyyMMdd-HHmmss').log"
)

# Script metadata
$Script:TriggerName = "Windows-Defender-Signature-Failed"
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

function Repair-WindowsDefenderSignatures {
    Write-Log "Repairing Windows Defender signature issues..."
    $fixesApplied = @()
    
    try {
        if (-not $LogOnly) {
            # Update Windows Defender signatures
            Write-Log "Updating Windows Defender signatures..."
            Update-MpSignature
            $fixesApplied += "Updated Windows Defender signatures"
            
            # Enable real-time protection if disabled
            $mpStatus = Get-MpComputerStatus
            if (-not $mpStatus.RealTimeProtectionEnabled) {
                Write-Log "Enabling real-time protection..."
                Set-MpPreference -DisableRealtimeMonitoring $false
                $fixesApplied += "Enabled real-time protection"
            }
            
            # Start Windows Defender service if stopped
            $defenderService = Get-Service -Name "WinDefend" -ErrorAction SilentlyContinue
            if ($defenderService -and $defenderService.Status -ne "Running") {
                Write-Log "Starting Windows Defender service..."
                Start-Service -Name "WinDefend"
                $fixesApplied += "Started Windows Defender service"
            }
            
            # Trigger full signature update
            Write-Log "Triggering comprehensive signature update..."
            Start-MpScan -ScanType QuickScan
            $fixesApplied += "Initiated quick scan to verify signature functionality"
            
            Write-Log "Windows Defender remediation completed" -Level "SUCCESS"
        } else {
            Write-Log "Would repair Windows Defender signatures and configuration" -Level "WARN"
            $fixesApplied += "[SIMULATION] Would repair Windows Defender signatures and configuration"
        }
        
        return $fixesApplied
    }
    catch {
        Write-Log "Error during Windows Defender repair: $($_.Exception.Message)" -Level "ERROR"
        return $fixesApplied
    }
}

# Main execution
try {
    Write-Log "Starting $Script:TriggerName Remediation Script"
    Write-Log "Mode: $(if ($LogOnly) { 'DIAGNOSTIC ONLY' } else { 'REMEDIATION' })"
    
    $fixes = Repair-WindowsDefenderSignatures
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