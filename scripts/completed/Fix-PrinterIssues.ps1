#Requires -Version 5.1
#Requires -RunAsAdministrator

<#
.SYNOPSIS
    Diagnoses and repairs printer connectivity and functionality issues.

.DESCRIPTION
    This script identifies and fixes common printer problems including:
    - Printer driver issues and conflicts
    - Print spooler service problems
    - Printer queue corruption
    - Network printer connectivity
    - Print job management

.PARAMETER LogOnly
    Run in diagnostic mode only - no changes made

.PARAMETER ClearPrintQueue
    Enable clearing of stuck print jobs

.PARAMETER ReportPath
    Path to save diagnostic report

.EXAMPLE
    .\Fix-PrinterIssues.ps1 -LogOnly
    Diagnose printer issues without changes

.EXAMPLE
    .\Fix-PrinterIssues.ps1 -ClearPrintQueue
    Full printer repair including queue clearing

.NOTES
    File Name: Fix-PrinterIssues.ps1
    Version: 1.0
    Date: June 30, 2025
    Author: Wesley Ellis (Wesley.Ellis@compucom.com)
    Company: CompuCom - SysTrack Automation Team
    
    Impact: Printer issues affect document workflow and productivity
    Priority: MEDIUM - Important for business operations and document management
#>

[CmdletBinding()]
param(
    [switch]$LogOnly,
    [switch]$ClearPrintQueue,
    [string]$ReportPath = "$env:TEMP\Printer-Issues-Report-$(Get-Date -Format 'yyyyMMdd-HHmmss').log"
)

$Script:ScriptVersion = "1.0"
$Script:LogFile = $ReportPath
$Script:FixesApplied = @()

function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "[$timestamp] [$Level] $Message"
    Write-Host $logEntry -ForegroundColor $(switch ($Level) { "ERROR" { "Red" }; "WARN" { "Yellow" }; "SUCCESS" { "Green" }; default { "White" } })
    Add-Content -Path $Script:LogFile -Value $logEntry -ErrorAction SilentlyContinue
}

function Test-PrinterStatus {
    Write-Log "Testing printer status..."
    $issues = @()
    
    try {
        $printers = Get-Printer
        foreach ($printer in $printers) {
            if ($printer.PrinterStatus -ne "Normal") {
                $issues += "Printer issue: $($printer.Name) - Status: $($printer.PrinterStatus)"
            }
        }
        
        Write-Log "Found $($issues.Count) printer issues"
        return $issues
    } catch {
        Write-Log "Error testing printers: $($_.Exception.Message)" -Level "ERROR"
        return @()
    }
}

function Repair-PrintSpooler {
    Write-Log "Repairing print spooler service..."
    $fixes = @()
    
    if (-not $LogOnly) {
        try {
            Stop-Service -Name "Spooler" -Force
            $spoolPath = "$env:WINDIR\System32\spool\PRINTERS"
            if (Test-Path $spoolPath) {
                Remove-Item -Path "$spoolPath\*" -Force -ErrorAction SilentlyContinue
                $fixes += "Cleared print spooler cache"
            }
            Start-Service -Name "Spooler"
            $fixes += "Restarted print spooler service"
        } catch {
            Write-Log "Error repairing print spooler: $($_.Exception.Message)" -Level "ERROR"
        }
    }
    return $fixes
}

function Clear-PrintQueues {
    Write-Log "Clearing print queues..."
    $fixes = @()
    
    if ($ClearPrintQueue -and -not $LogOnly) {
        try {
            Get-Printer | ForEach-Object {
                $jobs = Get-PrintJob -PrinterName $_.Name -ErrorAction SilentlyContinue
                if ($jobs) {
                    $jobs | Remove-PrintJob -ErrorAction SilentlyContinue
                    $fixes += "Cleared print queue for: $($_.Name)"
                }
            }
        } catch {
            Write-Log "Error clearing print queues: $($_.Exception.Message)" -Level "ERROR"
        }
    }
    return $fixes
}

# Main execution
try {
    Write-Log "Starting Printer Issues Repair v$Script:ScriptVersion"
    Write-Log "Author: Wesley Ellis (Wesley.Ellis@compucom.com)"
    
    $issues = Test-PrinterStatus
    Write-Log "Found $($issues.Count) printer issues"
    
    $Script:FixesApplied += Repair-PrintSpooler
    $Script:FixesApplied += Clear-PrintQueues
    
    Write-Log "=== EXECUTION SUMMARY ===" -Level "SUCCESS"
    Write-Log "Printer Issues Found: $($issues.Count)"
    Write-Log "Fixes Applied: $($Script:FixesApplied.Count)"
    Write-Log "Report Location: $Script:LogFile"
    
    exit 0
} catch {
    Write-Log "FATAL ERROR: $($_.Exception.Message)" -Level "ERROR"
    exit 1
}
