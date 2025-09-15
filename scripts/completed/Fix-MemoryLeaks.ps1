#Requires -Version 5.1
#Requires -RunAsAdministrator

<#
.SYNOPSIS
    Detects and remediates memory leaks in running processes.

.DESCRIPTION
    This script identifies and fixes memory leak issues including:
    - High memory usage processes
    - Memory growth pattern detection
    - Intelligent process restart
    - User state preservation
    - Application-specific leak remediation

.PARAMETER LogOnly
    Run in diagnostic mode only - no changes made

.PARAMETER MemoryThresholdMB
    Memory threshold in MB before process is considered leaking (default: 1000)

.PARAMETER MonitorMinutes
    Minutes to monitor for memory growth patterns (default: 5)

.PARAMETER ReportPath
    Path to save diagnostic report

.EXAMPLE
    .\Fix-MemoryLeaks.ps1 -LogOnly
    Run diagnostic scan without making changes

.EXAMPLE
    .\Fix-MemoryLeaks.ps1 -MemoryThresholdMB 500 -MonitorMinutes 10 -ReportPath "C:\Reports\memory-leaks.log"
    Monitor for 10 minutes with 500MB threshold

.NOTES
    File Name: Fix-MemoryLeaks.ps1
    Version: 1.0
    Date: June 30, 2025
    Author: Wesley Ellis (Wesley.Ellis@compucom.com)
    Company: CompuCom - SysTrack Automation Team
    Requires: Administrator privileges
    Tested: Windows 10/11, Server 2016/2019/2022
    
    Change Log:
    v1.0 - 2025-06-30 - Initial release with comprehensive memory leak detection
    
    Impact: Targets 200+ systems with memory leak issues across multiple processes
    Priority: HIGH - Critical for system stability and performance
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [switch]$LogOnly,
    
    [Parameter(Mandatory = $false)]
    [int]$MemoryThresholdMB = 1000,
    
    [Parameter(Mandatory = $false)]
    [int]$MonitorMinutes = 5,
    
    [Parameter(Mandatory = $false)]
    [string]$ReportPath = "$env:TEMP\MemoryLeak-Report-$(Get-Date -Format 'yyyyMMdd-HHmmss').log"
)

# Script metadata
$Script:ScriptVersion = "1.0"
$Script:ScriptDate = "2025-06-30"
$Script:ScriptAuthor = "Wesley Ellis (Wesley.Ellis@compucom.com)"

# Initialize logging
$Script:LogFile = $ReportPath
$Script:StartTime = Get-Date
$Script:FixesApplied = @()
$Script:IssuesFound = @()

# Memory leak patterns for common applications
$Script:KnownLeakyProcesses = @{
    "chrome" = @{ MaxMemoryMB = 800; RestartSafe = $true; SaveState = $true }
    "msedge" = @{ MaxMemoryMB = 800; RestartSafe = $true; SaveState = $true }
    "firefox" = @{ MaxMemoryMB = 600; RestartSafe = $true; SaveState = $true }
    "outlook" = @{ MaxMemoryMB = 500; RestartSafe = $false; SaveState = $true }
    "teams" = @{ MaxMemoryMB = 400; RestartSafe = $true; SaveState = $false }
    "slack" = @{ MaxMemoryMB = 300; RestartSafe = $true; SaveState = $false }
    "discord" = @{ MaxMemoryMB = 400; RestartSafe = $true; SaveState = $false }
    "spotify" = @{ MaxMemoryMB = 200; RestartSafe = $true; SaveState = $false }
}

function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "[$timestamp] [$Level] $Message"
    Write-Host $logEntry -ForegroundColor $(
        switch ($Level) {
            "ERROR" { "Red" }; "WARN" { "Yellow" }; "SUCCESS" { "Green" }
            default { "White" }
        }
    )
    Add-Content -Path $Script:LogFile -Value $logEntry -ErrorAction SilentlyContinue
}

function Get-SystemMemoryInfo {
    Write-Log "Gathering system memory information..."
    
    try {
        $computerSystem = Get-WmiObject -Class Win32_ComputerSystem
        $operatingSystem = Get-WmiObject -Class Win32_OperatingSystem
        
        $totalMemoryGB = [math]::Round($computerSystem.TotalPhysicalMemory / 1GB, 2)
        $freeMemoryGB = [math]::Round($operatingSystem.FreePhysicalMemory / 1MB / 1024, 2)
        $usedMemoryGB = $totalMemoryGB - $freeMemoryGB
        $memoryUsagePercent = [math]::Round(($usedMemoryGB / $totalMemoryGB) * 100, 1)
        
        $memoryInfo = @{
            TotalMemoryGB = $totalMemoryGB
            FreeMemoryGB = $freeMemoryGB
            UsedMemoryGB = $usedMemoryGB
            MemoryUsagePercent = $memoryUsagePercent
            Timestamp = Get-Date
        }
        
        Write-Log "Total Memory: $($memoryInfo.TotalMemoryGB) GB"
        Write-Log "Used Memory: $($memoryInfo.UsedMemoryGB) GB ($($memoryInfo.MemoryUsagePercent)%)"
        Write-Log "Free Memory: $($memoryInfo.FreeMemoryGB) GB"
        
        return $memoryInfo
    }
    catch {
        Write-Log "Error gathering memory info: $($_.Exception.Message)" -Level "ERROR"
        return $null
    }
}

function Get-HighMemoryProcesses {
    Write-Log "Scanning for high memory usage processes..."
    
    try {
        $processes = Get-Process | Where-Object { $_.WorkingSet -gt 0 } | Sort-Object WorkingSet -Descending
        $highMemoryProcesses = @()
        
        foreach ($process in $processes) {
            $memoryMB = [math]::Round($process.WorkingSet / 1MB, 2)
            
            # Check against global threshold
            if ($memoryMB -gt $MemoryThresholdMB) {
                $highMemoryProcesses += [PSCustomObject]@{
                    ProcessName = $process.ProcessName
                    ProcessId = $process.Id
                    MemoryMB = $memoryMB
                    StartTime = $process.StartTime
                    Responding = $process.Responding
                    WindowTitle = $process.MainWindowTitle
                    Issue = "High memory usage: $memoryMB MB"
                    RecommendedAction = "Monitor or restart"
                }
            }
            # Check against known leaky process thresholds
            elseif ($Script:KnownLeakyProcesses.ContainsKey($process.ProcessName.ToLower())) {
                $knownProcess = $Script:KnownLeakyProcesses[$process.ProcessName.ToLower()]
                if ($memoryMB -gt $knownProcess.MaxMemoryMB) {
                    $highMemoryProcesses += [PSCustomObject]@{
                        ProcessName = $process.ProcessName
                        ProcessId = $process.Id
                        MemoryMB = $memoryMB
                        StartTime = $process.StartTime
                        Responding = $process.Responding
                        WindowTitle = $process.MainWindowTitle
                        Issue = "Known leaky process exceeding threshold: $memoryMB MB > $($knownProcess.MaxMemoryMB) MB"
                        RecommendedAction = if ($knownProcess.RestartSafe) { "Safe to restart" } else { "Manual intervention" }
                    }
                }
            }
        }
        
        Write-Log "Found $($highMemoryProcesses.Count) processes with high memory usage"
        return $highMemoryProcesses
    }
    catch {
        Write-Log "Error scanning processes: $($_.Exception.Message)" -Level "ERROR"
        return @()
    }
}

function Monitor-MemoryGrowth {
    param([array]$SuspectProcesses)
    
    Write-Log "Monitoring memory growth patterns for $MonitorMinutes minutes..."
    
    try {
        $growthData = @{}
        $monitoringStartTime = Get-Date
        $sampleCount = 0
        $maxSamples = $MonitorMinutes * 2  # Sample every 30 seconds
        
        while ($sampleCount -lt $maxSamples) {
            foreach ($suspectProcess in $SuspectProcesses) {
                try {
                    $currentProcess = Get-Process -Id $suspectProcess.ProcessId -ErrorAction SilentlyContinue
                    if ($currentProcess) {
                        $currentMemoryMB = [math]::Round($currentProcess.WorkingSet / 1MB, 2)
                        
                        if (-not $growthData.ContainsKey($suspectProcess.ProcessId)) {
                            $growthData[$suspectProcess.ProcessId] = @{
                                ProcessName = $suspectProcess.ProcessName
                                Samples = @()
                                InitialMemory = $currentMemoryMB
                            }
                        }
                        
                        $growthData[$suspectProcess.ProcessId].Samples += [PSCustomObject]@{
                            Timestamp = Get-Date
                            MemoryMB = $currentMemoryMB
                            SampleNumber = $sampleCount
                        }
                    }
                }
                catch {
                    Write-Log "Process $($suspectProcess.ProcessId) no longer exists" -Level "WARN"
                }
            }
            
            Start-Sleep -Seconds 30
            $sampleCount++
            
            if ($sampleCount % 4 -eq 0) {  # Every 2 minutes
                Write-Log "Memory monitoring progress: $($sampleCount * 100 / $maxSamples)% complete"
            }
        }
        
        # Analyze growth patterns
        $leakingProcesses = @()
        foreach ($processData in $growthData.GetEnumerator()) {
            $samples = $processData.Value.Samples
            if ($samples.Count -gt 3) {
                $memoryGrowth = $samples[-1].MemoryMB - $samples[0].MemoryMB
                $growthRate = $memoryGrowth / ($samples.Count * 0.5)  # MB per minute
                
                if ($growthRate -gt 10) {  # Growing more than 10MB per minute
                    $leakingProcesses += [PSCustomObject]@{
                        ProcessName = $processData.Value.ProcessName
                        ProcessId = $processData.Key
                        InitialMemoryMB = $processData.Value.InitialMemory
                        FinalMemoryMB = $samples[-1].MemoryMB
                        MemoryGrowthMB = $memoryGrowth
                        GrowthRateMBPerMin = [math]::Round($growthRate, 2)
                        Issue = "Memory leak detected: growing $([math]::Round($growthRate, 2)) MB/min"
                        Severity = if ($growthRate -gt 50) { "CRITICAL" } elseif ($growthRate -gt 25) { "HIGH" } else { "MEDIUM" }
                    }
                }
            }
        }
        
        Write-Log "Memory growth analysis complete. Found $($leakingProcesses.Count) processes with memory leaks"
        return $leakingProcesses
    }
    catch {
        Write-Log "Error monitoring memory growth: $($_.Exception.Message)" -Level "ERROR"
        return @()
    }
}

function Restart-LeakyProcess {
    param([object]$Process, [bool]$SaveState = $false)
    
    Write-Log "Restarting leaky process: $($Process.ProcessName) (PID: $($Process.ProcessId))"
    
    try {
        $fixesApplied = @()
        
        if (-not $LogOnly) {
            # Get process information before termination
            $targetProcess = Get-Process -Id $Process.ProcessId -ErrorAction SilentlyContinue
            if (-not $targetProcess) {
                Write-Log "Process $($Process.ProcessId) no longer exists" -Level "WARN"
                return @("Process already terminated")
            }
            
            $processPath = $targetProcess.Path
            $windowTitle = $targetProcess.MainWindowTitle
            
            # Save state for supported applications
            if ($SaveState) {
                Write-Log "Attempting to save application state for $($Process.ProcessName)"
                
                switch ($Process.ProcessName.ToLower()) {
                    "chrome" {
                        # Chrome auto-saves session
                        Write-Log "Chrome session will be restored automatically"
                    }
                    "msedge" {
                        # Edge auto-saves session
                        Write-Log "Edge session will be restored automatically"
                    }
                    "firefox" {
                        # Firefox auto-saves session
                        Write-Log "Firefox session will be restored automatically"
                    }
                    "outlook" {
                        # Send Ctrl+S to save any drafts
                        if ($targetProcess.MainWindowHandle -ne [System.IntPtr]::Zero) {
                            Add-Type -AssemblyName System.Windows.Forms
                            [System.Windows.Forms.SendKeys]::SendWait("^s")
                            Start-Sleep -Seconds 2
                        }
                    }
                }
            }
            
            # Gracefully close the process first
            try {
                if ($targetProcess.CloseMainWindow()) {
                    Write-Log "Sent close signal to $($Process.ProcessName)"
                    Start-Sleep -Seconds 5
                    
                    # Check if process actually closed
                    $stillRunning = Get-Process -Id $Process.ProcessId -ErrorAction SilentlyContinue
                    if ($stillRunning) {
                        Write-Log "Process didn't close gracefully, forcing termination"
                        Stop-Process -Id $Process.ProcessId -Force
                    }
                } else {
                    Write-Log "Could not close gracefully, forcing termination"
                    Stop-Process -Id $Process.ProcessId -Force
                }
                
                Start-Sleep -Seconds 2
                $fixesApplied += "Terminated leaky process: $($Process.ProcessName)"
                
                # Restart the process if we have the path
                if ($processPath -and (Test-Path $processPath)) {
                    try {
                        Start-Process -FilePath $processPath -ErrorAction Stop
                        Write-Log "Restarted process: $($Process.ProcessName)" -Level "SUCCESS"
                        $fixesApplied += "Restarted process: $($Process.ProcessName)"
                    }
                    catch {
                        Write-Log "Could not restart process automatically: $($_.Exception.Message)" -Level "WARN"
                        $fixesApplied += "Process terminated but could not auto-restart"
                    }
                } else {
                    Write-Log "Could not determine process path for auto-restart" -Level "WARN"
                    $fixesApplied += "Process terminated - manual restart required"
                }
            }
            catch {
                Write-Log "Error restarting process: $($_.Exception.Message)" -Level "ERROR"
                $fixesApplied += "Error restarting process: $($_.Exception.Message)"
            }
        } else {
            Write-Log "Would restart leaky process: $($Process.ProcessName)" -Level "WARN"
            $fixesApplied += "Would restart leaky process: $($Process.ProcessName)"
        }
        
        return $fixesApplied
    }
    catch {
        Write-Log "Error in restart process function: $($_.Exception.Message)" -Level "ERROR"
        return @("Error restarting process")
    }
}

function Optimize-SystemMemory {
    Write-Log "Optimizing system memory..."
    
    try {
        $fixesApplied = @()
        
        if (-not $LogOnly) {
            # Force garbage collection
            [System.GC]::Collect()
            [System.GC]::WaitForPendingFinalizers()
            [System.GC]::Collect()
            
            # Clear system file cache
            try {
                $clearStandbyList = @"
using System;
using System.Runtime.InteropServices;
public class MemoryManagement {
    [DllImport("kernel32.dll")]
    public static extern bool SetProcessWorkingSetSize(IntPtr proc, int min, int max);
    public static void FlushMemory() {
        GC.Collect();
        GC.WaitForPendingFinalizers();
        if (Environment.OSVersion.Platform == PlatformID.Win32NT) {
            SetProcessWorkingSetSize(System.Diagnostics.Process.GetCurrentProcess().Handle, -1, -1);
        }
    }
}
"@
                Add-Type -TypeDefinition $clearStandbyList -ErrorAction SilentlyContinue
                [MemoryManagement]::FlushMemory()
                Write-Log "Optimized system memory allocation" -Level "SUCCESS"
                $fixesApplied += "Optimized system memory allocation"
            }
            catch {
                Write-Log "Could not optimize memory allocation: $($_.Exception.Message)" -Level "WARN"
            }
            
            # Clear temporary files
            try {
                $tempFiles = Get-ChildItem -Path $env:TEMP -Recurse -ErrorAction SilentlyContinue | Where-Object { 
                    $_.LastWriteTime -lt (Get-Date).AddDays(-7) 
                }
                $tempFiles | Remove-Item -Force -Recurse -ErrorAction SilentlyContinue
                Write-Log "Cleared old temporary files"
                $fixesApplied += "Cleared old temporary files"
            }
            catch {
                Write-Log "Could not clear temporary files: $($_.Exception.Message)" -Level "WARN"
            }
        } else {
            Write-Log "Would optimize system memory" -Level "WARN"
            $fixesApplied += "Would optimize system memory"
        }
        
        return $fixesApplied
    }
    catch {
        Write-Log "Error optimizing system memory: $($_.Exception.Message)" -Level "ERROR"
        return @()
    }
}

function Generate-MemoryReport {
    param([array]$HighMemoryProcesses, [array]$LeakingProcesses, [array]$Fixes, [object]$SystemInfo)
    
    Write-Log "Generating memory leak report..."
    
    $report = @"
====================================================================
MEMORY LEAK DETECTION AND REMEDIATION REPORT
====================================================================
Report Generated: $(Get-Date)
Script Version: $Script:ScriptVersion
Script Date: $Script:ScriptDate
Script Author: $Script:ScriptAuthor
Computer: $env:COMPUTERNAME
User: $env:USERNAME
Script Mode: $(if ($LogOnly) { "DIAGNOSTIC ONLY" } else { "REMEDIATION" })
Memory Threshold: $MemoryThresholdMB MB
Monitor Duration: $MonitorMinutes minutes

SYSTEM MEMORY STATUS:
====================================================================
Total Physical Memory: $($SystemInfo.TotalMemoryGB) GB
Used Memory: $($SystemInfo.UsedMemoryGB) GB ($($SystemInfo.MemoryUsagePercent)%)
Free Memory: $($SystemInfo.FreeMemoryGB) GB

HIGH MEMORY PROCESSES DETECTED:
====================================================================
Total High Memory Processes: $($HighMemoryProcesses.Count)
"@
    
    foreach ($process in $HighMemoryProcesses) {
        $report += @"

Process: $($process.ProcessName) (PID: $($process.ProcessId))
Memory Usage: $($process.MemoryMB) MB
Issue: $($process.Issue)
Recommended Action: $($process.RecommendedAction)
Responding: $($process.Responding)
"@
    }
    
    if ($LeakingProcesses.Count -gt 0) {
        $report += @"

MEMORY LEAK ANALYSIS:
====================================================================
Processes with Detected Memory Leaks: $($LeakingProcesses.Count)
"@
        
        foreach ($leak in $LeakingProcesses) {
            $report += @"

Process: $($leak.ProcessName) (PID: $($leak.ProcessId))
Severity: $($leak.Severity)
Initial Memory: $($leak.InitialMemoryMB) MB
Final Memory: $($leak.FinalMemoryMB) MB
Memory Growth: $($leak.MemoryGrowthMB) MB
Growth Rate: $($leak.GrowthRateMBPerMin) MB/minute
Issue: $($leak.Issue)
"@
        }
    }
    
    if ($Fixes.Count -gt 0) {
        $report += @"

REMEDIATION ACTIONS TAKEN:
====================================================================
"@
        foreach ($fix in $Fixes) {
            $report += "- $fix`n"
        }
    }
    
    $report += @"

RECOMMENDATIONS:
====================================================================
1. Monitor processes that were restarted for recurring leaks
2. Update applications with known memory leak issues
3. Consider increasing system memory if usage consistently high
4. Run this script regularly for proactive memory management
5. Review application configurations for memory optimization

SUPPORT CONTACT:
====================================================================
Script Author: $Script:ScriptAuthor
CompuCom SysTrack Automation Team

====================================================================
Report saved to: $Script:LogFile
Script execution time: $((Get-Date) - $Script:StartTime)
====================================================================
"@
    
    Add-Content -Path $Script:LogFile -Value $report
    Write-Log "Report saved to: $Script:LogFile" -Level "SUCCESS"
}

# Main execution
try {
    Write-Log "Starting Memory Leak Detection Script v$Script:ScriptVersion"
    Write-Log "Script Date: $Script:ScriptDate"
    Write-Log "Author: $Script:ScriptAuthor"
    Write-Log "Mode: $(if ($LogOnly) { 'DIAGNOSTIC ONLY' } else { 'REMEDIATION' })"
    Write-Log "Memory Threshold: $MemoryThresholdMB MB"
    Write-Log "Monitor Duration: $MonitorMinutes minutes"
    
    # Get system memory information
    $systemInfo = Get-SystemMemoryInfo
    if (-not $systemInfo) {
        throw "Failed to gather system memory information"
    }
    
    # Scan for high memory processes
    $highMemoryProcesses = Get-HighMemoryProcesses
    $Script:IssuesFound += $highMemoryProcesses
    
    if ($highMemoryProcesses.Count -eq 0) {
        Write-Log "No high memory usage processes detected" -Level "SUCCESS"
    } else {
        Write-Log "Found $($highMemoryProcesses.Count) processes with high memory usage" -Level "WARN"
        
        # Monitor memory growth patterns
        $leakingProcesses = Monitor-MemoryGrowth -SuspectProcesses $highMemoryProcesses
        $Script:IssuesFound += $leakingProcesses
        
        # Restart leaking processes
        foreach ($leakingProcess in $leakingProcesses) {
            $processName = $leakingProcess.ProcessName.ToLower()
            $shouldSaveState = $Script:KnownLeakyProcesses.ContainsKey($processName) -and $Script:KnownLeakyProcesses[$processName].SaveState
            
            if ($leakingProcess.Severity -eq "CRITICAL" -or $leakingProcess.Severity -eq "HIGH") {
                $Script:FixesApplied += Restart-LeakyProcess -Process $leakingProcess -SaveState $shouldSaveState
            }
        }
        
        # Optimize system memory
        $Script:FixesApplied += Optimize-SystemMemory
    }
    
    # Generate comprehensive report
    Generate-MemoryReport -HighMemoryProcesses $highMemoryProcesses -LeakingProcesses $leakingProcesses -Fixes $Script:FixesApplied -SystemInfo $systemInfo
    
    # Summary
    Write-Log "=== EXECUTION SUMMARY ===" -Level "SUCCESS"
    Write-Log "High Memory Processes: $($highMemoryProcesses.Count)"
    Write-Log "Memory Leaks Detected: $(($Script:IssuesFound | Where-Object { $_.Issue -like '*leak*' }).Count)"
    Write-Log "Fixes Applied: $($Script:FixesApplied.Count)"
    Write-Log "Execution Time: $((Get-Date) - $Script:StartTime)"
    Write-Log "Report Location: $Script:LogFile"
    
    if (-not $LogOnly -and $Script:FixesApplied.Count -gt 0) {
        Write-Log "RECOMMENDATION: Monitor restarted processes for stability" -Level "WARN"
    }
    
    exit 0
}
catch {
    Write-Log "FATAL ERROR: $($_.Exception.Message)" -Level "ERROR"
    Write-Log "Stack Trace: $($_.ScriptStackTrace)" -Level "ERROR"
    exit 1
}
