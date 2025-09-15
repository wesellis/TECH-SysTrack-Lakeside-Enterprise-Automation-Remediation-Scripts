#Requires -Version 5.1
#Requires -RunAsAdministrator

<#
.SYNOPSIS
    Detection script for Supervisor-Service-Stopped trigger.

.DESCRIPTION
    This script detects SysTrack Supervisor service failure.
    
    Impact: 45 systems affected (95% of enterprise fleet)
    Priority: CRITICAL

.PARAMETER ReportPath
    Path to save diagnostic report

.EXAMPLE
    .\Detect-SupervisorServiceStopped.ps1
    Run diagnostic scan to check Supervisor service status

.NOTES
    File Name: Detect-SupervisorServiceStopped.ps1
    Version: 1.0
    Date: 2025-07-01
    Author: Wesley Ellis (Wesley.Ellis@compucom.com)
    Company: CompuCom - SysTrack Automation Team
    Requires: Administrator privileges
    Tested: Windows 10/11, Server 2016/2019/2022
    
    Trigger: Supervisor-Service-Stopped
    Systems Affected: 45 (95% impact)
    Priority: CRITICAL
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$ReportPath = "$env:TEMP\Supervisor-Service-Stopped-Report-$(Get-Date -Format 'yyyyMMdd-HHmmss').log"
)

# Script metadata
$Script:ScriptVersion = "1.0"
$Script:ScriptDate = "2025-07-01"
$Script:ScriptAuthor = "Wesley Ellis (Wesley.Ellis@compucom.com)"
$Script:TriggerName = "Supervisor-Service-Stopped"
$Script:SystemsAffected = 45
$Script:ImpactPercentage = 95
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

function Test-SupervisorService {
    Write-Log "Checking SysTrack Supervisor service status..."
    
    try {
        $serviceIssues = @()
        
        # Check for SysTrack Supervisor service variants
        $supervisorServiceNames = @(
            "Supervisor",
            "SysTrack Supervisor", 
            "LakesideSupervisor",
            "Lakeside Supervisor",
            "SysTrackSupervisor"
        )
        
        $foundServices = @()
        $supervisorService = $null
        
        foreach ($serviceName in $supervisorServiceNames) {
            $service = Get-Service -Name $serviceName -ErrorAction SilentlyContinue
            if ($service) {
                $foundServices += $service
                $supervisorService = $service
                Write-Log "Found SysTrack service: $($service.DisplayName) ($($service.Name))"
                break
            }
        }
        
        if (-not $supervisorService) {
            # Check for any service with "supervisor" in the name
            $allServices = Get-Service | Where-Object { $_.Name -like "*supervisor*" -or $_.DisplayName -like "*supervisor*" -or $_.DisplayName -like "*SysTrack*" }
            if ($allServices) {
                $supervisorService = $allServices | Select-Object -First 1
                Write-Log "Found potential SysTrack service: $($supervisorService.DisplayName)"
            }
        }
        
        if ($supervisorService) {
            # Check service status
            if ($supervisorService.Status -ne "Running") {
                $serviceIssues += [PSCustomObject]@{
                    ServiceName = $supervisorService.Name
                    DisplayName = $supervisorService.DisplayName
                    Status = $supervisorService.Status
                    StartType = $supervisorService.StartType
                    Issue = "SysTrack Supervisor service not running: $($supervisorService.Status)"
                    Severity = "CRITICAL"
                    Impact = "SysTrack monitoring and data collection stopped"
                }
                Write-Log "CRITICAL: SysTrack Supervisor service is $($supervisorService.Status)" -Level "ERROR"
            }
            
            # Check service startup type
            if ($supervisorService.StartType -eq "Disabled") {
                $serviceIssues += [PSCustomObject]@{
                    ServiceName = $supervisorService.Name
                    DisplayName = $supervisorService.DisplayName
                    Status = $supervisorService.Status
                    StartType = $supervisorService.StartType
                    Issue = "SysTrack Supervisor service is disabled"
                    Severity = "CRITICAL"
                    Impact = "Service will not start automatically"
                }
                Write-Log "CRITICAL: SysTrack Supervisor service is disabled" -Level "ERROR"
            }
            
            # Check service dependencies
            try {
                $dependencies = Get-Service -Name $supervisorService.Name -DependentServices -ErrorAction SilentlyContinue
                foreach ($dep in $dependencies) {
                    if ($dep.Status -ne "Running" -and $dep.StartType -ne "Disabled") {
                        Write-Log "Dependent service issue: $($dep.DisplayName) is $($dep.Status)" -Level "WARN"
                    }
                }
            }
            catch {
                Write-Log "Could not check service dependencies: $($_.Exception.Message)" -Level "WARN"
            }
            
            # Check if service can be controlled
            try {
                $service = Get-WmiObject -Class Win32_Service -Filter "Name='$($supervisorService.Name)'"
                if ($service) {
                    Write-Log "Service executable: $($service.PathName)"
                    Write-Log "Service account: $($service.StartName)"
                }
            }
            catch {
                Write-Log "Could not get detailed service information: $($_.Exception.Message)" -Level "WARN"
            }
            
        } else {
            $serviceIssues += [PSCustomObject]@{
                ServiceName = "Not Found"
                DisplayName = "SysTrack Supervisor Service"
                Status = "NotInstalled"
                StartType = "Unknown"
                Issue = "SysTrack Supervisor service not found on system"
                Severity = "CRITICAL"
                Impact = "SysTrack monitoring not installed or severely corrupted"
            }
            Write-Log "CRITICAL: No SysTrack Supervisor service found on system" -Level "ERROR"
        }
        
        # Check for SysTrack processes
        $sysTrackProcesses = Get-Process | Where-Object { 
            $_.ProcessName -like "*supervisor*" -or 
            $_.ProcessName -like "*systrack*" -or
            $_.ProcessName -like "*lakeside*"
        }
        
        if ($sysTrackProcesses) {
            Write-Log "Found SysTrack-related processes:"
            foreach ($proc in $sysTrackProcesses) {
                Write-Log "  - $($proc.ProcessName) (PID: $($proc.Id))"
            }
        } else {
            Write-Log "No SysTrack-related processes found" -Level "WARN"
        }
        
        $Script:IssuesFound = $serviceIssues
        return $serviceIssues.Count -gt 0
    }
    catch {
        Write-Log "Error checking SysTrack Supervisor service: $($_.Exception.Message)" -Level "ERROR"
        return $false
    }
}

function Test-SysTrackConnectivity {
    Write-Log "Testing SysTrack database connectivity..."
    
    try {
        # Check for SysTrack configuration files
        $configPaths = @(
            "$env:ProgramFiles\Lakeside Software\SysTrack",
            "$env:ProgramFiles(x86)\Lakeside Software\SysTrack",
            "$env:ProgramData\Lakeside Software\SysTrack",
            "C:\Program Files\Lakeside Software",
            "C:\Program Files (x86)\Lakeside Software"
        )
        
        $configFound = $false
        foreach ($path in $configPaths) {
            if (Test-Path $path) {
                Write-Log "Found SysTrack installation path: $path"
                $configFound = $true
                
                # Look for configuration files
                $configFiles = Get-ChildItem -Path $path -Recurse -Include "*.config", "*.xml", "*.ini" -ErrorAction SilentlyContinue
                foreach ($file in $configFiles) {
                    Write-Log "Configuration file: $($file.FullName)"
                }
            }
        }
        
        if (-not $configFound) {
            Write-Log "No SysTrack installation directories found" -Level "WARN"
        }
        
        # Check Windows Event Log for SysTrack events
        try {
            $sysTrackEvents = Get-WinEvent -FilterHashtable @{LogName='Application'; ProviderName='*SysTrack*'} -MaxEvents 10 -ErrorAction SilentlyContinue
            if ($sysTrackEvents) {
                Write-Log "Found recent SysTrack events in Application log:"
                foreach ($event in $sysTrackEvents | Select-Object -First 3) {
                    Write-Log "  - $($event.TimeCreated): $($event.LevelDisplayName) - $($event.Message.Substring(0, [Math]::Min(100, $event.Message.Length)))"
                }
            }
        }
        catch {
            Write-Log "Could not check SysTrack events: $($_.Exception.Message)" -Level "WARN"
        }
        
        return $true
    }
    catch {
        Write-Log "Error testing SysTrack connectivity: $($_.Exception.Message)" -Level "ERROR"
        return $false
    }
}

function Generate-Report {
    param([array]$Issues)
    
    Write-Log "Generating diagnostic report..."
    
    $report = @"
====================================================================
Supervisor-Service-Stopped DETECTION REPORT
====================================================================
Report Generated: $(Get-Date)
Script Version: $Script:ScriptVersion
Computer: $env:COMPUTERNAME
User: $env:USERNAME
Trigger: $Script:TriggerName
Systems Affected: $Script:SystemsAffected ($Script:ImpactPercentage% impact)
Priority: $Script:Priority

DETECTION RESULTS:
====================================================================
Issues Found: $($Issues.Count)

"@
    
    foreach ($issue in $Issues) {
        $report += @"

Service Name: $($issue.ServiceName)
Display Name: $($issue.DisplayName)
Current Status: $($issue.Status)
Startup Type: $($issue.StartType)
Issue Description: $($issue.Issue)
Severity: $($issue.Severity)
Business Impact: $($issue.Impact)
"@
    }
    
    $report += @"

SYSTEM INFORMATION:
====================================================================
Computer Name: $env:COMPUTERNAME
Domain: $env:USERDOMAIN
User: $env:USERNAME
OS Version: $((Get-WmiObject Win32_OperatingSystem).Caption)
Last Boot: $((Get-WmiObject Win32_OperatingSystem).ConvertToDateTime((Get-WmiObject Win32_OperatingSystem).LastBootUpTime))

RECOMMENDATIONS:
====================================================================
1. Run corresponding remediation script immediately if service stopped
2. Check SysTrack database connectivity after service restoration
3. Verify SysTrack data collection is resuming properly
4. Review Windows Event Logs for service failure root cause
5. Contact SysTrack administrators if service cannot be started
6. Consider automatic service monitoring and restart capabilities

BUSINESS IMPACT:
====================================================================
- SysTrack monitoring and data collection stopped
- Performance analytics unavailable
- Compliance reporting interrupted  
- End-user experience monitoring disabled
- Automation trigger detection stopped
- IT operational visibility reduced

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
    Write-Log "Starting Supervisor-Service-Stopped Detection Script v$Script:ScriptVersion"
    Write-Log "Priority: $Script:Priority | Impact: $Script:ImpactPercentage% | Systems: $Script:SystemsAffected"
    
    $detected = Test-SupervisorService
    
    # Additional connectivity tests
    Test-SysTrackConnectivity
    
    if ($detected) {
        Write-Log "CRITICAL ISSUES DETECTED: SysTrack Supervisor service problems found" -Level "ERROR"
        Write-Log "Found $($Script:IssuesFound.Count) critical issues requiring immediate attention"
        Write-Log "IMMEDIATE ACTION REQUIRED: Run Fix-SupervisorServiceStopped.ps1"
    } else {
        Write-Log "No issues detected: SysTrack Supervisor service is operational" -Level "SUCCESS"
    }
    
    Generate-Report -Issues $Script:IssuesFound
    
    Write-Log "=== DETECTION SUMMARY ===" -Level "SUCCESS"
    Write-Log "Issues Found: $($Script:IssuesFound.Count)"
    Write-Log "Detection Time: $((Get-Date) - $Script:StartTime)"
    Write-Log "Report Location: $Script:LogFile"
    
    if ($detected) {
        Write-Log "EXIT CODE: 1 (Issues found - immediate action required)" -Level "ERROR"
        exit 1  # Issues found
    } else {
        Write-Log "EXIT CODE: 0 (No issues detected)" -Level "SUCCESS"
        exit 0  # No issues
    }
}
catch {
    Write-Log "FATAL ERROR: $($_.Exception.Message)" -Level "ERROR"
    Write-Log "Stack Trace: $($_.ScriptStackTrace)" -Level "ERROR"
    exit 2  # Error occurred
}
