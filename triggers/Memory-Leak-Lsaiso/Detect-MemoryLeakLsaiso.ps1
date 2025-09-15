#Requires -Version 5.1
#Requires -RunAsAdministrator

<#
.SYNOPSIS
    Detection script for Memory-Leak-Lsaiso trigger.

.DESCRIPTION
    This script detects LSA Isolation process memory leak affecting system performance.
    
    Impact: 180 systems affected (55% of enterprise fleet)
    Priority: HIGH
    
.PARAMETER ReportPath
    Path to save diagnostic report

.EXAMPLE
    .\Detect-MemoryLeakLsaiso.ps1
    Run diagnostic scan

.NOTES
    File Name: Detect-MemoryLeakLsaiso.ps1
    Version: 1.0
    Date: 2025-07-01
    Author: Wesley Ellis (Wesley.Ellis@compucom.com)
    Company: CompuCom - SysTrack Automation Team
    
    Trigger: Memory-Leak-Lsaiso
    Systems Affected: 180 (55% impact)
    Priority: HIGH
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$ReportPath = "$env:TEMP\Memory-Leak-Lsaiso-Report-$(Get-Date -Format 'yyyyMMdd-HHmmss').log"
)

# Script metadata
$Script:ScriptVersion = "1.0"
$Script:ScriptDate = "2025-07-01"
$Script:ScriptAuthor = "Wesley Ellis (Wesley.Ellis@compucom.com)"
$Script:TriggerName = "Memory-Leak-Lsaiso"
$Script:SystemsAffected = 180
$Script:ImpactPercentage = 55
$Script:Priority = "HIGH"

# Initialize logging
$Script:LogFile = $ReportPath
$Script:StartTime = Get-Date
$Script:IssuesFound = @()

function Write-Log {
    param(
        [string]$Message,
        [string]$Level = "INFO"
    )
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "[$timestamp] [$Level] $Message"
    Write-Host $logEntry -ForegroundColor $(
        switch ($Level) {
            "ERROR" { "Red" }
            "WARN" { "Yellow" }
            "SUCCESS" { "Green" }
            default { "White" }
        }
    )
    Add-Content -Path $Script:LogFile -Value $logEntry -ErrorAction SilentlyContinue
}

function Test-LsaisoMemoryLeak {
    Write-Log "Analyzing LSA Isolation process memory usage..."
    
    try {
        $memoryIssues = @()
        $memoryThreshold = 300  # MB
        
        # Get all lsaiso processes
        $lsaisoProcesses = Get-Process -Name "lsaiso" -ErrorAction SilentlyContinue
        
        if (-not $lsaisoProcesses) {
            Write-Log "LSA Isolation process not found - system may not use Credential Guard" -Level "WARN"
            return $false
        }
        
        foreach ($process in $lsaisoProcesses) {
            $memoryMB = [math]::Round($process.WorkingSet / 1MB, 2)
            
            # Check for memory leak indicators
            if ($memoryMB -gt $memoryThreshold) {
                $memoryIssues += [PSCustomObject]@{
                    ProcessName = $process.ProcessName
                    PID = $process.Id
                    WorkingSetMB = $memoryMB
                    StartTime = $process.StartTime
                    Issue = "LSA Isolation memory usage exceeds threshold: $memoryMB MB"
                    Severity = "HIGH"
                    Impact = "Authentication performance degraded"
                }
                Write-Log "HIGH: LSA Isolation using $memoryMB MB (threshold: $memoryThreshold MB)" -Level "WARN"
            } else {
                Write-Log "OK: LSA Isolation using $memoryMB MB (within threshold)" -Level "SUCCESS"
            }
        }
        
        $Script:IssuesFound = $memoryIssues
        return $memoryIssues.Count -gt 0
    }
    catch {
        Write-Log "Error analyzing LSA Isolation memory: $($_.Exception.Message)" -Level "ERROR"
        return $false
    }
}

# Main execution
try {
    Write-Log "Starting $Script:TriggerName Detection Script v$Script:ScriptVersion"
    Write-Log "Priority: $Script:Priority | Impact: $Script:ImpactPercentage% | Systems: $Script:SystemsAffected"
    
    $detected = Test-LsaisoMemoryLeak
    
    Write-Log "=== DETECTION SUMMARY ===" -Level "SUCCESS"
    Write-Log "Issues Found: $($Script:IssuesFound.Count)"
    Write-Log "Detection Time: $((Get-Date) - $Script:StartTime)"
    
    if ($detected) { exit 1 } else { exit 0 }
}
catch {
    Write-Log "FATAL ERROR: $($_.Exception.Message)" -Level "ERROR"
    exit 2
}
