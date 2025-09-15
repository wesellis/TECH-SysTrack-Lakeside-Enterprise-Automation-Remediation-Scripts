#Requires -Version 5.1
#Requires -RunAsAdministrator

<#
.SYNOPSIS
    Diagnoses and repairs Microsoft Office application crashes and performance issues.

.DESCRIPTION
    This script identifies and fixes common Office problems including:
    - Office application crashes and hangs
    - Add-in conflicts and corruption
    - Profile corruption and reset
    - Office update and repair issues
    - PST file corruption in Outlook

.PARAMETER LogOnly
    Run in diagnostic mode only - no changes made

.PARAMETER ResetProfiles
    Enable Office profile reset for corrupted profiles

.PARAMETER ReportPath
    Path to save diagnostic report

.EXAMPLE
    .\Fix-OfficeApplications.ps1 -LogOnly
    Diagnose Office issues without making changes

.EXAMPLE
    .\Fix-OfficeApplications.ps1 -ResetProfiles
    Full Office repair including profile reset

.NOTES
    File Name: Fix-OfficeApplications.ps1
    Version: 1.0
    Date: June 30, 2025
    Author: Wesley Ellis (Wesley.Ellis@compucom.com)
    Company: CompuCom - SysTrack Automation Team
    
    Impact: Office crashes affect productivity across enterprise
    Priority: HIGH - Critical for business operations and user productivity
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [switch]$LogOnly,
    
    [Parameter(Mandatory = $false)]
    [switch]$ResetProfiles,
    
    [Parameter(Mandatory = $false)]
    [string]$ReportPath = "$env:TEMP\Office-Applications-Report-$(Get-Date -Format 'yyyyMMdd-HHmmss').log"
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

function Get-OfficeInstallation {
    Write-Log "Detecting Office installation..."
    try {
        $officeApps = @()
        
        # Check for Office applications
        $commonOfficeApps = @("WINWORD.EXE", "EXCEL.EXE", "POWERPNT.EXE", "OUTLOOK.EXE", "MSACCESS.EXE")
        
        foreach ($app in $commonOfficeApps) {
            $process = Get-Process -Name $app.Replace(".EXE", "") -ErrorAction SilentlyContinue
            if ($process) {
                $officeApps += [PSCustomObject]@{
                    Name = $app.Replace(".EXE", "")
                    Path = $process.Path
                    Version = $process.FileVersion
                    Running = $true
                }
            } else {
                # Check if installed even if not running
                $registryPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths\$app"
                if (Test-Path $registryPath) {
                    $appPath = (Get-ItemProperty $registryPath).'(default)'
                    if (Test-Path $appPath) {
                        $fileInfo = Get-ItemProperty $appPath
                        $officeApps += [PSCustomObject]@{
                            Name = $app.Replace(".EXE", "")
                            Path = $appPath
                            Version = $fileInfo.VersionInfo.FileVersion
                            Running = $false
                        }
                    }
                }
            }
        }
        
        Write-Log "Found $($officeApps.Count) Office applications"
        return $officeApps
    } catch {
        Write-Log "Error detecting Office installation: $($_.Exception.Message)" -Level "ERROR"
        return @()
    }
}

function Test-OfficeAddins {
    Write-Log "Checking Office add-ins for conflicts..."
    $addinIssues = @()
    
    try {
        # Check Office add-ins registry locations
        $addinPaths = @(
            "HKCU:\Software\Microsoft\Office\Word\Addins",
            "HKCU:\Software\Microsoft\Office\Excel\Addins", 
            "HKCU:\Software\Microsoft\Office\PowerPoint\Addins",
            "HKCU:\Software\Microsoft\Office\Outlook\Addins",
            "HKLM:\Software\Microsoft\Office\Word\Addins",
            "HKLM:\Software\Microsoft\Office\Excel\Addins",
            "HKLM:\Software\Microsoft\Office\PowerPoint\Addins",
            "HKLM:\Software\Microsoft\Office\Outlook\Addins"
        )
        
        foreach ($path in $addinPaths) {
            if (Test-Path $path) {
                $addins = Get-ChildItem $path -ErrorAction SilentlyContinue
                foreach ($addin in $addins) {
                    try {
                        $addinProps = Get-ItemProperty $addin.PSPath -ErrorAction SilentlyContinue
                        if ($addinProps -and $addinProps.LoadBehavior -eq 3) {
                            # LoadBehavior 3 means the add-in loads at startup
                            $addinIssues += [PSCustomObject]@{
                                Application = $path.Split('\')[5]  # Extract app name
                                AddinName = $addin.PSChildName
                                LoadBehavior = $addinProps.LoadBehavior
                                Path = $addinProps.Path
                                Issue = "Add-in loads at startup (potential conflict)"
                            }
                        }
                    } catch {
                        # Continue with other add-ins
                    }
                }
            }
        }
        
        Write-Log "Found $($addinIssues.Count) potentially problematic add-ins"
        return $addinIssues
    } catch {
        Write-Log "Error checking Office add-ins: $($_.Exception.Message)" -Level "ERROR"
        return @()
    }
}

function Repair-OfficeApplications {
    Write-Log "Repairing Office applications..."
    $fixes = @()
    
    if (-not $LogOnly) {
        try {
            # Terminate Office processes
            $officeProcesses = @("WINWORD", "EXCEL", "POWERPNT", "OUTLOOK", "MSACCESS", "ONENOTE")
            foreach ($proc in $officeProcesses) {
                $process = Get-Process -Name $proc -ErrorAction SilentlyContinue
                if ($process) {
                    Stop-Process -Name $proc -Force -ErrorAction SilentlyContinue
                    $fixes += "Terminated Office process: $proc"
                }
            }
            
            # Run Office Quick Repair
            $officeVersion = "16.0"  # Office 2016/2019/365
            $repairPath = "${env:ProgramFiles}\Common Files\microsoft shared\ClickToRun\OfficeC2RClient.exe"
            
            if (Test-Path $repairPath) {
                Write-Log "Running Office Quick Repair..."
                Start-Process -FilePath $repairPath -ArgumentList "/update user updatetoversion=$officeVersion" -Wait -WindowStyle Hidden
                $fixes += "Executed Office Quick Repair"
            } else {
                # Try alternative repair method
                $msiexecResult = Start-Process -FilePath "msiexec.exe" -ArgumentList "/fmu Microsoft Office Professional Plus 2019" -Wait -PassThru -WindowStyle Hidden -ErrorAction SilentlyContinue
                if ($msiexecResult) {
                    $fixes += "Attempted MSI-based Office repair"
                }
            }
            
        } catch {
            Write-Log "Error repairing Office applications: $($_.Exception.Message)" -Level "ERROR"
        }
    } else {
        Write-Log "Would repair Office applications and run Quick Repair" -Level "WARN"
    }
    
    return $fixes
}

function Reset-OfficeProfiles {
    Write-Log "Resetting Office user profiles..."
    $fixes = @()
    
    if ($ResetProfiles) {
        if (-not $LogOnly) {
            try {
                # Backup and reset Outlook profile
                $outlookProfile = "$env:APPDATA\Microsoft\Outlook"
                if (Test-Path $outlookProfile) {
                    $backupPath = "$env:TEMP\OutlookProfileBackup_$(Get-Date -Format 'yyyyMMdd')"
                    Copy-Item -Path $outlookProfile -Destination $backupPath -Recurse -ErrorAction SilentlyContinue
                    
                    # Reset Outlook registry settings
                    $outlookRegPath = "HKCU:\Software\Microsoft\Office\16.0\Outlook"
                    if (Test-Path $outlookRegPath) {
                        Remove-Item -Path "$outlookRegPath\Profiles" -Recurse -Force -ErrorAction SilentlyContinue
                        $fixes += "Reset Outlook profile registry settings"
                    }
                }
                
                # Reset Word settings
                $wordRegPath = "HKCU:\Software\Microsoft\Office\16.0\Word"
                if (Test-Path $wordRegPath) {
                    Remove-Item -Path "$wordRegPath\Options" -Recurse -Force -ErrorAction SilentlyContinue
                    $fixes += "Reset Word user settings"
                }
                
                # Reset Excel settings
                $excelRegPath = "HKCU:\Software\Microsoft\Office\16.0\Excel"
                if (Test-Path $excelRegPath) {
                    Remove-Item -Path "$excelRegPath\Options" -Recurse -Force -ErrorAction SilentlyContinue
                    $fixes += "Reset Excel user settings"
                }
                
                Write-Log "Office profiles reset completed" -Level "SUCCESS"
            } catch {
                Write-Log "Error resetting Office profiles: $($_.Exception.Message)" -Level "ERROR"
            }
        } else {
            Write-Log "Would reset Office user profiles and settings" -Level "WARN"
        }
    } else {
        Write-Log "Profile reset not requested"
    }
    
    return $fixes
}

function Disable-ProblematicAddins {
    param([array]$AddinIssues)
    Write-Log "Disabling problematic Office add-ins..."
    $fixes = @()
    
    foreach ($addin in $AddinIssues) {
        if ($addin.LoadBehavior -eq 3) {
            try {
                if (-not $LogOnly) {
                    $regPath = "HKCU:\Software\Microsoft\Office\$($addin.Application)\Addins\$($addin.AddinName)"
                    if (Test-Path $regPath) {
                        Set-ItemProperty -Path $regPath -Name "LoadBehavior" -Value 2  # Load on demand
                        $fixes += "Disabled startup loading for: $($addin.AddinName)"
                        Write-Log "Disabled add-in: $($addin.AddinName) in $($addin.Application)"
                    }
                } else {
                    Write-Log "Would disable add-in: $($addin.AddinName) in $($addin.Application)" -Level "WARN"
                }
            } catch {
                Write-Log "Error disabling add-in $($addin.AddinName): $($_.Exception.Message)" -Level "ERROR"
            }
        }
    }
    
    return $fixes
}

function Clear-OfficeCache {
    Write-Log "Clearing Office cache and temporary files..."
    $fixes = @()
    
    if (-not $LogOnly) {
        try {
            # Office cache locations
            $cachePaths = @(
                "$env:LOCALAPPDATA\Microsoft\Office\16.0\OfficeFileCache",
                "$env:APPDATA\Microsoft\Office\Recent",
                "$env:APPDATA\Microsoft\Templates",
                "$env:LOCALAPPDATA\Microsoft\Office\UnsavedFiles"
            )
            
            foreach ($path in $cachePaths) {
                if (Test-Path $path) {
                    $items = Get-ChildItem -Path $path -Recurse -Force -ErrorAction SilentlyContinue
                    if ($items) {
                        Remove-Item -Path "$path\*" -Recurse -Force -ErrorAction SilentlyContinue
                        $fixes += "Cleared cache: $path"
                        Write-Log "Cleared Office cache: $path"
                    }
                }
            }
            
        } catch {
            Write-Log "Error clearing Office cache: $($_.Exception.Message)" -Level "ERROR"
        }
    } else {
        Write-Log "Would clear Office cache and temporary files" -Level "WARN"
    }
    
    return $fixes
}

function Test-OfficeHealth {
    Write-Log "Testing Office application health..."
    
    try {
        # Test Office applications startup
        $testApps = @("WINWORD.EXE", "EXCEL.EXE")
        
        foreach ($app in $testApps) {
            $appName = $app.Replace(".EXE", "")
            $registryPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths\$app"
            
            if (Test-Path $registryPath) {
                $appPath = (Get-ItemProperty $registryPath).'(default)'
                if (Test-Path $appPath) {
                    Write-Log "$appName application found and accessible"
                } else {
                    Write-Log "$appName application path invalid" -Level "WARN"
                }
            } else {
                Write-Log "$appName not found in registry" -Level "WARN"
            }
        }
        
    } catch {
        Write-Log "Error testing Office health: $($_.Exception.Message)" -Level "ERROR"
    }
}

# Main execution
try {
    Write-Log "Starting Office Applications Repair v$Script:ScriptVersion"
    Write-Log "Author: $Script:ScriptAuthor"
    Write-Log "Reset Profiles: $ResetProfiles"
    
    # Detect Office installation
    $officeApps = Get-OfficeInstallation
    if ($officeApps.Count -eq 0) {
        Write-Log "No Office applications detected - exiting" -Level "WARN"
        exit 0
    }
    
    # Check for add-in issues
    $addinIssues = Test-OfficeAddins
    $Script:IssuesFound = $addinIssues
    
    Write-Log "Found $($addinIssues.Count) potential add-in conflicts"
    
    # Apply fixes
    $Script:FixesApplied += Repair-OfficeApplications
    $Script:FixesApplied += Disable-ProblematicAddins -AddinIssues $addinIssues
    $Script:FixesApplied += Clear-OfficeCache
    $Script:FixesApplied += Reset-OfficeProfiles
    
    # Test Office health after repairs
    Test-OfficeHealth
    
    # Summary
    Write-Log "=== EXECUTION SUMMARY ===" -Level "SUCCESS"
    Write-Log "Office Apps Found: $($officeApps.Count)"
    Write-Log "Add-in Issues: $($Script:IssuesFound.Count)"
    Write-Log "Repairs Applied: $($Script:FixesApplied.Count)"
    Write-Log "Report Location: $Script:LogFile"
    
    if (-not $LogOnly -and $Script:FixesApplied.Count -gt 0) {
        Write-Log "RECOMMENDATION: Test Office applications and restart if needed" -Level "WARN"
    }
    
    exit 0
} catch {
    Write-Log "FATAL ERROR: $($_.Exception.Message)" -Level "ERROR"
    exit 1
}
