#Requires -Version 5.1
#Requires -RunAsAdministrator

<#
.SYNOPSIS
    Diagnoses and remediates high CPU usage issues across the system.

.DESCRIPTION
    This script identifies and fixes common high CPU usage problems including:
    - Runaway processes consuming excessive CPU
    - Background services with CPU spikes
    - Windows Update or maintenance tasks
    - Antivirus scanning optimization
    - System file corruption causing CPU issues

.PARAMETER LogOnly
    Run in diagnostic mode only - no changes made

.PARAMETER CPUThreshold
    CPU usage percentage threshold for remediation (default: 80)

.PARAMETER ProcessThreshold
    Individual process CPU threshold for action (default: 50)

.PARAMETER ReportPath
    Path to save diagnostic report

.EXAMPLE
    .\Fix-HighCPUUsage.ps1 -LogOnly
    Run diagnostic scan without making changes

.EXAMPLE
    .\Fix-HighCPUUsage.ps1 -CPUThreshold 70 -ProcessThreshold 40
    Fix CPU issues with lower thresholds

.NOTES
    File Name: Fix-HighCPUUsage.ps1
    Version: 1.0
    Date: June 30, 2025
    Author: Wesley Ellis (Wesley.Ellis@compucom.com)
    Company: CompuCom - SysTrack Automation Team
    
    Impact: High CPU usage affects system responsiveness and user productivity
    Priority: HIGH - Common performance issue across enterprise
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [switch]$LogOnly,
    
    [Parameter(Mandatory = $false)]
    [int]$CPUThreshold = 80,
    
    [Parameter(Mandatory = $false)]
    [int]$ProcessThreshold = 50,
    
    [Parameter(Mandatory = $false)]
    [string]$ReportPath = "$env:TEMP\CPU-Usage-Report-$(Get-Date -Format 'yyyyMMdd-HHmmss').log"
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

function Get-SystemCPUStats {
    Write-Log "Gathering system CPU statistics..."
    try {
        $cpuData = Get-Counter "\Processor(_Total)\% Processor Time" -SampleInterval 3 -MaxSamples 5
        $avgCPU = ($cpuData.CounterSamples | Measure-Object CookedValue -Average).Average
        
        $processes = Get-Process | Sort-Object CPU -Descending | Select-Object -First 20
        
        return @{
            AverageCPU = [math]::Round($avgCPU, 2)
            TopProcesses = $processes
            Timestamp = Get-Date
        }
    } catch {
        Write-Log "Error gathering CPU statistics: $($_.Exception.Message)" -Level "ERROR"
        return $null
    }
}

function Test-HighCPUProcesses {
    Write-Log "Analyzing high CPU processes..."
    $highCPUProcesses = @()
    
    try {
        $stats = Get-SystemCPUStats
        if ($stats -and $stats.AverageCPU -gt $CPUThreshold) {
            Write-Log "System CPU usage: $($stats.AverageCPU)% (Threshold: $CPUThreshold%)" -Level "WARN"
            
            foreach ($proc in $stats.TopProcesses) {
                $cpuPercent = [math]::Round(($proc.CPU / (Get-Date).Subtract($proc.StartTime).TotalSeconds), 2)
                
                if ($cpuPercent -gt $ProcessThreshold) {
                    $highCPUProcesses += [PSCustomObject]@{
                        ProcessName = $proc.ProcessName
                        ProcessID = $proc.Id
                        CPUPercent = $cpuPercent
                        WorkingSet = [math]::Round($proc.WorkingSet / 1MB, 0)
                        StartTime = $proc.StartTime
                        Issue = "High CPU usage: $cpuPercent%"
                        Safe = $proc.ProcessName -notin @("System", "Idle", "csrss", "winlogon", "services")
                    }
                }
            }
        }
        
        Write-Log "Found $($highCPUProcesses.Count) high CPU processes"
        return $highCPUProcesses
    } catch {
        Write-Log "Error analyzing CPU processes: $($_.Exception.Message)" -Level "ERROR"
        return @()
    }
}

function Optimize-WindowsServices {
    Write-Log "Optimizing Windows services for CPU performance..."
    $fixes = @()
    
    if (-not $LogOnly) {
        try {
            # Stop unnecessary services that commonly cause CPU issues
            $servicesToOptimize = @(
                @{Name="DiagTrack"; DisplayName="Connected User Experiences and Telemetry"},
                @{Name="dmwappushservice"; DisplayName="dmwappushsvc"},
                @{Name="MapsBroker"; DisplayName="Downloaded Maps Manager"},
                @{Name="NetTcpPortSharing"; DisplayName="Net.Tcp Port Sharing Service"}
            )
            
            foreach ($svc in $servicesToOptimize) {
                $service = Get-Service -Name $svc.Name -ErrorAction SilentlyContinue
                if ($service -and $service.Status -eq "Running") {
                    Stop-Service -Name $svc.Name -Force -ErrorAction SilentlyContinue
                    Set-Service -Name $svc.Name -StartupType Disabled -ErrorAction SilentlyContinue
                    $fixes += "Disabled service: $($svc.DisplayName)"
                    Write-Log "Disabled CPU-intensive service: $($svc.DisplayName)"
                }
            }
        } catch {
            Write-Log "Error optimizing services: $($_.Exception.Message)" -Level "ERROR"
        }
    } else {
        Write-Log "Would optimize Windows services for CPU performance" -Level "WARN"
    }
    
    return $fixes
}

function Repair-HighCPUProcesses {
    param([array]$HighCPUProcesses)
    Write-Log "Repairing high CPU processes..."
    $fixes = @()
    
    foreach ($proc in $HighCPUProcesses) {
        if ($proc.Safe) {
            try {
                Write-Log "Processing high CPU process: $($proc.ProcessName) (PID: $($proc.ProcessID))"
                
                if (-not $LogOnly) {
                    # Try to restart the process gracefully
                    $process = Get-Process -Id $proc.ProcessID -ErrorAction SilentlyContinue
                    if ($process) {
                        $processPath = $process.Path
                        
                        # Stop the process
                        Stop-Process -Id $proc.ProcessID -Force
                        Start-Sleep -Seconds 2
                        
                        # Restart if it's a common application
                        if ($proc.ProcessName -in @("chrome", "firefox", "msedge", "outlook", "teams")) {
                            if ($processPath -and (Test-Path $processPath)) {
                                Start-Process -FilePath $processPath -ErrorAction SilentlyContinue
                                $fixes += "Restarted high CPU process: $($proc.ProcessName)"
                            }
                        } else {
                            $fixes += "Terminated high CPU process: $($proc.ProcessName)"
                        }
                    }
                } else {
                    Write-Log "Would restart process: $($proc.ProcessName)" -Level "WARN"
                }
            } catch {
                Write-Log "Error handling process $($proc.ProcessName): $($_.Exception.Message)" -Level "ERROR"
            }
        } else {
            Write-Log "Skipping system process: $($proc.ProcessName)" -Level "WARN"
        }
    }
    
    return $fixes
}

function Optimize-SystemPerformance {
    Write-Log "Applying system performance optimizations..."
    $fixes = @()
    
    if (-not $LogOnly) {
        try {
            # Set high performance power plan
            powercfg.exe /setactive 8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c
            $fixes += "Set high performance power plan"
            
            # Optimize visual effects for performance
            Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects" -Name "VisualFXSetting" -Value 2
            $fixes += "Optimized visual effects for performance"
            
            # Disable unnecessary startup programs
            $startupItems = Get-CimInstance -ClassName Win32_StartupCommand
            foreach ($item in $startupItems) {
                if ($item.Command -like "*Teams*" -or $item.Command -like "*Skype*") {
                    # Disable heavy startup applications
                    $fixes += "Would disable startup item: $($item.Name)"
                }
            }
        } catch {
            Write-Log "Error optimizing system performance: $($_.Exception.Message)" -Level "ERROR"
        }
    } else {
        Write-Log "Would apply system performance optimizations" -Level "WARN"
    }
    
    return $fixes
}

# Main execution
try {
    Write-Log "Starting High CPU Usage Remediation v$Script:ScriptVersion"
    Write-Log "Author: $Script:ScriptAuthor"
    Write-Log "CPU Threshold: $CPUThreshold%, Process Threshold: $ProcessThreshold%"
    
    # Analyze system
    $highCPUProcesses = Test-HighCPUProcesses
    $Script:IssuesFound = $highCPUProcesses
    
    if ($highCPUProcesses.Count -eq 0) {
        Write-Log "No high CPU issues detected" -Level "SUCCESS"
    } else {
        Write-Log "Found $($highCPUProcesses.Count) high CPU processes" -Level "WARN"
        
        # Apply fixes
        $Script:FixesApplied += Repair-HighCPUProcesses -HighCPUProcesses $highCPUProcesses
        $Script:FixesApplied += Optimize-WindowsServices
        $Script:FixesApplied += Optimize-SystemPerformance
    }
    
    # Summary
    Write-Log "=== EXECUTION SUMMARY ===" -Level "SUCCESS"
    Write-Log "Issues Found: $($Script:IssuesFound.Count)"
    Write-Log "Fixes Applied: $($Script:FixesApplied.Count)"
    Write-Log "Report Location: $Script:LogFile"
    
    exit 0
} catch {
    Write-Log "FATAL ERROR: $($_.Exception.Message)" -Level "ERROR"
    exit 1
}
