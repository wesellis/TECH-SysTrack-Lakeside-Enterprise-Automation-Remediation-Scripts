#Requires -Version 5.1
#Requires -RunAsAdministrator

<#
.SYNOPSIS
    Remediation script for Qualys-Cloud-Agent-Stopped trigger.

.DESCRIPTION
    This script remediates Qualys Cloud Agent service failure affecting security scanning.
    
    Impact: 25 systems affected (88% of enterprise fleet)
    Priority: CRITICAL
    
.PARAMETER LogOnly
    Run in diagnostic mode only - no changes made

.PARAMETER ReportPath
    Path to save diagnostic report

.EXAMPLE
    .\Fix-QualysCloudAgentStopped.ps1 -LogOnly
    Run diagnostic scan without making changes

.EXAMPLE
    .\Fix-QualysCloudAgentStopped.ps1
    Execute remediation actions

.NOTES
    File Name: Fix-QualysCloudAgentStopped.ps1
    Version: 1.0
    Date: 2025-07-01
    Author: Wesley Ellis (Wesley.Ellis@compucom.com)
    Company: CompuCom - SysTrack Automation Team
    Requires: Administrator privileges
    Tested: Windows 10/11, Server 2016/2019/2022
    
    Trigger: Qualys-Cloud-Agent-Stopped
    Systems Affected: 25 (88% impact)
    Priority: CRITICAL
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [switch]$LogOnly,
    
    [Parameter(Mandatory = $false)]
    [string]$ReportPath = "$env:TEMP\Qualys-Cloud-Agent-Stopped-Report-$(Get-Date -Format 'yyyyMMdd-HHmmss').log"
)

# Script metadata
$Script:ScriptVersion = "1.0"
$Script:ScriptDate = "2025-07-01"
$Script:ScriptAuthor = "Wesley Ellis (Wesley.Ellis@compucom.com)"
$Script:TriggerName = "Qualys-Cloud-Agent-Stopped"
$Script:SystemsAffected = 25
$Script:ImpactPercentage = 88
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

function Test-QualysServices {
    Write-Log "Checking Qualys Cloud Agent service status..."
    
    try {
        $qualysServices = @("QualysAgent", "Qualys Cloud Agent", "QualysCloudAgent")
        $serviceIssues = @()
        
        foreach ($serviceName in $qualysServices) {
            $service = Get-Service -Name $serviceName -ErrorAction SilentlyContinue
            if ($service -and $service.Status -ne "Running") {
                $serviceIssues += [PSCustomObject]@{
                    ServiceName = $service.Name
                    DisplayName = $service.DisplayName
                    Status = $service.Status
                    StartType = $service.StartType
                    Issue = "Service not running"
                    Severity = "CRITICAL"
                }
            }
        }
        
        $Script:IssuesFound = $serviceIssues
        return $serviceIssues
    }
    catch {
        Write-Log "Error checking Qualys services: $($_.Exception.Message)" -Level "ERROR"
        return @()
    }
}

function Repair-QualysServiceIssues {
    param([array]$ServiceIssues)
    
    Write-Log "Repairing Qualys Cloud Agent service issues..."
    $fixesApplied = @()
    
    foreach ($issue in $ServiceIssues) {
        try {
            Write-Log "Processing service: $($issue.ServiceName)"
            
            if (-not $LogOnly) {
                $service = Get-Service -Name $issue.ServiceName -ErrorAction SilentlyContinue
                if ($service) {
                    # Create backup of current service state
                    $backupInfo = @{
                        ServiceName = $service.Name
                        OriginalStatus = $service.Status
                        OriginalStartType = $service.StartType
                        BackupTime = Get-Date
                    }
                    $Script:ServiceBackups += $backupInfo
                    
                    # Set service to automatic if not already
                    if ($service.StartType -ne "Automatic") {
                        Write-Log "Setting $($issue.ServiceName) to Automatic startup"
                        Set-Service -Name $issue.ServiceName -StartupType Automatic
                        $fixesApplied += "Set $($issue.ServiceName) to Automatic startup"
                    }
                    
                    # Stop and restart the service to clear any issues
                    if ($service.Status -eq "Running") {
                        Write-Log "Restarting service: $($issue.DisplayName)"
                        Restart-Service -Name $issue.ServiceName -Force -ErrorAction Stop
                        $fixesApplied += "Restarted service: $($issue.DisplayName)"
                    } else {
                        Write-Log "Starting service: $($issue.DisplayName)"
                        Start-Service -Name $issue.ServiceName -ErrorAction Stop
                        $fixesApplied += "Started service: $($issue.DisplayName)"
                    }
                    
                    # Verify service started successfully
                    Start-Sleep -Seconds 5
                    $verifyService = Get-Service -Name $issue.ServiceName
                    if ($verifyService.Status -eq "Running") {
                        Write-Log "Service started successfully: $($issue.DisplayName)" -Level "SUCCESS"
                    } else {
                        Write-Log "Service failed to start: $($issue.DisplayName)" -Level "ERROR"
                    }
                }
            } else {
                Write-Log "Would repair service: $($issue.DisplayName)" -Level "WARN"
                $fixesApplied += "Would start service: $($issue.DisplayName)"
            }
        }
        catch {
            Write-Log "Error starting service $($issue.ServiceName): $($_.Exception.Message)" -Level "ERROR"
        }
    }
    
    # Additional Qualys-specific repairs
    if (-not $LogOnly) {
        try {
            # Force Qualys agent to check-in with cloud
            Write-Log "Forcing Qualys agent cloud check-in..."
            $qualysExe = Get-ChildItem -Path "${env:ProgramFiles}\Qualys" -Name "QualysAgent.exe" -Recurse -ErrorAction SilentlyContinue
            if ($qualysExe) {
                $qualysPath = $qualysExe.FullName
                & $qualysPath -checkin 2>$null
                if ($LASTEXITCODE -eq 0) {
                    $fixesApplied += "Forced Qualys cloud check-in"
                    Write-Log "Qualys cloud check-in initiated" -Level "SUCCESS"
                }
            }
        }
        catch {
            Write-Log "Error forcing Qualys check-in: $($_.Exception.Message)" -Level "ERROR"
        }
        
        try {
            # Clear Qualys cache and logs if needed
            $cacheCleared = $false
            $cachePaths = @(
                "$env:ProgramData\Qualys\QualysAgent\cache",
                "$env:ProgramFiles\Qualys\QualysAgent\cache"
            )
            
            foreach ($cachePath in $cachePaths) {
                if (Test-Path $cachePath) {
                    Write-Log "Clearing Qualys cache: $cachePath"
                    Get-ChildItem -Path $cachePath -File | Remove-Item -Force -ErrorAction SilentlyContinue
                    $cacheCleared = $true
                }
            }
            
            if ($cacheCleared) {
                $fixesApplied += "Cleared Qualys agent cache"
                Write-Log "Qualys cache cleared" -Level "SUCCESS"
            }
        }
        catch {
            Write-Log "Error clearing Qualys cache: $($_.Exception.Message)" -Level "ERROR"
        }
        
        try {
            # Verify Qualys cloud connectivity
            Write-Log "Testing Qualys cloud connectivity..."
            $testEndpoint = "qualysguard.qualys.com"
            $connectTest = Test-Connection -ComputerName $testEndpoint -Count 2 -ErrorAction SilentlyContinue
            if ($connectTest) {
                $fixesApplied += "Verified Qualys cloud connectivity"
                Write-Log "Qualys cloud connectivity verified" -Level "SUCCESS"
            } else {
                Write-Log "Cannot reach Qualys cloud - check firewall/network" -Level "WARN"
            }
        }
        catch {
            Write-Log "Error testing connectivity: $($_.Exception.Message)" -Level "ERROR"
        }
    }
    
    return $fixesApplied
}

function Test-PostRepair {
    Write-Log "Performing post-repair validation..."
    
    try {
        $validationResults = @()
        
        # Verify Qualys services are running
        $services = @("QualysAgent", "Qualys Cloud Agent", "QualysCloudAgent")
        foreach ($serviceName in $services) {
            $service = Get-Service -Name $serviceName -ErrorAction SilentlyContinue
            if ($service -and $service.Status -eq "Running") {
                $validationResults += "$serviceName service: RUNNING"
                Write-Log "$serviceName service running" -Level "SUCCESS"
            } elseif ($service) {
                $validationResults += "$serviceName service: $($service.Status)"
                Write-Log "$serviceName service not running: $($service.Status)" -Level "WARN"
            }
        }
        
        # Test Qualys process health
        $qualysProcess = Get-Process -Name "QualysAgent" -ErrorAction SilentlyContinue
        if ($qualysProcess) {
            $memoryMB = [math]::Round($qualysProcess.WorkingSet / 1MB, 2)
            $validationResults += "Qualys process memory: $memoryMB MB"
            Write-Log "Qualys process using $memoryMB MB memory" -Level "SUCCESS"
        }
        
        # Check recent log activity
        $logPaths = @(
            "$env:ProgramFiles\Qualys\QualysAgent\log",
            "$env:ProgramData\Qualys\QualysAgent\log"
        )
        
        foreach ($logPath in $logPaths) {
            if (Test-Path $logPath) {
                $recentLogs = Get-ChildItem -Path $logPath -Filter "*.log" | 
                             Where-Object { $_.LastWriteTime -gt (Get-Date).AddMinutes(-30) }
                if ($recentLogs) {
                    $validationResults += "Recent log activity: DETECTED"
                    Write-Log "Recent Qualys log activity detected" -Level "SUCCESS"
                    break
                }
            }
        }
        
        return $validationResults
    }
    catch {
        Write-Log "Error during post-repair validation: $($_.Exception.Message)" -Level "ERROR"
        return @("Validation error occurred")
    }
}

function Generate-Report {
    param([array]$Issues, [array]$Fixes)
    
    Write-Log "Generating remediation report..."
    
    $report = @"
====================================================================
Qualys-Cloud-Agent-Stopped REMEDIATION REPORT
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
        $report += "Issue: $($issue | ConvertTo-Json -Compress)`n"
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
    
    # Add post-repair validation results
    if (-not $LogOnly -and $Fixes.Count -gt 0) {
        $validationResults = Test-PostRepair
        $report += @"

POST-REPAIR VALIDATION:
====================================================================
"@
        foreach ($result in $validationResults) {
            $report += "- $result`n"
        }
    }
    
    $report += @"

SECURITY SCANNING STATUS:
====================================================================
"@
    
    $services = @("QualysAgent", "Qualys Cloud Agent", "QualysCloudAgent")
    foreach ($serviceName in $services) {
        $service = Get-Service -Name $serviceName -ErrorAction SilentlyContinue
        if ($service) {
            $report += "- $($service.DisplayName): $($service.Status) ($($service.StartType))`n"
        }
    }
    
    $report += @"

RECOMMENDATIONS:
====================================================================
1. Monitor Qualys scanning schedules for next 24 hours
2. Verify vulnerability scans are resuming normally
3. Check Qualys console for agent connectivity
4. Review firewall rules for Qualys cloud endpoints
5. Schedule regular Qualys agent health monitoring
6. Verify compliance scan results are being reported

CRITICAL ACTIONS:
====================================================================
- Ensure Qualys activation key is properly configured
- Verify network connectivity to qualysguard.qualys.com
- Check Windows Event Logs for Qualys service errors
- Monitor security scan compliance status

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
    Write-Log "Starting $Script:TriggerName Remediation Script v$Script:ScriptVersion"
    Write-Log "Priority: $Script:Priority | Impact: $Script:ImpactPercentage% | Systems: $Script:SystemsAffected"
    Write-Log "Mode: $(if ($LogOnly) { 'DIAGNOSTIC ONLY' } else { 'REMEDIATION' })"
    
    $Script:ServiceBackups = @()
    $issues = Test-QualysServices
    
    if ($issues.Count -eq 0) {
        Write-Log "No Qualys Cloud Agent service issues detected" -Level "SUCCESS"
    } else {
        Write-Log "Found $($issues.Count) Qualys service issues" -Level "WARN"
        $Script:FixesApplied += Repair-QualysServiceIssues -ServiceIssues $issues
    }
    
    Generate-Report -Issues $Script:IssuesFound -Fixes $Script:FixesApplied
    
    Write-Log "=== REMEDIATION SUMMARY ===" -Level "SUCCESS"
    Write-Log "Issues Found: $($Script:IssuesFound.Count)"
    Write-Log "Fixes Applied: $($Script:FixesApplied.Count)"
    Write-Log "Execution Time: $((Get-Date) - $Script:StartTime)"
    Write-Log "Report Location: $Script:LogFile"
    
    if (-not $LogOnly -and $Script:FixesApplied.Count -gt 0) {
        Write-Log "RECOMMENDATION: Monitor vulnerability scanning and compliance status" -Level "WARN"
        Write-Log "CRITICAL: Verify Qualys cloud connectivity and activation" -Level "WARN"
    }
    
    exit 0
}
catch {
    Write-Log "FATAL ERROR: $($_.Exception.Message)" -Level "ERROR"
    Write-Log "Stack Trace: $($_.ScriptStackTrace)" -Level "ERROR"
    exit 1
}
