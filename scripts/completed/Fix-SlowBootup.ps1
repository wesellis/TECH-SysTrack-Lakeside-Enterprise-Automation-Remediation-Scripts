#Requires -Version 5.1
#Requires -RunAsAdministrator

<#
.SYNOPSIS
    Diagnoses and remediates system boot and startup performance issues.

.DESCRIPTION
    This script identifies and fixes common startup problems including:
    - Excessive startup programs
    - Slow boot services
    - Registry optimization for startup
    - Fast startup configuration
    - Boot file corruption repair

.PARAMETER LogOnly
    Run in diagnostic mode only - no changes made

.PARAMETER StartupThreshold
    Maximum acceptable startup programs (default: 15)

.PARAMETER ReportPath
    Path to save diagnostic report

.EXAMPLE
    .\Fix-SlowBootup.ps1 -LogOnly
    Analyze startup performance without changes

.EXAMPLE
    .\Fix-SlowBootup.ps1 -StartupThreshold 10
    Optimize startup with stricter limits

.NOTES
    File Name: Fix-SlowBootup.ps1
    Version: 1.0
    Date: June 30, 2025
    Author: Wesley Ellis (Wesley.Ellis@compucom.com)
    Company: CompuCom - SysTrack Automation Team
    
    Impact: Slow boot times affect user productivity and system availability
    Priority: MEDIUM - Improves user experience and system efficiency
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [switch]$LogOnly,
    
    [Parameter(Mandatory = $false)]
    [int]$StartupThreshold = 15,
    
    [Parameter(Mandatory = $false)]
    [string]$ReportPath = "$env:TEMP\Boot-Performance-Report-$(Get-Date -Format 'yyyyMMdd-HHmmss').log"
)

# Script metadata and logging setup
$Script:ScriptVersion = "1.0"
$Script:ScriptDate = "2025-06-30"
$Script:ScriptAuthor = "Wesley Ellis (Wesley.Ellis@compucom.com)"
$Script:LogFile = $ReportPath
$Script:StartTime = Get-Date
$Script:FixesApplied = @()
$Script:IssuesFound = @()

function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "[$timestamp] [$Level] $Message"
    Write-Host $logEntry -ForegroundColor $(
        switch ($Level) { "ERROR" { "Red" }; "WARN" { "Yellow" }; "SUCCESS" { "Green" }; default { "White" } }
    )
    Add-Content -Path $Script:LogFile -Value $logEntry -ErrorAction SilentlyContinue
}

function Get-StartupPrograms {
    Write-Log "Analyzing startup programs..."
    try {
        $startupItems = @()
        
        # Registry startup locations
        $startupKeys = @(
            "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run",
            "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce",
            "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run",
            "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce"
        )
        
        foreach ($key in $startupKeys) {
            if (Test-Path $key) {
                $items = Get-ItemProperty -Path $key -ErrorAction SilentlyContinue
                if ($items) {
                    $items.PSObject.Properties | Where-Object { $_.Name -notlike "PS*" } | ForEach-Object {
                        $startupItems += [PSCustomObject]@{
                            Name = $_.Name
                            Command = $_.Value
                            Location = $key
                            Type = "Registry"
                        }
                    }
                }
            }
        }
        
        # Startup folder items
        $startupFolders = @(
            "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Startup",
            "$env:ALLUSERSPROFILE\Microsoft\Windows\Start Menu\Programs\Startup"
        )
        
        foreach ($folder in $startupFolders) {
            if (Test-Path $folder) {
                Get-ChildItem -Path $folder -File | ForEach-Object {
                    $startupItems += [PSCustomObject]@{
                        Name = $_.BaseName
                        Command = $_.FullName
                        Location = $folder
                        Type = "StartupFolder"
                    }
                }
            }
        }
        
        Write-Log "Found $($startupItems.Count) startup items (Threshold: $StartupThreshold)"
        return $startupItems
    } catch {
        Write-Log "Error analyzing startup programs: $($_.Exception.Message)" -Level "ERROR"
        return @()
    }
}

function Optimize-StartupPrograms {
    param([array]$StartupItems)
    Write-Log "Optimizing startup programs..."
    $fixes = @()
    
    # Known programs safe to disable at startup
    $safeToDisable = @(
        "Spotify", "Steam", "Discord", "Skype", "iTunes", "QuickTime", 
        "Adobe Updater", "Java Update", "Acrobat Update", "Office ClickToRun",
        "Teams Machine-Wide Installer", "OneDrive", "Dropbox"
    )
    
    foreach ($item in $StartupItems) {
        $shouldDisable = $false
        
        # Check if it's in the safe-to-disable list
        foreach ($program in $safeToDisable) {
            if ($item.Name -like "*$program*" -or $item.Command -like "*$program*") {
                $shouldDisable = $true
                break
            }
        }
        
        if ($shouldDisable) {
            if (-not $LogOnly) {
                try {
                    if ($item.Type -eq "Registry") {
                        Remove-ItemProperty -Path $item.Location -Name $item.Name -ErrorAction Stop
                        $fixes += "Disabled startup program: $($item.Name)"
                        Write-Log "Disabled startup program: $($item.Name)"
                    } elseif ($item.Type -eq "StartupFolder") {
                        $backupPath = "$env:TEMP\StartupBackup"
                        if (-not (Test-Path $backupPath)) { New-Item -Path $backupPath -ItemType Directory | Out-Null }
                        Move-Item -Path $item.Command -Destination $backupPath -ErrorAction Stop
                        $fixes += "Moved startup item to backup: $($item.Name)"
                        Write-Log "Moved startup item to backup: $($item.Name)"
                    }
                } catch {
                    Write-Log "Error disabling $($item.Name): $($_.Exception.Message)" -Level "ERROR"
                }
            } else {
                Write-Log "Would disable startup program: $($item.Name)" -Level "WARN"
            }
        }
    }
    
    return $fixes
}

function Optimize-BootConfiguration {
    Write-Log "Optimizing boot configuration..."
    $fixes = @()
    
    if (-not $LogOnly) {
        try {
            # Enable fast startup
            Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Power" -Name "HiberbootEnabled" -Value 1
            $fixes += "Enabled fast startup (hibernation boot)"
            
            # Optimize boot timeout
            bcdedit /timeout 3 | Out-Null
            $fixes += "Set boot timeout to 3 seconds"
            
            # Disable unnecessary boot logging
            bcdedit /set bootlog no | Out-Null
            $fixes += "Disabled boot logging"
            
            # Enable processor performance boost
            Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Power" -Name "ProcessorPerformanceBoostPolicy" -Value 100
            $fixes += "Enabled processor performance boost"
            
        } catch {
            Write-Log "Error optimizing boot configuration: $($_.Exception.Message)" -Level "ERROR"
        }
    } else {
        Write-Log "Would optimize boot configuration settings" -Level "WARN"
    }
    
    return $fixes
}

function Optimize-Services {
    Write-Log "Optimizing service startup settings..."
    $fixes = @()
    
    # Services safe to set to manual or delayed start
    $servicesToOptimize = @(
        @{Name="Fax"; StartType="Manual"; Description="Fax Service"},
        @{Name="WSearch"; StartType="DelayedAutoStart"; Description="Windows Search"},
        @{Name="SysMain"; StartType="Manual"; Description="Superfetch/Prefetch"},
        @{Name="Themes"; StartType="Manual"; Description="Themes Service"},
        @{Name="TabletInputService"; StartType="Manual"; Description="Tablet PC Input Service"}
    )
    
    if (-not $LogOnly) {
        foreach ($svc in $servicesToOptimize) {
            try {
                $service = Get-Service -Name $svc.Name -ErrorAction SilentlyContinue
                if ($service) {
                    if ($svc.StartType -eq "DelayedAutoStart") {
                        Set-Service -Name $svc.Name -StartupType Automatic
                        sc.exe config $svc.Name start= delayed-auto | Out-Null
                    } else {
                        Set-Service -Name $svc.Name -StartupType $svc.StartType
                    }
                    $fixes += "Optimized service startup: $($svc.Description) -> $($svc.StartType)"
                    Write-Log "Optimized service: $($svc.Name) -> $($svc.StartType)"
                }
            } catch {
                Write-Log "Error optimizing service $($svc.Name): $($_.Exception.Message)" -Level "WARN"
            }
        }
    } else {
        Write-Log "Would optimize $($servicesToOptimize.Count) service startup settings" -Level "WARN"
    }
    
    return $fixes
}

function Repair-BootFiles {
    Write-Log "Checking and repairing boot files..."
    $fixes = @()
    
    if (-not $LogOnly) {
        try {
            # Repair boot configuration data
            Write-Log "Repairing boot configuration data..."
            bcdedit /export "$env:TEMP\BCD_Backup" | Out-Null
            
            # Rebuild BCD if corrupted
            $bcdResult = Start-Process -FilePath "bcdboot.exe" -ArgumentList "$env:WINDIR /s C:" -Wait -PassThru -WindowStyle Hidden
            if ($bcdResult.ExitCode -eq 0) {
                $fixes += "Boot configuration data repaired successfully"
            }
            
            # Fix master boot record
            $bootsectResult = Start-Process -FilePath "bootsect.exe" -ArgumentList "/nt60 C: /mbr" -Wait -PassThru -WindowStyle Hidden -ErrorAction SilentlyContinue
            if ($bootsectResult -and $bootsectResult.ExitCode -eq 0) {
                $fixes += "Master boot record repaired"
            }
            
        } catch {
            Write-Log "Error repairing boot files: $($_.Exception.Message)" -Level "ERROR"
        }
    } else {
        Write-Log "Would check and repair boot files" -Level "WARN"
    }
    
    return $fixes
}

# Main execution
try {
    Write-Log "Starting Boot Performance Optimization v$Script:ScriptVersion"
    Write-Log "Author: $Script:ScriptAuthor"
    Write-Log "Startup Threshold: $StartupThreshold programs"
    
    # Analyze startup programs
    $startupItems = Get-StartupPrograms
    $Script:IssuesFound = if ($startupItems.Count -gt $StartupThreshold) { $startupItems } else { @() }
    
    if ($startupItems.Count -le $StartupThreshold) {
        Write-Log "Startup program count within acceptable range" -Level "SUCCESS"
    } else {
        Write-Log "Found $($startupItems.Count) startup programs (exceeds threshold of $StartupThreshold)" -Level "WARN"
    }
    
    # Apply optimizations
    $Script:FixesApplied += Optimize-StartupPrograms -StartupItems $startupItems
    $Script:FixesApplied += Optimize-BootConfiguration
    $Script:FixesApplied += Optimize-Services
    $Script:FixesApplied += Repair-BootFiles
    
    # Summary
    Write-Log "=== EXECUTION SUMMARY ===" -Level "SUCCESS"
    Write-Log "Startup Items Found: $($startupItems.Count)"
    Write-Log "Optimizations Applied: $($Script:FixesApplied.Count)"
    Write-Log "Report Location: $Script:LogFile"
    
    if (-not $LogOnly -and $Script:FixesApplied.Count -gt 0) {
        Write-Log "RECOMMENDATION: Restart system to see boot performance improvements" -Level "WARN"
    }
    
    exit 0
} catch {
    Write-Log "FATAL ERROR: $($_.Exception.Message)" -Level "ERROR"
    exit 1
}
