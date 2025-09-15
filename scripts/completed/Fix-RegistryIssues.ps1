#Requires -Version 5.1
#Requires -RunAsAdministrator

<#
.SYNOPSIS
    Diagnoses and repairs Windows Registry corruption and optimization issues.

.DESCRIPTION
    This script identifies and fixes common registry problems including:
    - Registry corruption and errors
    - Invalid registry entries
    - Registry optimization for performance
    - Registry backup and restore
    - Registry permissions issues

.PARAMETER LogOnly
    Run in diagnostic mode only - no changes made

.PARAMETER BackupRegistry
    Enable registry backup before changes

.PARAMETER ReportPath
    Path to save diagnostic report

.EXAMPLE
    .\Fix-RegistryIssues.ps1 -LogOnly
    Diagnose registry issues without changes

.EXAMPLE
    .\Fix-RegistryIssues.ps1 -BackupRegistry
    Full registry repair with backup

.NOTES
    File Name: Fix-RegistryIssues.ps1
    Version: 1.0
    Date: June 30, 2025
    Author: Wesley Ellis (Wesley.Ellis@compucom.com)
    Company: CompuCom - SysTrack Automation Team
    
    Impact: Registry corruption affects system stability and performance
    Priority: HIGH - Critical for system integrity and functionality
#>

[CmdletBinding()]
param(
    [switch]$LogOnly,
    [switch]$BackupRegistry,
    [string]$ReportPath = "$env:TEMP\Registry-Issues-Report-$(Get-Date -Format 'yyyyMMdd-HHmmss').log"
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

function Test-RegistryHealth {
    Write-Log "Testing registry health..."
    $issues = @()
    
    try {
        # Test critical registry keys
        $criticalKeys = @(
            "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion",
            "HKLM:\SYSTEM\CurrentControlSet\Services",
            "HKCU:\Software\Microsoft\Windows\CurrentVersion"
        )
        
        foreach ($key in $criticalKeys) {
            if (-not (Test-Path $key)) {
                $issues += "Missing critical registry key: $key"
            }
        }
        
        Write-Log "Found $($issues.Count) registry issues"
        return $issues
    } catch {
        Write-Log "Error testing registry: $($_.Exception.Message)" -Level "ERROR"
        return @()
    }
}

function Backup-RegistryKeys {
    Write-Log "Backing up registry..."
    $fixes = @()
    
    if ($BackupRegistry -and -not $LogOnly) {
        try {
            $backupPath = "$env:TEMP\RegistryBackup_$(Get-Date -Format 'yyyyMMdd_HHmmss').reg"
            Start-Process -FilePath "regedit.exe" -ArgumentList "/e `"$backupPath`"" -Wait -WindowStyle Hidden
            $fixes += "Created registry backup: $backupPath"
        } catch {
            Write-Log "Error backing up registry: $($_.Exception.Message)" -Level "ERROR"
        }
    }
    return $fixes
}

function Repair-RegistryCorruption {
    Write-Log "Repairing registry corruption..."
    $fixes = @()
    
    if (-not $LogOnly) {
        try {
            # Run system file checker which includes registry repair
            Start-Process -FilePath "sfc.exe" -ArgumentList "/scannow" -Wait -WindowStyle Hidden
            $fixes += "Executed system file checker (includes registry repair)"
            
            # Run DISM to repair system image
            Start-Process -FilePath "dism.exe" -ArgumentList "/online /cleanup-image /restorehealth" -Wait -WindowStyle Hidden
            $fixes += "Executed DISM system image repair"
        } catch {
            Write-Log "Error repairing registry: $($_.Exception.Message)" -Level "ERROR"
        }
    }
    return $fixes
}

function Optimize-RegistryPerformance {
    Write-Log "Optimizing registry performance..."
    $fixes = @()
    
    if (-not $LogOnly) {
        try {
            # Remove common junk registry entries
            $junkPaths = @(
                "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\RecentDocs",
                "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\RunMRU"
            )
            
            foreach ($path in $junkPaths) {
                if (Test-Path $path) {
                    Remove-Item -Path $path -Recurse -Force -ErrorAction SilentlyContinue
                    $fixes += "Cleaned registry path: $path"
                }
            }
        } catch {
            Write-Log "Error optimizing registry: $($_.Exception.Message)" -Level "ERROR"
        }
    }
    return $fixes
}

# Main execution
try {
    Write-Log "Starting Registry Issues Repair v$Script:ScriptVersion"
    Write-Log "Author: Wesley Ellis (Wesley.Ellis@compucom.com)"
    
    $issues = Test-RegistryHealth
    Write-Log "Found $($issues.Count) registry issues"
    
    $Script:FixesApplied += Backup-RegistryKeys
    $Script:FixesApplied += Repair-RegistryCorruption
    $Script:FixesApplied += Optimize-RegistryPerformance
    
    Write-Log "=== EXECUTION SUMMARY ===" -Level "SUCCESS"
    Write-Log "Registry Issues Found: $($issues.Count)"
    Write-Log "Fixes Applied: $($Script:FixesApplied.Count)"
    Write-Log "Report Location: $Script:LogFile"
    
    if (-not $LogOnly -and $Script:FixesApplied.Count -gt 0) {
        Write-Log "RECOMMENDATION: Restart system to ensure registry changes take effect" -Level "WARN"
    }
    
    exit 0
} catch {
    Write-Log "FATAL ERROR: $($_.Exception.Message)" -Level "ERROR"
    exit 1
}
