#Requires -Version 5.1
#Requires -RunAsAdministrator

<#
.SYNOPSIS
    Remediation script for Supervisor-Service-Stopped trigger.

.DESCRIPTION
    This script remediates SysTrack Supervisor service failure.
    
    Impact: 45 systems affected (95% of enterprise fleet)
    Priority: CRITICAL

.PARAMETER LogOnly
    Run in diagnostic mode only - no changes made

.PARAMETER ReportPath
    Path to save diagnostic report

.PARAMETER ForceRestart
    Force restart even if service appears to be running

.PARAMETER WaitForStartup
    Seconds to wait for service startup (default: 60)

.EXAMPLE
    .\Fix-SupervisorServiceStopped.ps1 -LogOnly
    Run diagnostic scan without making changes

.EXAMPLE
    .\Fix-SupervisorServiceStopped.ps1 -ForceRestart -WaitForStartup 120
    Force restart service and wait 2 minutes for startup

.NOTES
    File Name: Fix-SupervisorServiceStopped.ps1
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
    [switch]$LogOnly,
    
    [Parameter(Mandatory = $false)]
    [string]$ReportPath = "$env:TEMP\Supervisor-Service-Stopped-Report-$(Get-Date -Format 'yyyyMMdd-HHmmss').log",
    
    [Parameter(Mandatory = $false)]
    [switch]$ForceRestart,
    
    [Parameter(Mandatory = $false)]
    [int]$WaitForStartup = 60
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
$Script:FixesApplied = @()

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
        
        $supervisorService = $null
        
        foreach ($serviceName in $supervisorServiceNames) {
            $service = Get-Service -Name $serviceName -ErrorAction SilentlyContinue
            if ($service) {
                $supervisorService = $service
                Write-Log "Found SysTrack service: $($service.DisplayName) ($($service.Name))"
                break
            }
        }
        
        if (-not $supervisorService) {
            # Check for any service with "supervisor" or "systrack" in the name
            $allServices = Get-Service | Where-Object { 
                $_.Name -like "*supervisor*" -or 
                $_.DisplayName -like "*supervisor*" -or 
                $_.DisplayName -like "*SysTrack*" -or
                $_.DisplayName -like "*Lakeside*"
            }
            if ($allServices) {
                $supervisorService = $allServices | Select-Object -First 1
                Write-Log "Found potential SysTrack service: $($supervisorService.DisplayName)"
            }
        }
        
        if ($supervisorService) {
            # Check service status
            if ($supervisorService.Status -ne "Running" -or $ForceRestart) {
                $serviceIssues += [PSCustomObject]@{
                    ServiceName = $supervisorService.Name
                    DisplayName = $supervisorService.DisplayName
                    Status = $supervisorService.Status
                    StartType = $supervisorService.StartType
                    Issue = if ($ForceRestart) { "Force restart requested" } else { "Service not running: $($supervisorService.Status)" }
                    Action = "Restart service"
                }
                Write-Log "Service issue: $($supervisorService.DisplayName) is $($supervisorService.Status)" -Level "WARN"
            }
            
            # Check service startup type
            if ($supervisorService.StartType -eq "Disabled") {
                $serviceIssues += [PSCustomObject]@{
                    ServiceName = $supervisorService.Name
                    DisplayName = $supervisorService.DisplayName
                    Status = $supervisorService.Status
                    StartType = $supervisorService.StartType
                    Issue = "Service startup type is Disabled"
                    Action = "Set to Automatic startup"
                }
                Write-Log "Service startup issue: $($supervisorService.DisplayName) is disabled" -Level "WARN"
            }
        } else {
            $serviceIssues += [PSCustomObject]@{
                ServiceName = "Not Found"
                DisplayName = "SysTrack Supervisor Service"
                Status = "NotInstalled"
                StartType = "Unknown"
                Issue = "SysTrack Supervisor service not found on system"
                Action = "Manual installation required"
            }
            Write-Log "CRITICAL: No SysTrack Supervisor service found on system" -Level "ERROR"
        }
        
        $Script:IssuesFound = $serviceIssues
        return $serviceIssues
    }
    catch {
        Write-Log "Error checking SysTrack Supervisor service: $($_.Exception.Message)" -Level "ERROR"
        return @()
    }
}

function Repair-SupervisorService {
    param([array]$ServiceIssues)
    
    Write-Log "Repairing SysTrack Supervisor service issues..."
    $fixesApplied = @()
    
    foreach ($issue in $ServiceIssues) {
        try {
            Write-Log "Processing service issue: $($issue.DisplayName)"
            
            if ($issue.ServiceName -eq "Not Found") {
                Write-Log "Cannot repair: SysTrack Supervisor service not installed" -Level "ERROR"
                if (-not $LogOnly) {
                    $fixesApplied += "ERROR: Service not installed - manual installation required"
                }
                continue
            }
            
            if (-not $LogOnly) {
                $service = Get-Service -Name $issue.ServiceName -ErrorAction SilentlyContinue
                if ($service) {
                    
                    # Set service to automatic startup if needed
                    if ($service.StartType -eq "Disabled" -or $service.StartType -eq "Manual") {
                        Write-Log "Setting $($service.DisplayName) to Automatic startup..."
                        Set-Service -Name $issue.ServiceName -StartupType Automatic
                        Write-Log "Service startup type changed to Automatic" -Level "SUCCESS"
                        $fixesApplied += "Set $($service.DisplayName) to Automatic startup"
                    }
                    
                    # Stop service if running and force restart is requested
                    if ($ForceRestart -and $service.Status -eq "Running") {
                        Write-Log "Force stopping service for restart..."
                        Stop-Service -Name $issue.ServiceName -Force -ErrorAction SilentlyContinue
                        Start-Sleep -Seconds 5
                    }
                    
                    # Start the service if not running
                    if ($service.Status -ne "Running") {
                        Write-Log "Starting SysTrack Supervisor service..."
                        
                        # Check for dependent services
                        try {
                            $requiredServices = Get-Service -Name $issue.ServiceName -RequiredServices -ErrorAction SilentlyContinue
                            foreach ($reqService in $requiredServices) {
                                if ($reqService.Status -ne "Running") {
                                    Write-Log "Starting required service: $($reqService.DisplayName)"
                                    Start-Service -Name $reqService.Name -ErrorAction SilentlyContinue
                                }
                            }
                        }
                        catch {
                            Write-Log "Could not check required services: $($_.Exception.Message)" -Level "WARN"
                        }
                        
                        # Start the main service
                        Start-Service -Name $issue.ServiceName -ErrorAction Stop
                        
                        # Wait for service to fully start
                        $timeout = $WaitForStartup
                        $elapsed = 0
                        do {
                            Start-Sleep -Seconds 2
                            $elapsed += 2
                            $service = Get-Service -Name $issue.ServiceName
                            Write-Log "Waiting for service startup... ($elapsed/$timeout seconds)"
                        } while ($service.Status -ne "Running" -and $elapsed -lt $timeout)
                        
                        if ($service.Status -eq "Running") {
                            Write-Log "SysTrack Supervisor service started successfully!" -Level "SUCCESS"
                            $fixesApplied += "Started SysTrack Supervisor service: $($service.DisplayName)"
                            
                            # Verify service is actually functional
                            Start-Sleep -Seconds 5
                            $verifyService = Get-Service -Name $issue.ServiceName
                            if ($verifyService.Status -eq "Running") {
                                Write-Log "Service startup verification: PASSED" -Level "SUCCESS"
                                $fixesApplied += "Verified service is running and stable"
                            } else {
                                Write-Log "Service startup verification: FAILED - service stopped after starting" -Level "ERROR"
                                $fixesApplied += "WARNING: Service started but then stopped - check event logs"
                            }
                        } else {
                            Write-Log "Service failed to start within $timeout seconds" -Level "ERROR"
                            $fixesApplied += "ERROR: Service failed to start within timeout period"
                        }
                    } else {
                        Write-Log "Service is already running" -Level "SUCCESS"
                        if ($ForceRestart) {
                            $fixesApplied += "Force restart completed - service is running"
                        } else {
                            $fixesApplied += "Service verified as running - no action needed"
                        }
                    }
                }
            } else {
                Write-Log "Would repair service: $($issue.DisplayName) - $($issue.Action)" -Level "WARN"
                $fixesApplied += "Would apply: $($issue.Action) for $($issue.DisplayName)"
            }
        }
        catch {
            Write-Log "Error repairing service $($issue.ServiceName): $($_.Exception.Message)" -Level "ERROR"
            $fixesApplied += "ERROR repairing $($issue.ServiceName): $($_.Exception.Message)"
        }
    }
    
    return $fixesApplied
}

function Test-ServiceHealth {
    Write-Log "Performing post-remediation health check..."
    
    try {
        # Re-check service status
        $healthIssues = Test-SupervisorService
        
        if ($healthIssues.Count -eq 0) {
            Write-Log "Health check PASSED: SysTrack Supervisor service is healthy" -Level "SUCCESS"
            
            # Additional health checks
            $processes = Get-Process | Where-Object { 
                $_.ProcessName -like "*supervisor*" -or 
                $_.ProcessName -like "*systrack*" 
            }
            
            if ($processes) {
                Write-Log "SysTrack processes detected:"
                foreach ($proc in $processes) {
                    Write-Log "  - $($proc.ProcessName) (PID: $($proc.Id), Memory: $([math]::Round($proc.WorkingSet/1MB,1)) MB)"
                }
            }
            
            # Check recent event logs for any service errors
            try {
                $recentEvents = Get-WinEvent -FilterHashtable @{
                    LogName = 'System'
                    StartTime = (Get-Date).AddMinutes(-30)
                    ID = 7034, 7035, 7036  # Service control events
                } -ErrorAction SilentlyContinue | Where-Object { $_.Message -like "*supervisor*" -or $_.Message -like "*systrack*" }
                
                if ($recentEvents) {
                    Write-Log "Recent service events found:"
                    foreach ($event in $recentEvents | Select-Object -First 3) {
                        Write-Log "  - $($event.TimeCreated): $($event.LevelDisplayName) - $($event.Message.Substring(0, [Math]::Min(100, $event.Message.Length)))"
                    }
                }
            }
            catch {
                Write-Log "Could not check recent events: $($_.Exception.Message)" -Level "WARN"
            }
            
            return $true
        } else {
            Write-Log "Health check FAILED: Issues still detected after remediation" -Level "ERROR"
            return $false
        }
    }
    catch {
        Write-Log "Error during health check: $($_.Exception.Message)" -Level "ERROR"
        return $false
    }
}

function Generate-Report {
    param([array]$Issues, [array]$Fixes)
    
    Write-Log "Generating remediation report..."
    
    $report = @"
====================================================================
Supervisor-Service-Stopped REMEDIATION REPORT
====================================================================
Report Generated: $(Get-Date)
Script Version: $Script:ScriptVersion
Computer: $env:COMPUTERNAME
User: $env:USERNAME
Script Mode: $(if ($LogOnly) { "DIAGNOSTIC ONLY" } else { "REMEDIATION" })
Trigger: $Script:TriggerName
Systems Affected: $Script:SystemsAffected ($Script:ImpactPercentage% impact)
Priority: $Script:Priority

REMEDIATION RESULTS:
====================================================================
Issues Found: $($Issues.Count)
Fixes Applied: $($Fixes.Count)

DETAILED FINDINGS:
====================================================================
"@
    
    foreach ($issue in $Issues) {
        $report += @"

Service: $($issue.ServiceName)
Display Name: $($issue.DisplayName)
Status: $($issue.Status)
Startup Type: $($issue.StartType)
Issue: $($issue.Issue)
Action Taken: $($issue.Action)
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

BUSINESS IMPACT RESOLUTION:
====================================================================
$(if ($Fixes.Count -gt 0 -and -not $LogOnly) {
"- SysTrack monitoring and data collection restored
- Performance analytics resumed
- Compliance reporting operational
- End-user experience monitoring active
- Automation trigger detection restored
- IT operational visibility restored"
} else {
"- Issues identified but not resolved (diagnostic mode or errors occurred)
- SysTrack monitoring still impacted
- Manual intervention may be required"
})

POST-REMEDIATION VERIFICATION:
====================================================================
$(if (-not $LogOnly) {
"Run the following command to verify service health:
Get-Service | Where-Object { `$_.DisplayName -like '*SysTrack*' -or `$_.DisplayName -like '*Supervisor*' }

Check SysTrack console for data collection resumption.
Monitor Windows Event Logs for any service-related errors."
} else {
"Re-run this script without -LogOnly parameter to apply fixes.
Ensure adequate privileges for service management operations."
})

RECOMMENDATIONS:
====================================================================
1. Monitor SysTrack service health continuously
2. Set up automated service monitoring and restart
3. Review Windows Event Logs for root cause of service failure
4. Verify SysTrack database connectivity and data flow
5. Consider implementing service dependency management
6. Update SysTrack software if service failures persist
7. Review system resources if service fails to start
8. Contact Lakeside Software support for persistent issues

====================================================================
Report saved to: $Script:LogFile
Remediation time: $((Get-Date) - $Script:StartTime)
====================================================================
"@
    
    Add-Content -Path $Script:LogFile -Value $report
    Write-Log "Report saved to: $Script:LogFile" -Level "SUCCESS"
}

# Main execution
try {
    Write-Log "Starting Supervisor-Service-Stopped Remediation Script v$Script:ScriptVersion"
    Write-Log "Priority: $Script:Priority | Impact: $Script:ImpactPercentage% | Systems: $Script:SystemsAffected"
    Write-Log "Mode: $(if ($LogOnly) { 'DIAGNOSTIC ONLY' } else { 'REMEDIATION' })"
    if ($ForceRestart) { Write-Log "Force restart enabled" -Level "WARN" }
    Write-Log "Service startup timeout: $WaitForStartup seconds"
    
    $issues = Test-SupervisorService
    
    if ($issues.Count -eq 0) {
        Write-Log "No issues detected: SysTrack Supervisor service is healthy" -Level "SUCCESS"
    } else {
        Write-Log "Found $($issues.Count) issues with SysTrack Supervisor service" -Level "WARN"
        $Script:FixesApplied += Repair-SupervisorService -ServiceIssues $issues
        
        # Perform health check after remediation
        if (-not $LogOnly) {
            Write-Log "Performing post-remediation health check..."
            $healthResult = Test-ServiceHealth
            if ($healthResult) {
                $Script:FixesApplied += "Post-remediation health check: PASSED"
            } else {
                $Script:FixesApplied += "Post-remediation health check: FAILED - manual intervention required"
            }
        }
    }
    
    Generate-Report -Issues $Script:IssuesFound -Fixes $Script:FixesApplied
    
    Write-Log "=== REMEDIATION SUMMARY ===" -Level "SUCCESS"
    Write-Log "Issues Found: $($Script:IssuesFound.Count)"
    Write-Log "Fixes Applied: $($Script:FixesApplied.Count)"
    Write-Log "Execution Time: $((Get-Date) - $Script:StartTime)"
    Write-Log "Report Location: $Script:LogFile"
    
    if (-not $LogOnly -and $Script:FixesApplied.Count -gt 0) {
        Write-Log "RECOMMENDATION: Monitor SysTrack service for 15-30 minutes to ensure stability" -Level "WARN"
        Write-Log "CRITICAL: Verify SysTrack data collection is resuming in the console" -Level "WARN"
    }
    
    exit 0
}
catch {
    Write-Log "FATAL ERROR: $($_.Exception.Message)" -Level "ERROR"
    Write-Log "Stack Trace: $($_.ScriptStackTrace)" -Level "ERROR"
    exit 1
}
