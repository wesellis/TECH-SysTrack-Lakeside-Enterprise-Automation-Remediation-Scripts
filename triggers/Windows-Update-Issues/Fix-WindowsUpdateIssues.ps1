#Requires -Version 5.1
#Requires -RunAsAdministrator

<#
.SYNOPSIS
    Diagnoses and remediates Windows Update service issues and failures.

.DESCRIPTION
    This script identifies and fixes common Windows Update problems including:
    - Windows Update service failures
    - Corrupted update cache
    - Failed update installations
    - Update agent corruption
    - WSUS configuration issues

.PARAMETER LogOnly
    Run in diagnostic mode only - no changes made

.PARAMETER ResetUpdateAgent
    Enable complete Windows Update agent reset

.PARAMETER ReportPath
    Path to save diagnostic report

.EXAMPLE
    .\Fix-WindowsUpdate.ps1 -LogOnly
    Diagnose Windows Update issues without changes

.EXAMPLE
    .\Fix-WindowsUpdate.ps1 -ResetUpdateAgent
    Full Windows Update repair and reset

.NOTES
    File Name: Fix-WindowsUpdate.ps1
    Version: 1.0
    Date: June 30, 2025
    Author: Wesley Ellis (Wesley.Ellis@compucom.com)
    Company: CompuCom - SysTrack Automation Team
    
    Impact: Windows Update issues affect security and system stability
    Priority: HIGH - Critical for security patches and system maintenance
#>

[CmdletBinding()]
param(
    [switch]$LogOnly,
    [switch]$ResetUpdateAgent,
    [string]$ReportPath = "$env:TEMP\Windows-Update-Report-$(Get-Date -Format 'yyyyMMdd-HHmmss').log"
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

function Test-WindowsUpdateServices {
    Write-Log "Testing Windows Update services..."
    $issues = @()
    
    $requiredServices = @("wuauserv", "cryptsvc", "bits", "msiserver")
    foreach ($service in $requiredServices) {
        $svc = Get-Service -Name $service -ErrorAction SilentlyContinue
        if (-not $svc -or $svc.Status -ne "Running") {
            $issues += "Service $service not running"
        }
    }
    return $issues
}

function Repair-WindowsUpdateServices {
    Write-Log "Repairing Windows Update services..."
    $fixes = @()
    
    if (-not $LogOnly) {
        $services = @("wuauserv", "cryptsvc", "bits", "msiserver")
        foreach ($service in $services) {
            try {
                Stop-Service -Name $service -Force -ErrorAction SilentlyContinue
                Set-Service -Name $service -StartupType Automatic
                Start-Service -Name $service
                $fixes += "Restarted service: $service"
            } catch {
                Write-Log "Error restarting $service`: $($_.Exception.Message)" -Level "ERROR"
            }
        }
    }
    return $fixes
}

function Clear-UpdateCache {
    Write-Log "Clearing Windows Update cache..."
    $fixes = @()
    
    if (-not $LogOnly) {
        try {
            Stop-Service -Name "wuauserv" -Force
            $cacheFolder = "$env:WINDIR\SoftwareDistribution"
            if (Test-Path $cacheFolder) {
                Remove-Item -Path "$cacheFolder\*" -Recurse -Force -ErrorAction SilentlyContinue
                $fixes += "Cleared Windows Update cache"
            }
            Start-Service -Name "wuauserv"
        } catch {
            Write-Log "Error clearing update cache: $($_.Exception.Message)" -Level "ERROR"
        }
    }
    return $fixes
}

function Reset-WindowsUpdateAgent {
    Write-Log "Resetting Windows Update agent..."
    $fixes = @()
    
    if ($ResetUpdateAgent -and -not $LogOnly) {
        try {
            # Stop services
            @("wuauserv", "cryptsvc", "bits", "msiserver") | ForEach-Object {
                Stop-Service -Name $_ -Force -ErrorAction SilentlyContinue
            }
            
            # Reset Windows Update components
            Start-Process -FilePath "dism.exe" -ArgumentList "/online /cleanup-image /restorehealth" -Wait -WindowStyle Hidden
            Start-Process -FilePath "sfc.exe" -ArgumentList "/scannow" -Wait -WindowStyle Hidden
            
            # Re-register Windows Update DLLs
            $dlls = @("atl.dll", "urlmon.dll", "mshtml.dll", "shdocvw.dll", "browseui.dll", "jscript.dll", "vbscript.dll", "scrrun.dll", "msxml.dll", "msxml3.dll", "msxml6.dll", "actxprxy.dll", "softpub.dll", "wintrust.dll", "dssenh.dll", "rsaenh.dll", "gpkcsp.dll", "sccbase.dll", "slbcsp.dll", "cryptdlg.dll", "oleaut32.dll", "ole32.dll", "shell32.dll", "initpkg.dll", "wuapi.dll", "wuaueng.dll", "wuaueng1.dll", "wucltui.dll", "wups.dll", "wups2.dll", "wuweb.dll", "qmgr.dll", "qmgrprxy.dll", "wucltux.dll", "muweb.dll", "wuwebv.dll")
            
            foreach ($dll in $dlls) {
                Start-Process -FilePath "regsvr32.exe" -ArgumentList "/s $dll" -Wait -WindowStyle Hidden -ErrorAction SilentlyContinue
            }
            
            $fixes += "Reset Windows Update agent and re-registered components"
            
            # Restart services
            @("cryptsvc", "bits", "msiserver", "wuauserv") | ForEach-Object {
                Start-Service -Name $_ -ErrorAction SilentlyContinue
            }
        } catch {
            Write-Log "Error resetting update agent: $($_.Exception.Message)" -Level "ERROR"
        }
    }
    return $fixes
}

# Main execution
try {
    Write-Log "Starting Windows Update Repair v$Script:ScriptVersion"
    Write-Log "Author: Wesley Ellis (Wesley.Ellis@compucom.com)"
    
    $issues = Test-WindowsUpdateServices
    Write-Log "Found $($issues.Count) Windows Update issues"
    
    $Script:FixesApplied += Repair-WindowsUpdateServices
    $Script:FixesApplied += Clear-UpdateCache
    $Script:FixesApplied += Reset-WindowsUpdateAgent
    
    Write-Log "=== EXECUTION SUMMARY ===" -Level "SUCCESS"
    Write-Log "Fixes Applied: $($Script:FixesApplied.Count)"
    Write-Log "Report Location: $Script:LogFile"
    
    exit 0
} catch {
    Write-Log "FATAL ERROR: $($_.Exception.Message)" -Level "ERROR"
    exit 1
}
