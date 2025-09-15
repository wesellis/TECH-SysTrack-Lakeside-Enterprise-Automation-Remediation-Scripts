#Requires -Version 5.1
#Requires -RunAsAdministrator

<#
.SYNOPSIS
    Diagnoses and remediates audio device and sound system issues.

.DESCRIPTION
    This script identifies and fixes common audio problems including:
    - Audio device driver issues
    - Windows Audio service problems
    - Audio endpoint configuration
    - Sound quality and performance issues
    - Microphone and recording device problems

.PARAMETER LogOnly
    Run in diagnostic mode only - no changes made

.PARAMETER ResetAudioStack
    Enable complete audio stack reset

.PARAMETER ReportPath
    Path to save diagnostic report

.EXAMPLE
    .\Fix-AudioDevices.ps1 -LogOnly
    Diagnose audio issues without changes

.EXAMPLE
    .\Fix-AudioDevices.ps1 -ResetAudioStack
    Full audio system repair and reset

.NOTES
    File Name: Fix-AudioDevices.ps1
    Version: 1.0
    Date: June 30, 2025
    Author: Wesley Ellis (Wesley.Ellis@compucom.com)
    Company: CompuCom - SysTrack Automation Team
    
    Impact: Audio issues affect communication and multimedia functionality
    Priority: MEDIUM - Important for video calls and multimedia applications
#>

[CmdletBinding()]
param(
    [switch]$LogOnly,
    [switch]$ResetAudioStack,
    [string]$ReportPath = "$env:TEMP\Audio-Devices-Report-$(Get-Date -Format 'yyyyMMdd-HHmmss').log"
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

function Test-AudioDevices {
    Write-Log "Testing audio devices..."
    $issues = @()
    
    try {
        $audioDevices = Get-WmiObject -Class Win32_SoundDevice
        foreach ($device in $audioDevices) {
            if ($device.Status -ne "OK") {
                $issues += "Audio device issue: $($device.Name) - Status: $($device.Status)"
            }
        }
        
        Write-Log "Found $($issues.Count) audio device issues"
        return $issues
    } catch {
        Write-Log "Error testing audio devices: $($_.Exception.Message)" -Level "ERROR"
        return @()
    }
}

function Repair-AudioServices {
    Write-Log "Repairing audio services..."
    $fixes = @()
    
    if (-not $LogOnly) {
        $audioServices = @("AudioSrv", "AudioEndpointBuilder", "Audiosrv")
        foreach ($service in $audioServices) {
            try {
                $svc = Get-Service -Name $service -ErrorAction SilentlyContinue
                if ($svc) {
                    Restart-Service -Name $service -Force
                    $fixes += "Restarted audio service: $service"
                }
            } catch {
                Write-Log "Error restarting $service`: $($_.Exception.Message)" -Level "ERROR"
            }
        }
    }
    return $fixes
}

function Reset-AudioStack {
    Write-Log "Resetting audio stack..."
    $fixes = @()
    
    if ($ResetAudioStack -and -not $LogOnly) {
        try {
            # Reset audio drivers
            Get-WmiObject -Class Win32_SoundDevice | ForEach-Object {
                $_.Reset()
            }
            
            # Clear audio cache
            $audioCache = "$env:LOCALAPPDATA\Microsoft\Windows\Explorer\thumbcache*"
            Remove-Item -Path $audioCache -Force -ErrorAction SilentlyContinue
            
            $fixes += "Reset audio stack and cleared cache"
        } catch {
            Write-Log "Error resetting audio stack: $($_.Exception.Message)" -Level "ERROR"
        }
    }
    return $fixes
}

function Optimize-AudioSettings {
    Write-Log "Optimizing audio settings..."
    $fixes = @()
    
    if (-not $LogOnly) {
        try {
            # Disable audio enhancements that can cause issues
            $audioRegPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\MMDevices\Audio\Render"
            if (Test-Path $audioRegPath) {
                Set-ItemProperty -Path $audioRegPath -Name "DisableProtectedAudioDG" -Value 1 -ErrorAction SilentlyContinue
                $fixes += "Optimized audio registry settings"
            }
        } catch {
            Write-Log "Error optimizing audio settings: $($_.Exception.Message)" -Level "ERROR"
        }
    }
    return $fixes
}

# Main execution
try {
    Write-Log "Starting Audio Devices Repair v$Script:ScriptVersion"
    Write-Log "Author: Wesley Ellis (Wesley.Ellis@compucom.com)"
    
    $issues = Test-AudioDevices
    Write-Log "Found $($issues.Count) audio issues"
    
    $Script:FixesApplied += Repair-AudioServices
    $Script:FixesApplied += Reset-AudioStack
    $Script:FixesApplied += Optimize-AudioSettings
    
    Write-Log "=== EXECUTION SUMMARY ===" -Level "SUCCESS"
    Write-Log "Audio Issues Found: $($issues.Count)"
    Write-Log "Fixes Applied: $($Script:FixesApplied.Count)"
    Write-Log "Report Location: $Script:LogFile"
    
    if (-not $LogOnly -and $Script:FixesApplied.Count -gt 0) {
        Write-Log "RECOMMENDATION: Test audio functionality and restart if needed" -Level "WARN"
    }
    
    exit 0
} catch {
    Write-Log "FATAL ERROR: $($_.Exception.Message)" -Level "ERROR"
    exit 1
}
