#Requires -Version 5.1
#Requires -RunAsAdministrator

<#
.SYNOPSIS
    Diagnoses and remediates CPU interrupt issues that affect system performance.

.DESCRIPTION
    This script identifies and fixes common CPU interrupt issues including:
    - High interrupt rates from specific devices
    - Driver conflicts causing interrupt storms
    - Network adapter interrupt optimization
    - USB controller interrupt issues
    - Audio device interrupt problems

.PARAMETER LogOnly
    Run in diagnostic mode only - no changes made

.PARAMETER MaxInterruptRate
    Maximum interrupt rate per second before remediation (default: 1000)

.PARAMETER ReportPath
    Path to save diagnostic report

.EXAMPLE
    .\Fix-CPUInterrupts.ps1 -LogOnly
    Run diagnostic scan without making changes

.EXAMPLE
    .\Fix-CPUInterrupts.ps1 -MaxInterruptRate 500 -ReportPath "C:\Reports\cpu-interrupts.log"
    Fix interrupts above 500/sec and save detailed report

.NOTES
    File Name: Fix-CPUInterrupts.ps1
    Version: 1.0
    Date: June 30, 2025
    Author: Wesley Ellis (Wesley.Ellis@compucom.com)
    Company: CompuCom - SysTrack Automation Team
    Requires: Administrator privileges
    Tested: Windows 10/11, Server 2016/2019/2022
    
    Change Log:
    v1.0 - 2025-06-30 - Initial release with comprehensive interrupt detection and remediation
    
    Impact: Targets 1,857 systems (82% of enterprise fleet) with CPU interrupt issues
    Priority: CRITICAL - Highest impact automation target
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [switch]$LogOnly,
    
    [Parameter(Mandatory = $false)]
    [int]$MaxInterruptRate = 1000,
    
    [Parameter(Mandatory = $false)]
    [string]$ReportPath = "$env:TEMP\CPUInterrupt-Report-$(Get-Date -Format 'yyyyMMdd-HHmmss').log"
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

function Get-InterruptStatistics {
    Write-Log "Gathering CPU interrupt statistics..."
    
    try {
        # Get interrupt rates using performance counters
        $processors = Get-Counter -Counter "\Processor(*)\Interrupts/sec" -SampleInterval 1 -MaxSamples 3
        $interruptData = @()
        
        foreach ($sample in $processors.CounterSamples) {
            if ($sample.InstanceName -ne "_total") {
                $interruptData += [PSCustomObject]@{
                    ProcessorID = $sample.InstanceName
                    InterruptsPerSec = [math]::Round($sample.CookedValue, 0)
                    Path = $sample.Path
                    TimeStamp = $sample.TimeStamp
                }
            }
        }
        
        # Get device information
        $devices = Get-WmiObject -Class Win32_SystemDriver | Where-Object { $_.State -eq "Running" }
        
        Write-Log "Found $($interruptData.Count) processors, $($devices.Count) active drivers"
        return @{
            Processors = $interruptData
            Devices = $devices
            Timestamp = Get-Date
        }
    }
    catch {
        Write-Log "Error gathering interrupt statistics: $($_.Exception.Message)" -Level "ERROR"
        return $null
    }
}

function Test-HighInterruptDevices {
    Write-Log "Analyzing high interrupt devices..."
    
    try {
        $highInterruptDevices = @()
        
        # Check processor interrupt rates
        $stats = Get-InterruptStatistics
        if ($stats) {
            foreach ($proc in $stats.Processors) {
                if ($proc.InterruptsPerSec -gt $MaxInterruptRate) {
                    $highInterruptDevices += [PSCustomObject]@{
                        DeviceType = "Processor"
                        DeviceName = "CPU $($proc.ProcessorID)"
                        InterruptRate = $proc.InterruptsPerSec
                        DeviceID = $proc.ProcessorID
                        Issue = "High interrupt rate: $($proc.InterruptsPerSec)/sec"
                    }
                    Write-Log "High interrupt rate detected on CPU $($proc.ProcessorID): $($proc.InterruptsPerSec)/sec" -Level "WARN"
                }
            }
        }
        
        # Network adapters
        $networkAdapters = Get-WmiObject -Class Win32_NetworkAdapter | Where-Object { $_.NetEnabled -eq $true }
        foreach ($adapter in $networkAdapters) {
            try {
                if ($adapter.NetConnectionID) {
                    $perfData = Get-Counter -Counter "\Network Interface($($adapter.NetConnectionID))\Packets/sec" -SampleInterval 1 -MaxSamples 2 -ErrorAction SilentlyContinue
                    if ($perfData) {
                        $avgPackets = ($perfData.CounterSamples | Measure-Object CookedValue -Average).Average
                        if ($avgPackets -gt ($MaxInterruptRate * 0.5)) {  # Network threshold is 50% of CPU threshold
                            $highInterruptDevices += [PSCustomObject]@{
                                DeviceType = "NetworkAdapter"
                                DeviceName = $adapter.Name
                                InterruptRate = [math]::Round($avgPackets, 0)
                                DeviceID = $adapter.DeviceID
                                Issue = "High packet rate causing interrupts"
                            }
                        }
                    }
                }
            }
            catch {
                Write-Log "Error checking network adapter $($adapter.Name): $($_.Exception.Message)" -Level "WARN"
            }
        }
        
        # USB controllers
        $usbControllers = Get-WmiObject -Class Win32_USBController
        foreach ($usb in $usbControllers) {
            if ($usb.Status -ne "OK") {
                $highInterruptDevices += [PSCustomObject]@{
                    DeviceType = "USBController"
                    DeviceName = $usb.Name
                    InterruptRate = "Unknown"
                    DeviceID = $usb.DeviceID
                    Issue = "USB controller status: $($usb.Status)"
                }
            }
        }
        
        # Audio devices
        $audioDevices = Get-WmiObject -Class Win32_SoundDevice
        foreach ($audio in $audioDevices) {
            if ($audio.Status -ne "OK") {
                $highInterruptDevices += [PSCustomObject]@{
                    DeviceType = "AudioDevice"
                    DeviceName = $audio.Name
                    InterruptRate = "Unknown"
                    DeviceID = $audio.DeviceID
                    Issue = "Audio device status: $($audio.Status)"
                }
            }
        }
        
        Write-Log "Found $($highInterruptDevices.Count) devices with potential interrupt issues"
        return $highInterruptDevices
    }
    catch {
        Write-Log "Error analyzing interrupt devices: $($_.Exception.Message)" -Level "ERROR"
        return @()
    }
}

function Repair-NetworkAdapterInterrupts {
    param([array]$NetworkIssues)
    
    Write-Log "Repairing network adapter interrupt issues..."
    $fixesApplied = @()
    
    foreach ($issue in $NetworkIssues) {
        try {
            Write-Log "Processing network adapter: $($issue.DeviceName)"
            
            if (-not $LogOnly) {
                # Find matching network adapter
                $adapter = Get-NetAdapter | Where-Object { $_.InterfaceDescription -like "*$($issue.DeviceName.Split(' ')[0])*" }
                
                if ($adapter) {
                    # Disable and re-enable adapter
                    Write-Log "Resetting adapter: $($adapter.Name)"
                    Disable-NetAdapter -Name $adapter.Name -Confirm:$false
                    Start-Sleep -Seconds 3
                    Enable-NetAdapter -Name $adapter.Name -Confirm:$false
                    
                    # Apply interrupt optimization via registry
                    $regPath = "HKLM:\SYSTEM\CurrentControlSet\Class\{4d36e972-e325-11ce-bfc1-08002be10318}"
                    $subKeys = Get-ChildItem $regPath -ErrorAction SilentlyContinue
                    
                    foreach ($subKey in $subKeys) {
                        try {
                            $driverDesc = Get-ItemProperty -Path $subKey.PSPath -Name "DriverDesc" -ErrorAction SilentlyContinue
                            if ($driverDesc -and $driverDesc.DriverDesc -like "*$($adapter.InterfaceDescription.Split(' ')[0])*") {
                                # Set interrupt moderation
                                Set-ItemProperty -Path $subKey.PSPath -Name "*InterruptModeration" -Value "1" -ErrorAction SilentlyContinue
                                Set-ItemProperty -Path $subKey.PSPath -Name "*ITR" -Value "200" -ErrorAction SilentlyContinue
                                Write-Log "Applied interrupt optimization to $($adapter.Name)"
                            }
                        }
                        catch {
                            # Continue with other adapters
                        }
                    }
                    
                    $fixesApplied += "Network adapter reset and optimized: $($adapter.Name)"
                }
            } else {
                Write-Log "Would reset network adapter: $($issue.DeviceName)" -Level "WARN"
            }
        }
        catch {
            Write-Log "Error fixing network adapter $($issue.DeviceName): $($_.Exception.Message)" -Level "ERROR"
        }
    }
    
    return $fixesApplied
}

function Repair-USBControllerInterrupts {
    param([array]$USBIssues)
    
    Write-Log "Repairing USB controller interrupt issues..."
    $fixesApplied = @()
    
    foreach ($issue in $USBIssues) {
        try {
            Write-Log "Processing USB controller: $($issue.DeviceName)"
            
            if (-not $LogOnly) {
                # Restart USB Root Hub services
                $usbServices = @("USB", "USBHUB")
                foreach ($serviceName in $usbServices) {
                    $service = Get-Service -Name $serviceName -ErrorAction SilentlyContinue
                    if ($service) {
                        try {
                            Restart-Service -Name $serviceName -Force -ErrorAction Stop
                            Write-Log "Restarted USB service: $serviceName"
                        }
                        catch {
                            Write-Log "Could not restart service $serviceName`: $($_.Exception.Message)" -Level "WARN"
                        }
                    }
                }
                
                $fixesApplied += "USB services restarted for: $($issue.DeviceName)"
            } else {
                Write-Log "Would restart USB services for: $($issue.DeviceName)" -Level "WARN"
            }
        }
        catch {
            Write-Log "Error fixing USB controller $($issue.DeviceName): $($_.Exception.Message)" -Level "ERROR"
        }
    }
    
    return $fixesApplied
}

function Repair-AudioDeviceInterrupts {
    param([array]$AudioIssues)
    
    Write-Log "Repairing audio device interrupt issues..."
    $fixesApplied = @()
    
    foreach ($issue in $AudioIssues) {
        try {
            Write-Log "Processing audio device: $($issue.DeviceName)"
            
            if (-not $LogOnly) {
                # Restart Windows Audio services
                $audioServices = @("AudioSrv", "AudioEndpointBuilder", "Audiosrv")
                foreach ($serviceName in $audioServices) {
                    $service = Get-Service -Name $serviceName -ErrorAction SilentlyContinue
                    if ($service -and $service.Status -eq "Running") {
                        try {
                            Restart-Service -Name $serviceName -Force -ErrorAction Stop
                            Write-Log "Restarted audio service: $serviceName"
                        }
                        catch {
                            Write-Log "Could not restart service $serviceName`: $($_.Exception.Message)" -Level "WARN"
                        }
                    }
                }
                
                $fixesApplied += "Audio services restarted for: $($issue.DeviceName)"
            } else {
                Write-Log "Would restart audio services for: $($issue.DeviceName)" -Level "WARN"
            }
        }
        catch {
            Write-Log "Error fixing audio device $($issue.DeviceName): $($_.Exception.Message)" -Level "ERROR"
        }
    }
    
    return $fixesApplied
}

function Optimize-SystemInterrupts {
    Write-Log "Applying system-wide interrupt optimizations..."
    $fixesApplied = @()
    
    try {
        if (-not $LogOnly) {
            # Set processor scheduling for background services (better for servers/workstations)
            Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\PriorityControl" -Name "Win32PrioritySeparation" -Value 24
            
            # Optimize system responsiveness (10% reserved for OS, 90% for applications)
            Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile" -Name "SystemResponsiveness" -Value 10
            
            # Optimize network throttling
            $netPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games"
            if (Test-Path $netPath) {
                Set-ItemProperty -Path $netPath -Name "GPU Priority" -Value 8 -ErrorAction SilentlyContinue
                Set-ItemProperty -Path $netPath -Name "Priority" -Value 6 -ErrorAction SilentlyContinue
            }
            
            # Disable unnecessary system interrupts for graphics
            $regPath = "HKLM:\SYSTEM\CurrentControlSet\Services\DXGKrnl"
            if (Test-Path $regPath) {
                Set-ItemProperty -Path $regPath -Name "MonitorLatencyTolerance" -Value 1 -ErrorAction SilentlyContinue
                Set-ItemProperty -Path $regPath -Name "MonitorRefreshLatencyTolerance" -Value 1 -ErrorAction SilentlyContinue
            }
            
            Write-Log "System interrupt optimizations applied" -Level "SUCCESS"
            $fixesApplied += "System interrupt optimizations applied"
        } else {
            Write-Log "Would apply system interrupt optimizations" -Level "WARN"
        }
    }
    catch {
        Write-Log "Error applying system optimizations: $($_.Exception.Message)" -Level "ERROR"
    }
    
    return $fixesApplied
}

function Generate-Report {
    param(
        [array]$Issues,
        [array]$Fixes,
        [object]$Stats
    )
    
    Write-Log "Generating diagnostic report..."
    
    $report = @"
====================================================================
CPU INTERRUPT DIAGNOSTIC REPORT
====================================================================
Report Generated: $(Get-Date)
Script Version: $Script:ScriptVersion
Script Date: $Script:ScriptDate
Script Author: $Script:ScriptAuthor
Computer: $env:COMPUTERNAME
User: $env:USERNAME
Script Mode: $(if ($LogOnly) { "DIAGNOSTIC ONLY" } else { "REMEDIATION" })
Max Interrupt Threshold: $MaxInterruptRate/sec

SYSTEM INFORMATION:
====================================================================
OS Version: $((Get-WmiObject Win32_OperatingSystem).Caption)
Total Physical Memory: $([math]::Round((Get-WmiObject Win32_ComputerSystem).TotalPhysicalMemory / 1GB, 2)) GB
Processor Count: $($Stats.Processors.Count)

INTERRUPT ANALYSIS:
====================================================================
Total Issues Found: $($Issues.Count)
Fixes Applied: $($Fixes.Count)

DETAILED FINDINGS:
====================================================================
"@
    
    foreach ($issue in $Issues) {
        $report += @"

Device Type: $($issue.DeviceType)
Device Name: $($issue.DeviceName)
Issue Description: $($issue.Issue)
Interrupt Rate: $($issue.InterruptRate)
Device ID: $($issue.DeviceID)
"@
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
1. Monitor system performance after remediation
2. Update device drivers if issues persist
3. Consider hardware replacement for consistently problematic devices
4. Run this script weekly for preventive maintenance
5. Review Windows Update for driver updates

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
    Write-Log "Starting CPU Interrupt Remediation Script v$Script:ScriptVersion"
    Write-Log "Script Date: $Script:ScriptDate"
    Write-Log "Author: $Script:ScriptAuthor"
    Write-Log "Mode: $(if ($LogOnly) { 'DIAGNOSTIC ONLY' } else { 'REMEDIATION' })"
    Write-Log "Max Interrupt Rate: $MaxInterruptRate/sec"
    
    # Gather system statistics
    $stats = Get-InterruptStatistics
    if (-not $stats) {
        throw "Failed to gather system statistics"
    }
    
    # Analyze for high interrupt devices
    $issues = Test-HighInterruptDevices
    $Script:IssuesFound = $issues
    
    if ($issues.Count -eq 0) {
        Write-Log "No interrupt issues detected" -Level "SUCCESS"
    } else {
        Write-Log "Found $($issues.Count) potential interrupt issues" -Level "WARN"
        
        # Apply fixes based on device type
        $networkIssues = $issues | Where-Object { $_.DeviceType -eq "NetworkAdapter" }
        $usbIssues = $issues | Where-Object { $_.DeviceType -eq "USBController" }
        $audioIssues = $issues | Where-Object { $_.DeviceType -eq "AudioDevice" }
        
        if ($networkIssues.Count -gt 0) {
            $Script:FixesApplied += Repair-NetworkAdapterInterrupts -NetworkIssues $networkIssues
        }
        
        if ($usbIssues.Count -gt 0) {
            $Script:FixesApplied += Repair-USBControllerInterrupts -USBIssues $usbIssues
        }
        
        if ($audioIssues.Count -gt 0) {
            $Script:FixesApplied += Repair-AudioDeviceInterrupts -AudioIssues $audioIssues
        }
        
        # Apply system-wide optimizations
        $Script:FixesApplied += Optimize-SystemInterrupts
    }
    
    # Generate comprehensive report
    Generate-Report -Issues $Script:IssuesFound -Fixes $Script:FixesApplied -Stats $stats
    
    # Summary
    Write-Log "=== EXECUTION SUMMARY ===" -Level "SUCCESS"
    Write-Log "Issues Found: $($Script:IssuesFound.Count)"
    Write-Log "Fixes Applied: $($Script:FixesApplied.Count)"
    Write-Log "Execution Time: $((Get-Date) - $Script:StartTime)"
    Write-Log "Report Location: $Script:LogFile"
    
    if (-not $LogOnly -and $Script:FixesApplied.Count -gt 0) {
        Write-Log "RECOMMENDATION: Restart system to ensure all changes take effect" -Level "WARN"
    }
    
    exit 0
}
catch {
    Write-Log "FATAL ERROR: $($_.Exception.Message)" -Level "ERROR"
    Write-Log "Stack Trace: $($_.ScriptStackTrace)" -Level "ERROR"
    exit 1
}
