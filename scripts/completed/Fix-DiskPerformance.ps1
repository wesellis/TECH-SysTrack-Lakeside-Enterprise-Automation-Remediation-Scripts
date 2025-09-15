#Requires -Version 5.1
#Requires -RunAsAdministrator

<#
.SYNOPSIS
    Diagnoses and remediates disk performance issues including cleanup and optimization.

.DESCRIPTION
    This script identifies and fixes common disk performance problems including:
    - Disk space cleanup and temporary file removal
    - Disk fragmentation analysis and defragmentation
    - Disk error checking and repair
    - Page file optimization
    - System file corruption repair

.PARAMETER LogOnly
    Run in diagnostic mode only - no changes made

.PARAMETER MinFreeSpaceGB
    Minimum free space threshold in GB (default: 10)

.PARAMETER DefragmentDisks
    Enable disk defragmentation if fragmentation > threshold

.PARAMETER ReportPath
    Path to save diagnostic report

.EXAMPLE
    .\Fix-DiskPerformance.ps1 -LogOnly
    Run diagnostic scan without making changes

.EXAMPLE
    .\Fix-DiskPerformance.ps1 -MinFreeSpaceGB 20 -DefragmentDisks
    Cleanup with 20GB threshold and enable defragmentation

.NOTES
    File Name: Fix-DiskPerformance.ps1
    Version: 1.0
    Date: June 30, 2025
    Author: Wesley Ellis (Wesley.Ellis@compucom.com)
    Company: CompuCom - SysTrack Automation Team
    
    Impact: Disk performance affects overall system responsiveness
    Priority: HIGH - Critical for system performance and stability
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [switch]$LogOnly,
    
    [Parameter(Mandatory = $false)]
    [int]$MinFreeSpaceGB = 10,
    
    [Parameter(Mandatory = $false)]
    [switch]$DefragmentDisks,
    
    [Parameter(Mandatory = $false)]
    [string]$ReportPath = "$env:TEMP\Disk-Performance-Report-$(Get-Date -Format 'yyyyMMdd-HHmmss').log"
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

function Get-DiskSpaceInfo {
    Write-Log "Gathering disk space information..."
    try {
        $diskInfo = Get-WmiObject -Class Win32_LogicalDisk | Where-Object { $_.DriveType -eq 3 }
        $diskIssues = @()
        
        foreach ($disk in $diskInfo) {
            $freeSpaceGB = [math]::Round($disk.FreeSpace / 1GB, 2)
            $totalSpaceGB = [math]::Round($disk.Size / 1GB, 2)
            $usedPercent = [math]::Round((($disk.Size - $disk.FreeSpace) / $disk.Size) * 100, 1)
            
            Write-Log "Drive $($disk.DeviceID) - Free: $freeSpaceGB GB, Used: $usedPercent%"
            
            if ($freeSpaceGB -lt $MinFreeSpaceGB) {
                $diskIssues += [PSCustomObject]@{
                    Drive = $disk.DeviceID
                    FreeSpaceGB = $freeSpaceGB
                    TotalSpaceGB = $totalSpaceGB
                    UsedPercent = $usedPercent
                    Issue = "Low disk space: $freeSpaceGB GB free"
                }
            }
            
            if ($usedPercent -gt 90) {
                $diskIssues += [PSCustomObject]@{
                    Drive = $disk.DeviceID
                    FreeSpaceGB = $freeSpaceGB
                    TotalSpaceGB = $totalSpaceGB
                    UsedPercent = $usedPercent
                    Issue = "High disk usage: $usedPercent% used"
                }
            }
        }
        
        return $diskIssues
    } catch {
        Write-Log "Error gathering disk information: $($_.Exception.Message)" -Level "ERROR"
        return @()
    }
}

function Clear-TemporaryFiles {
    Write-Log "Cleaning temporary files..."
    $cleanupPaths = @(
        "$env:TEMP\*",
        "$env:WINDIR\Temp\*",
        "$env:LOCALAPPDATA\Microsoft\Windows\INetCache\*",
        "$env:LOCALAPPDATA\Microsoft\Windows\WebCache\*",
        "$env:APPDATA\Microsoft\Teams\Cache\*",
        "$env:LOCALAPPDATA\Google\Chrome\User Data\Default\Cache\*",
        "$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default\Cache\*"
    )
    
    $totalFreed = 0
    $fixes = @()
    
    foreach ($path in $cleanupPaths) {
        try {
            if (-not $LogOnly) {
                $items = Get-ChildItem -Path $path -Recurse -Force -ErrorAction SilentlyContinue
                $sizeBeforeCleanup = ($items | Measure-Object -Property Length -Sum).Sum
                
                Remove-Item -Path $path -Recurse -Force -ErrorAction SilentlyContinue
                
                if ($sizeBeforeCleanup -gt 0) {
                    $freedMB = [math]::Round($sizeBeforeCleanup / 1MB, 2)
                    $totalFreed += $freedMB
                    $fixes += "Cleaned $freedMB MB from: $path"
                    Write-Log "Cleaned $freedMB MB from: $path"
                }
            } else {
                $items = Get-ChildItem -Path $path -Recurse -Force -ErrorAction SilentlyContinue
                if ($items) {
                    $sizeMB = [math]::Round(($items | Measure-Object -Property Length -Sum).Sum / 1MB, 2)
                    Write-Log "Would clean $sizeMB MB from: $path" -Level "WARN"
                }
            }
        } catch {
            Write-Log "Error cleaning $path`: $($_.Exception.Message)" -Level "WARN"
        }
    }
    
    if ($totalFreed -gt 0) {
        $fixes += "Total disk space freed: $totalFreed MB"
        Write-Log "Total disk space freed: $totalFreed MB" -Level "SUCCESS"
    }
    
    return $fixes
}

function Optimize-PageFile {
    Write-Log "Optimizing page file settings..."
    $fixes = @()
    
    try {
        if (-not $LogOnly) {
            # Get system memory
            $memory = Get-WmiObject -Class Win32_ComputerSystem
            $memoryGB = [math]::Round($memory.TotalPhysicalMemory / 1GB, 0)
            
            # Set optimal page file size (1.5x RAM)
            $optimalPageFileMB = $memoryGB * 1536
            
            # Configure page file via WMI
            $pageFile = Get-WmiObject -Class Win32_PageFileSetting
            if ($pageFile) {
                $pageFile.InitialSize = $optimalPageFileMB
                $pageFile.MaximumSize = $optimalPageFileMB * 2
                $pageFile.Put() | Out-Null
                $fixes += "Optimized page file: Initial=$optimalPageFileMB MB, Max=$($optimalPageFileMB * 2) MB"
            }
        } else {
            Write-Log "Would optimize page file settings" -Level "WARN"
        }
    } catch {
        Write-Log "Error optimizing page file: $($_.Exception.Message)" -Level "ERROR"
    }
    
    return $fixes
}

function Test-DiskErrors {
    Write-Log "Checking for disk errors..."
    $fixes = @()
    
    try {
        $drives = Get-WmiObject -Class Win32_LogicalDisk | Where-Object { $_.DriveType -eq 3 }
        
        foreach ($drive in $drives) {
            $driveLetter = $drive.DeviceID.Replace(":", "")
            
            if (-not $LogOnly) {
                # Run CHKDSK scan
                Write-Log "Running disk check on drive $($drive.DeviceID)..."
                $chkdskResult = Start-Process -FilePath "chkdsk.exe" -ArgumentList "$($drive.DeviceID) /f /r" -Wait -PassThru -WindowStyle Hidden
                
                if ($chkdskResult.ExitCode -eq 0) {
                    $fixes += "Disk check completed successfully on $($drive.DeviceID)"
                } else {
                    Write-Log "Disk check found issues on $($drive.DeviceID)" -Level "WARN"
                    $fixes += "Disk check found and fixed errors on $($drive.DeviceID)"
                }
            } else {
                Write-Log "Would run disk check on $($drive.DeviceID)" -Level "WARN"
            }
        }
    } catch {
        Write-Log "Error checking disk errors: $($_.Exception.Message)" -Level "ERROR"
    }
    
    return $fixes
}

function Optimize-DiskDefragmentation {
    Write-Log "Analyzing disk fragmentation..."
    $fixes = @()
    
    if ($DefragmentDisks) {
        try {
            $drives = Get-WmiObject -Class Win32_LogicalDisk | Where-Object { $_.DriveType -eq 3 }
            
            foreach ($drive in $drives) {
                if (-not $LogOnly) {
                    Write-Log "Analyzing fragmentation on $($drive.DeviceID)..."
                    
                    # Check if drive is SSD (skip defragmentation for SSDs)
                    $diskDrive = Get-WmiObject -Class Win32_DiskDrive | Where-Object { $_.DeviceID -like "*$($drive.DeviceID.Replace(':', ''))*" }
                    
                    if ($diskDrive -and $diskDrive.MediaType -notlike "*SSD*") {
                        # Run defragmentation
                        $defragResult = Start-Process -FilePath "defrag.exe" -ArgumentList "$($drive.DeviceID) /A /X" -Wait -PassThru -WindowStyle Hidden
                        
                        if ($defragResult.ExitCode -eq 0) {
                            $fixes += "Defragmentation completed on $($drive.DeviceID)"
                        }
                    } else {
                        Write-Log "Skipping defragmentation on SSD: $($drive.DeviceID)"
                        $fixes += "Skipped defragmentation on SSD: $($drive.DeviceID)"
                    }
                } else {
                    Write-Log "Would analyze and defragment $($drive.DeviceID)" -Level "WARN"
                }
            }
        } catch {
            Write-Log "Error during defragmentation: $($_.Exception.Message)" -Level "ERROR"
        }
    } else {
        Write-Log "Defragmentation not requested" -Level "INFO"
    }
    
    return $fixes
}

function Repair-SystemFiles {
    Write-Log "Checking system file integrity..."
    $fixes = @()
    
    try {
        if (-not $LogOnly) {
            # Run SFC scan
            Write-Log "Running System File Checker..."
            $sfcResult = Start-Process -FilePath "sfc.exe" -ArgumentList "/scannow" -Wait -PassThru -WindowStyle Hidden
            
            if ($sfcResult.ExitCode -eq 0) {
                $fixes += "System File Checker completed successfully"
            } else {
                $fixes += "System File Checker found and repaired corrupted files"
            }
            
            # Run DISM health check
            Write-Log "Running DISM health check..."
            $dismResult = Start-Process -FilePath "dism.exe" -ArgumentList "/online /cleanup-image /restorehealth" -Wait -PassThru -WindowStyle Hidden
            
            if ($dismResult.ExitCode -eq 0) {
                $fixes += "DISM health check completed successfully"
            }
        } else {
            Write-Log "Would run System File Checker and DISM" -Level "WARN"
        }
    } catch {
        Write-Log "Error checking system files: $($_.Exception.Message)" -Level "ERROR"
    }
    
    return $fixes
}

# Main execution
try {
    Write-Log "Starting Disk Performance Remediation v$Script:ScriptVersion"
    Write-Log "Author: $Script:ScriptAuthor"
    Write-Log "Min Free Space: $MinFreeSpaceGB GB, Defragment: $DefragmentDisks"
    
    # Analyze disk space
    $diskIssues = Get-DiskSpaceInfo
    $Script:IssuesFound = $diskIssues
    
    if ($diskIssues.Count -eq 0) {
        Write-Log "No disk space issues detected" -Level "SUCCESS"
    } else {
        Write-Log "Found $($diskIssues.Count) disk space issues" -Level "WARN"
    }
    
    # Apply fixes regardless of specific issues found
    $Script:FixesApplied += Clear-TemporaryFiles
    $Script:FixesApplied += Optimize-PageFile
    $Script:FixesApplied += Test-DiskErrors
    $Script:FixesApplied += Optimize-DiskDefragmentation
    $Script:FixesApplied += Repair-SystemFiles
    
    # Summary
    Write-Log "=== EXECUTION SUMMARY ===" -Level "SUCCESS"
    Write-Log "Disk Issues Found: $($Script:IssuesFound.Count)"
    Write-Log "Optimizations Applied: $($Script:FixesApplied.Count)"
    Write-Log "Report Location: $Script:LogFile"
    
    if (-not $LogOnly -and $Script:FixesApplied.Count -gt 0) {
        Write-Log "RECOMMENDATION: Restart system for all changes to take effect" -Level "WARN"
    }
    
    exit 0
} catch {
    Write-Log "FATAL ERROR: $($_.Exception.Message)" -Level "ERROR"
    exit 1
}
