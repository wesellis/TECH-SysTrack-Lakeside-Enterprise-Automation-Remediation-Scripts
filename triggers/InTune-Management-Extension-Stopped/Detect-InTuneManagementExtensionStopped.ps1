#Requires -Version 5.1
#Requires -RunAsAdministrator

<#
.SYNOPSIS
    Detection script for InTune-Management-Extension-Stopped trigger.

.DESCRIPTION
    This script detects Microsoft Intune Management Extension service failure affecting device management.
    
    Impact: 65 systems affected (70% of enterprise fleet)
    Priority: CRITICAL
    
.PARAMETER ReportPath
    Path to save diagnostic report

.EXAMPLE
    .\Detect-InTuneManagementExtensionStopped.ps1
    Run diagnostic scan

.NOTES
    File Name: Detect-InTuneManagementExtensionStopped.ps1
    Version: 1.0
    Date: 2025-07-01
    Author: Wesley Ellis (Wesley.Ellis@compucom.com)
    Company: CompuCom - SysTrack Automation Team
    Requires: Administrator privileges
    Tested: Windows 10/11, Server 2016/2019/2022
    
    Trigger: InTune-Management-Extension-Stopped
    Systems Affected: 65 (70% impact)
    Priority: CRITICAL
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$ReportPath = "$env:TEMP\InTune-Management-Extension-Stopped-Report-$(Get-Date -Format 'yyyyMMdd-HHmmss').log"
)

# Script metadata
$Script:ScriptVersion = "1.0"
$Script:ScriptDate = "2025-07-01"
$Script:ScriptAuthor = "Wesley Ellis (Wesley.Ellis@compucom.com)"
$Script:TriggerName = "InTune-Management-Extension-Stopped"
$Script:SystemsAffected = 65
$Script:ImpactPercentage = 70
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

function Test-ServiceStatus {
    Write-Log "Checking Microsoft Intune Management Extension service status..."
    
    try {
        # Microsoft Intune Management Extension service names
        $intuneServices = @("Microsoft Intune Management Extension", "IntuneManagementExtension")
        $serviceIssues = @()
        
        foreach ($serviceName in $intuneServices) {
            $service = Get-Service -Name $serviceName -ErrorAction SilentlyContinue
            if ($service) {
                Write-Log "Found service: $($service.DisplayName) ($($service.Name))"
                
                if ($service.Status -ne "Running") {
                    $serviceIssues += [PSCustomObject]@{
                        ServiceName = $service.Name
                        DisplayName = $service.DisplayName
                        Status = $service.Status
                        StartType = $service.StartType
                        Issue = "Microsoft Intune Management Extension service not running: $($service.Status)"
                        BusinessImpact = "Device management and policy enforcement disabled"
                        Severity = "CRITICAL"
                    }
                    Write-Log "CRITICAL: Microsoft Intune Management Extension service is $($service.Status)" -Level "ERROR"
                } else {
                    Write-Log "Microsoft Intune Management Extension service is running normally" -Level "SUCCESS"
                    
                    # Additional health checks for running service
                    try {
                        # Check if service is responding (basic health check)
                        $serviceProcess = Get-Process -Name $service.Name -ErrorAction SilentlyContinue
                        if (-not $serviceProcess) {
                            $serviceIssues += [PSCustomObject]@{
                                ServiceName = $service.Name
                                DisplayName = $service.DisplayName
                                Status = "Running-NoProcess"
                                StartType = $service.StartType
                                Issue = "Service shows running but no process found"
                                BusinessImpact = "Potential service instability"
                                Severity = "HIGH"
                            }
                            Write-Log "WARNING: Service running but no associated process found" -Level "WARN"
                        }
                    }
                    catch {
                        Write-Log "Could not verify service process: $($_.Exception.Message)" -Level "WARN"
                    }
                }
                break  # Found the service, exit loop
            }
        }
        
        # If no Intune service found
        if (-not $service) {
            $serviceIssues += [PSCustomObject]@{
                ServiceName = "Microsoft Intune Management Extension"
                DisplayName = "Microsoft Intune Management Extension"
                Status = "NotFound"
                StartType = "Unknown"
                Issue = "Microsoft Intune Management Extension service not found on system"
                BusinessImpact = "Intune management capability not available"
                Severity = "CRITICAL"
            }
            Write-Log "CRITICAL: Microsoft Intune Management Extension service not found on system" -Level "ERROR"
        }
        
        $Script:IssuesFound = $serviceIssues
        return $serviceIssues.Count -gt 0
    }
    catch {
        Write-Log "Error checking Microsoft Intune Management Extension service: $($_.Exception.Message)" -Level "ERROR"
        return $false
    }
}

function Test-IntuneManagementExtensionHealth {
    Write-Log "Performing additional Intune Management Extension health checks..."
    
    try {
        $additionalIssues = @()
        
        # Check for Intune-related registry entries
        $intuneRegPath = "HKLM:\SOFTWARE\Microsoft\IntuneManagementExtension"
        if (Test-Path $intuneRegPath) {
            Write-Log "Intune Management Extension registry entries found" -Level "SUCCESS"
        } else {
            $additionalIssues += [PSCustomObject]@{
                Component = "Registry"
                Issue = "Intune Management Extension registry path not found"
                Path = $intuneRegPath
                BusinessImpact = "Intune configuration may be incomplete"
                Severity = "HIGH"
            }
            Write-Log "WARNING: Intune Management Extension registry path not found" -Level "WARN"
        }
        
        # Check for Intune logs directory
        $intuneLogsPath = "$env:ProgramData\Microsoft\IntuneManagementExtension\Logs"
        if (Test-Path $intuneLogsPath) {
            Write-Log "Intune Management Extension logs directory found" -Level "SUCCESS"
            
            # Check for recent log activity
            $recentLogs = Get-ChildItem -Path $intuneLogsPath -Filter "*.log" | 
                         Where-Object { $_.LastWriteTime -gt (Get-Date).AddHours(-24) }
            
            if ($recentLogs.Count -eq 0) {
                $additionalIssues += [PSCustomObject]@{
                    Component = "Logging"
                    Issue = "No recent Intune Management Extension log activity (24 hours)"
                    Path = $intuneLogsPath
                    BusinessImpact = "Service may not be functioning properly"
                    Severity = "MEDIUM"
                }
                Write-Log "WARNING: No recent Intune log activity detected" -Level "WARN"
            } else {
                Write-Log "Recent Intune log activity detected: $($recentLogs.Count) files" -Level "SUCCESS"
            }
        } else {
            $additionalIssues += [PSCustomObject]@{
                Component = "Logs"
                Issue = "Intune Management Extension logs directory not found"
                Path = $intuneLogsPath
                BusinessImpact = "Cannot verify service operation"
                Severity = "MEDIUM"
            }
            Write-Log "WARNING: Intune logs directory not found" -Level "WARN"
        }
        
        # Add additional issues to main issues list
        $Script:IssuesFound += $additionalIssues
        
        return $additionalIssues.Count -gt 0
    }
    catch {
        Write-Log "Error checking Intune Management Extension health: $($_.Exception.Message)" -Level "ERROR"
        return $false
    }
}

function Generate-Report {
    param([array]$Issues)
    
    Write-Log "Generating diagnostic report..."
    
    $report = @"
====================================================================
InTune-Management-Extension-Stopped DETECTION REPORT
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
        $report += "Issue: $($issue | ConvertTo-Json -Compress)`n"
    }
    
    $report += @"

BUSINESS IMPACT ANALYSIS:
====================================================================
Service Function: Microsoft Intune Management Extension handles:
- Device enrollment and management
- Policy deployment and enforcement
- Application installation and updates
- Security configuration management
- Compliance monitoring

Impact of Service Failure:
- Device management policies not enforced
- Software deployment failures
- Security configurations not applied
- Compliance reporting disrupted
- End-user productivity impacted

RECOMMENDATIONS:
====================================================================
1. Run corresponding remediation script immediately if issues found
2. Monitor Intune admin console for device status
3. Check Azure AD device registration status
4. Verify network connectivity to Intune service endpoints
5. Review Windows event logs for additional error details

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
    Write-Log "Starting $Script:TriggerName Detection Script v$Script:ScriptVersion"
    Write-Log "Priority: $Script:Priority | Impact: $Script:ImpactPercentage% | Systems: $Script:SystemsAffected"
    
    # Primary detection: Service status
    $serviceIssues = Test-ServiceStatus
    
    # Secondary detection: Additional health checks
    $healthIssues = Test-IntuneManagementExtensionHealth
    
    $totalIssues = $serviceIssues -or $healthIssues
    
    if ($totalIssues) {
        Write-Log "Issues detected for $Script:TriggerName" -Level "WARN"
        Write-Log "Found $($Script:IssuesFound.Count) issues requiring attention"
        
        # Categorize issues by severity
        $criticalIssues = $Script:IssuesFound | Where-Object { $_.Severity -eq "CRITICAL" }
        $highIssues = $Script:IssuesFound | Where-Object { $_.Severity -eq "HIGH" }
        $mediumIssues = $Script:IssuesFound | Where-Object { $_.Severity -eq "MEDIUM" }
        
        if ($criticalIssues.Count -gt 0) {
            Write-Log "CRITICAL issues found: $($criticalIssues.Count) - Immediate action required!" -Level "ERROR"
        }
        if ($highIssues.Count -gt 0) {
            Write-Log "HIGH priority issues found: $($highIssues.Count)" -Level "WARN"
        }
        if ($mediumIssues.Count -gt 0) {
            Write-Log "MEDIUM priority issues found: $($mediumIssues.Count)" -Level "WARN"
        }
    } else {
        Write-Log "No issues detected for $Script:TriggerName" -Level "SUCCESS"
        Write-Log "Microsoft Intune Management Extension service is functioning normally" -Level "SUCCESS"
    }
    
    Generate-Report -Issues $Script:IssuesFound
    
    Write-Log "=== DETECTION SUMMARY ===" -Level "SUCCESS"
    Write-Log "Issues Found: $($Script:IssuesFound.Count)"
    Write-Log "Detection Time: $((Get-Date) - $Script:StartTime)"
    Write-Log "Report Location: $Script:LogFile"
    
    if ($totalIssues) {
        Write-Log "RECOMMENDATION: Run Fix-InTuneManagementExtensionStopped.ps1 to remediate issues" -Level "WARN"
        exit 1  # Issues found
    } else {
        exit 0  # No issues
    }
}
catch {
    Write-Log "FATAL ERROR: $($_.Exception.Message)" -Level "ERROR"
    Write-Log "Stack Trace: $($_.ScriptStackTrace)" -Level "ERROR"
    exit 2  # Error occurred
}