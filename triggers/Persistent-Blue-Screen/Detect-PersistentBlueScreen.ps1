#Requires -Version 5.1
#Requires -RunAsAdministrator

<#
.SYNOPSIS
    Detection script for Persistent-Blue-Screen trigger.

.DESCRIPTION
    This script detects recurring system crashes and blue screens.
    
    Impact: 15 systems affected (100% of enterprise fleet)
    Priority: CRITICAL

.PARAMETER DaysToAnalyze
    Number of days to analyze for blue screen events (default: 7)

.PARAMETER CrashThreshold
    Number of crashes that constitute "persistent" (default: 2)

.PARAMETER ReportPath
    Path to save diagnostic report

.EXAMPLE
    .\Detect-PersistentBlueScreen.ps1
    Run diagnostic scan for blue screens in last 7 days

.EXAMPLE
    .\Detect-PersistentBlueScreen.ps1 -DaysToAnalyze 14 -CrashThreshold 1
    Check for any blue screens in last 14 days

.NOTES
    File Name: Detect-PersistentBlueScreen.ps1
    Version: 1.0
    Date: 2025-07-01
    Author: Wesley Ellis (Wesley.Ellis@compucom.com)
    Company: CompuCom - SysTrack Automation Team
    Requires: Administrator privileges
    Tested: Windows 10/11, Server 2016/2019/2022
    
    Trigger: Persistent-Blue-Screen
    Systems Affected: 15 (100% impact)
    Priority: CRITICAL
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [int]$DaysToAnalyze = 7,
    
    [Parameter(Mandatory = $false)]
    [int]$CrashThreshold = 2,
    
    [Parameter(Mandatory = $false)]
    [string]$ReportPath = "$env:TEMP\Persistent-Blue-Screen-Report-$(Get-Date -Format 'yyyyMMdd-HHmmss').log"
)

# Script metadata
$Script:ScriptVersion = "1.0"
$Script:ScriptDate = "2025-07-01"
$Script:ScriptAuthor = "Wesley Ellis (Wesley.Ellis@compucom.com)"
$Script:TriggerName = "Persistent-Blue-Screen"
$Script:SystemsAffected = 15
$Script:ImpactPercentage = 100
$Script:Priority = "CRITICAL"

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

function Test-BlueScreenEvents {
    Write-Log "Analyzing system for blue screen events in the last $DaysToAnalyze days..."
    
    try {
        $startDate = (Get-Date).AddDays(-$DaysToAnalyze)
        $blueScreenIssues = @()
        
        # Check System Event Log for blue screen events (Event ID 1001, 1002, 6008)
        $bugCheckEvents = @()
        
        try {
            # Event ID 1001 - Windows Error Reporting bugcheck events
            $bugCheckEvents += Get-WinEvent -FilterHashtable @{
                LogName = 'Application'
                ProviderName = 'Windows Error Reporting'
                StartTime = $startDate
                ID = 1001
            } -ErrorAction SilentlyContinue | Where-Object { 
                $_.Message -like "*bugcheck*" -or $_.Message -like "*BSOD*" -or $_.Message -like "*Blue Screen*"
            }
            
            # Event ID 6008 - Unexpected shutdown
            $bugCheckEvents += Get-WinEvent -FilterHashtable @{
                LogName = 'System'
                StartTime = $startDate
                ID = 6008
            } -ErrorAction SilentlyContinue
            
            # Event ID 41 - Kernel-Power critical error (unexpected shutdown)
            $bugCheckEvents += Get-WinEvent -FilterHashtable @{
                LogName = 'System'
                ProviderName = 'Microsoft-Windows-Kernel-Power'
                StartTime = $startDate
                ID = 41
            } -ErrorAction SilentlyContinue
            
            # Event ID 1074 - System shutdown initiated
            $shutdownEvents = Get-WinEvent -FilterHashtable @{
                LogName = 'System'
                ProviderName = 'User32'
                StartTime = $startDate
                ID = 1074
            } -ErrorAction SilentlyContinue | Where-Object {
                $_.Message -like "*unexpected*" -or $_.Message -like "*critical*"
            }
            
            $bugCheckEvents += $shutdownEvents
            
        }
        catch {
            Write-Log "Error accessing Windows Event Logs: $($_.Exception.Message)" -Level "WARN"
        }
        
        # Group events by date to identify patterns
        $eventsByDate = $bugCheckEvents | Group-Object { $_.TimeCreated.Date }
        
        Write-Log "Found $($bugCheckEvents.Count) potential crash events in $($eventsByDate.Count) days"
        
        if ($bugCheckEvents.Count -ge $CrashThreshold) {
            foreach ($event in $bugCheckEvents | Sort-Object TimeCreated -Descending) {
                $blueScreenIssues += [PSCustomObject]@{
                    EventTime = $event.TimeCreated
                    EventID = $event.Id
                    LogName = $event.LogName
                    Provider = $event.ProviderName
                    Level = $event.LevelDisplayName
                    Message = $event.Message.Substring(0, [Math]::Min(200, $event.Message.Length))
                    Issue = "System crash/blue screen detected"
                    Severity = "CRITICAL"
                }
                Write-Log "Blue screen event: $($event.TimeCreated) - Event ID $($event.Id)" -Level "ERROR"
            }
        }
        
        # Check for dump files
        $dumpFiles = @()
        $dumpPaths = @(
            "$env:SystemRoot\MEMORY.DMP",
            "$env:SystemRoot\Minidump\*.dmp"
        )
        
        foreach ($path in $dumpPaths) {
            try {
                $dumps = Get-ChildItem -Path $path -ErrorAction SilentlyContinue | Where-Object { 
                    $_.LastWriteTime -gt $startDate 
                }
                $dumpFiles += $dumps
            }
            catch {
                # Path doesn't exist or access denied
            }
        }
        
        if ($dumpFiles) {
            Write-Log "Found $($dumpFiles.Count) crash dump files:"
            foreach ($dump in $dumpFiles | Sort-Object LastWriteTime -Descending) {
                Write-Log "  - $($dump.FullName) ($(($dump.Length / 1MB).ToString('F1')) MB, $($dump.LastWriteTime))"
                
                $blueScreenIssues += [PSCustomObject]@{
                    EventTime = $dump.LastWriteTime
                    EventID = "DumpFile"
                    LogName = "FileSystem"
                    Provider = "CrashDump"
                    Level = "Critical"
                    Message = "Crash dump file: $($dump.Name) ($(($dump.Length / 1MB).ToString('F1')) MB)"
                    Issue = "Crash dump file indicates blue screen"
                    Severity = "CRITICAL"
                    FilePath = $dump.FullName
                }
            }
        }
        
        # Check reliability history
        try {
            $reliabilityData = Get-WmiObject -Class Win32_ReliabilityStabilityMetrics | Where-Object {
                $_.TimeGenerated -gt $startDate.ToString("yyyyMMddHHmmss.ffffff+000")
            } | Sort-Object TimeGenerated -Descending
            
            $criticalEvents = $reliabilityData | Where-Object { 
                $_.SystemStabilityIndex -lt 5.0  # Low stability score
            }
            
            if ($criticalEvents) {
                Write-Log "Found $($criticalEvents.Count) days with low system stability (< 5.0)"
                foreach ($event in $criticalEvents | Select-Object -First 5) {
                    Write-Log "  - $(([WMI]'').ConvertToDateTime($event.TimeGenerated)): Stability Index $($event.SystemStabilityIndex)"
                }
            }
        }
        catch {
            Write-Log "Could not access reliability data: $($_.Exception.Message)" -Level "WARN"
        }
        
        # Check for recent driver issues
        try {
            $driverEvents = Get-WinEvent -FilterHashtable @{
                LogName = 'System'
                StartTime = $startDate
                Level = 1, 2  # Critical and Error levels
            } -ErrorAction SilentlyContinue | Where-Object {
                $_.Message -like "*driver*" -or $_.Message -like "*IRQL*" -or $_.Message -like "*PAGE_FAULT*"
            }
            
            if ($driverEvents) {
                Write-Log "Found $($driverEvents.Count) driver-related critical events"
                foreach ($driverEvent in $driverEvents | Select-Object -First 3) {
                    Write-Log "  - $($driverEvent.TimeCreated): $($driverEvent.LevelDisplayName) - Provider: $($driverEvent.ProviderName)"
                }
            }
        }
        catch {
            Write-Log "Could not check driver events: $($_.Exception.Message)" -Level "WARN"
        }
        
        $Script:IssuesFound = $blueScreenIssues
        return $blueScreenIssues.Count -gt 0
    }
    catch {
        Write-Log "Error analyzing blue screen events: $($_.Exception.Message)" -Level "ERROR"
        return $false
    }
}

function Get-SystemStabilityInfo {
    Write-Log "Gathering system stability information..."
    
    try {
        # Check last boot time
        $lastBoot = (Get-WmiObject Win32_OperatingSystem).ConvertToDateTime((Get-WmiObject Win32_OperatingSystem).LastBootUpTime)
        $uptime = (Get-Date) - $lastBoot
        Write-Log "System last booted: $lastBoot (uptime: $($uptime.Days) days, $($uptime.Hours) hours)"
        
        # Check for pending reboot
        $pendingReboot = $false
        
        # Check registry for pending reboot flags
        $rebootKeys = @(
            "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired",
            "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending",
            "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\PendingFileRenameOperations"
        )
        
        foreach ($key in $rebootKeys) {
            if (Test-Path $key) {
                $pendingReboot = $true
                Write-Log "Pending reboot detected: $key" -Level "WARN"
            }
        }
        
        if ($pendingReboot) {
            Write-Log "SYSTEM REQUIRES REBOOT - this may resolve stability issues" -Level "WARN"
        }
        
        # Check system memory
        $memory = Get-WmiObject Win32_ComputerSystem
        $totalMemoryGB = [math]::Round($memory.TotalPhysicalMemory / 1GB, 2)
        Write-Log "Total system memory: $totalMemoryGB GB"
        
        # Check for memory errors
        try {
            $memoryEvents = Get-WinEvent -FilterHashtable @{
                LogName = 'System'
                StartTime = (Get-Date).AddDays(-$DaysToAnalyze)
                ID = 2, 3  # Memory hardware errors
            } -ErrorAction SilentlyContinue
            
            if ($memoryEvents) {
                Write-Log "Found $($memoryEvents.Count) memory-related errors" -Level "WARN"
            }
        }
        catch {
            # No memory events or access issues
        }
        
        # Check hard drive health
        try {
            $drives = Get-WmiObject -Class Win32_LogicalDisk | Where-Object { $_.DriveType -eq 3 }
            foreach ($drive in $drives) {
                $freeSpacePercent = [math]::Round(($drive.FreeSpace / $drive.Size) * 100, 1)
                Write-Log "Drive $($drive.DeviceID) free space: $freeSpacePercent%"
                
                if ($freeSpacePercent -lt 10) {
                    Write-Log "LOW DISK SPACE WARNING: Drive $($drive.DeviceID) only has $freeSpacePercent% free" -Level "WARN"
                }
            }
        }
        catch {
            Write-Log "Could not check drive space: $($_.Exception.Message)" -Level "WARN"
        }
        
        return $true
    }
    catch {
        Write-Log "Error gathering stability info: $($_.Exception.Message)" -Level "ERROR"
        return $false
    }
}

function Generate-Report {
    param([array]$Issues)
    
    Write-Log "Generating diagnostic report..."
    
    $report = @"
====================================================================
Persistent-Blue-Screen DETECTION REPORT
====================================================================
Report Generated: $(Get-Date)
Script Version: $Script:ScriptVersion
Computer: $env:COMPUTERNAME
User: $env:USERNAME
Trigger: $Script:TriggerName
Systems Affected: $Script:SystemsAffected ($Script:ImpactPercentage% impact)
Priority: $Script:Priority

ANALYSIS PARAMETERS:
====================================================================
Days Analyzed: $DaysToAnalyze
Crash Threshold: $CrashThreshold events
Analysis Period: $((Get-Date).AddDays(-$DaysToAnalyze).ToString("yyyy-MM-dd")) to $(Get-Date -Format "yyyy-MM-dd")

DETECTION RESULTS:
====================================================================
Blue Screen Events Found: $($Issues.Count)
Persistent Pattern Detected: $(if ($Issues.Count -ge $CrashThreshold) { "YES - CRITICAL" } else { "NO" })

DETAILED FINDINGS:
====================================================================
"@
    
    foreach ($issue in $Issues | Sort-Object EventTime -Descending) {
        $report += @"

Event Time: $($issue.EventTime)
Event ID: $($issue.EventID)
Log Source: $($issue.LogName)
Provider: $($issue.Provider)
Severity: $($issue.Level)
Description: $($issue.Message)
$(if ($issue.FilePath) { "File Path: $($issue.FilePath)" })
"@
    }
    
    $report += @"

SYSTEM STABILITY ANALYSIS:
====================================================================
OS Version: $((Get-WmiObject Win32_OperatingSystem).Caption)
Last Boot: $((Get-WmiObject Win32_OperatingSystem).ConvertToDateTime((Get-WmiObject Win32_OperatingSystem).LastBootUpTime))
System Uptime: $((Get-Date) - (Get-WmiObject Win32_OperatingSystem).ConvertToDateTime((Get-WmiObject Win32_OperatingSystem).LastBootUpTime))
Total Memory: $([math]::Round((Get-WmiObject Win32_ComputerSystem).TotalPhysicalMemory / 1GB, 2)) GB

BUSINESS IMPACT ASSESSMENT:
====================================================================
$(if ($Issues.Count -ge $CrashThreshold) {
"CRITICAL IMPACT DETECTED:
- System reliability severely compromised
- Data loss risk from unexpected shutdowns
- User productivity significantly impacted
- Potential hardware damage from repeated crashes
- Support tickets and help desk load increased
- Business operations disrupted by system instability"
} else {
"IMPACT ASSESSMENT:
- No persistent blue screen pattern detected
- System appears stable in analyzed timeframe
- Continue monitoring for stability trends
- Proactive maintenance recommended"
})

RECOMMENDATIONS:
====================================================================
$(if ($Issues.Count -ge $CrashThreshold) {
"IMMEDIATE ACTIONS REQUIRED:
1. Run Fix-PersistentBlueScreen.ps1 for automated remediation
2. Update all device drivers, especially graphics and network
3. Run Windows Memory Diagnostic (mdsched.exe)
4. Check hard drive health with CHKDSK /F
5. Review and update BIOS/UEFI firmware
6. Scan for malware and system file corruption
7. Remove recently installed software or hardware
8. Contact hardware vendor if crashes persist"
} else {
"PREVENTIVE MEASURES:
1. Continue monitoring system stability
2. Keep drivers and Windows updates current
3. Perform regular system maintenance
4. Monitor hardware health indicators
5. Maintain adequate free disk space (>15%)
6. Run memory diagnostics quarterly"
})

ESCALATION CRITERIA:
====================================================================
- More than 3 blue screens in 7 days
- Blue screens occurring daily
- System cannot complete startup
- Hardware error messages in event logs
- Memory diagnostic test failures
- Hard drive SMART errors detected

====================================================================
Report saved to: $Script:LogFile
Detection time: $((Get-Date) - $Script:StartTime)
====================================================================
"@
    
    Add-Content -Path $Script:LogFile -Value $report
    Write-Log "Report saved to: $Script:LogFile" -Level "SUCCESS"
}

# Main execution
try {
    Write-Log "Starting Persistent-Blue-Screen Detection Script v$Script:ScriptVersion"
    Write-Log "Priority: $Script:Priority | Impact: $Script:ImpactPercentage% | Systems: $Script:SystemsAffected"
    Write-Log "Analyzing $DaysToAnalyze days for crashes (threshold: $CrashThreshold events)"
    
    $detected = Test-BlueScreenEvents
    
    # Gather additional system stability information
    Get-SystemStabilityInfo
    
    if ($detected) {
        Write-Log "CRITICAL: Persistent blue screen pattern detected!" -Level "ERROR"
        Write-Log "Found $($Script:IssuesFound.Count) crash events in the last $DaysToAnalyze days"
        Write-Log "IMMEDIATE ACTION REQUIRED: System stability severely compromised"
        Write-Log "NEXT STEP: Run Fix-PersistentBlueScreen.ps1 for automated remediation"
    } else {
        Write-Log "No persistent blue screen pattern detected" -Level "SUCCESS"
        Write-Log "System appears stable in the analyzed timeframe"
    }
    
    Generate-Report -Issues $Script:IssuesFound
    
    Write-Log "=== DETECTION SUMMARY ===" -Level "SUCCESS"
    Write-Log "Crash Events Found: $($Script:IssuesFound.Count)"
    Write-Log "Threshold for Concern: $CrashThreshold events"
    Write-Log "Pattern Classification: $(if ($Script:IssuesFound.Count -ge $CrashThreshold) { 'PERSISTENT (CRITICAL)' } else { 'STABLE' })"
    Write-Log "Detection Time: $((Get-Date) - $Script:StartTime)"
    Write-Log "Report Location: $Script:LogFile"
    
    if ($detected) {
        Write-Log "EXIT CODE: 1 (Persistent crashes detected - immediate action required)" -Level "ERROR"
        exit 1  # Issues found
    } else {
        Write-Log "EXIT CODE: 0 (System stable)" -Level "SUCCESS"
        exit 0  # No issues
    }
}
catch {
    Write-Log "FATAL ERROR: $($_.Exception.Message)" -Level "ERROR"
    Write-Log "Stack Trace: $($_.ScriptStackTrace)" -Level "ERROR"
    exit 2  # Error occurred
}
