#Requires -Version 5.1
#Requires -RunAsAdministrator

<#
.SYNOPSIS
    Remediation script for Netlogon-Service-Stopped trigger.

.DESCRIPTION
    This script remediates Netlogon service failure preventing domain authentication.
    
    Impact: 25 systems affected (90% of enterprise fleet)
    Priority: CRITICAL
    
.PARAMETER LogOnly
    Run in diagnostic mode only - no changes made

.PARAMETER ReportPath
    Path to save diagnostic report

.EXAMPLE
    .\Fix-NetlogonServiceStopped.ps1 -LogOnly
    Run diagnostic scan without making changes

.EXAMPLE
    .\Fix-NetlogonServiceStopped.ps1
    Execute remediation actions

.NOTES
    File Name: Fix-NetlogonServiceStopped.ps1
    Version: 1.0
    Date: 2025-07-01
    Author: Wesley Ellis (Wesley.Ellis@compucom.com)
    Company: CompuCom - SysTrack Automation Team
    Requires: Administrator privileges
    Tested: Windows 10/11, Server 2016/2019/2022
    
    Trigger: Netlogon-Service-Stopped
    Systems Affected: 25 (90% impact)
    Priority: CRITICAL
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [switch]$LogOnly,
    
    [Parameter(Mandatory = $false)]
    [string]$ReportPath = "$env:TEMP\Netlogon-Service-Stopped-Report-$(Get-Date -Format 'yyyyMMdd-HHmmss').log"
)

# Script metadata
$Script:ScriptVersion = "1.0"
$Script:ScriptDate = "2025-07-01"
$Script:ScriptAuthor = "Wesley Ellis (Wesley.Ellis@compucom.com)"
$Script:TriggerName = "Netlogon-Service-Stopped"
$Script:SystemsAffected = 25
$Script:ImpactPercentage = 90
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

function Test-NetlogonService {
    Write-Log "Checking Netlogon service status..."
    
    try {
        $criticalServices = @("Netlogon", "NtLmSsp", "KDC", "DFSR")
        $serviceIssues = @()
        
        foreach ($serviceName in $criticalServices) {
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
        Write-Log "Error checking Netlogon service: $($_.Exception.Message)" -Level "ERROR"
        return @()
    }
}

function Repair-NetlogonIssues {
    param([array]$ServiceIssues)
    
    Write-Log "Repairing Netlogon service issues..."
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
                    Start-Sleep -Seconds 3
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
    
    # Additional Netlogon-specific repairs
    if (-not $LogOnly) {
        try {
            # Reset secure channel
            Write-Log "Resetting machine account secure channel..."
            $resetResult = nltest /sc_reset:$env:USERDNSDOMAIN 2>$null
            if ($LASTEXITCODE -eq 0) {
                $fixesApplied += "Reset machine account secure channel"
                Write-Log "Machine account secure channel reset successfully" -Level "SUCCESS"
            } else {
                Write-Log "Failed to reset secure channel" -Level "WARN"
            }
        }
        catch {
            Write-Log "Error resetting secure channel: $($_.Exception.Message)" -Level "ERROR"
        }
        
        try {
            # Synchronize time with domain
            Write-Log "Synchronizing time with domain..."
            w32tm /resync /force | Out-Null
            if ($LASTEXITCODE -eq 0) {
                $fixesApplied += "Synchronized time with domain"
                Write-Log "Time synchronized successfully" -Level "SUCCESS"
            }
        }
        catch {
            Write-Log "Error synchronizing time: $($_.Exception.Message)" -Level "ERROR"
        }
        
        try {
            # Clear Kerberos tickets
            Write-Log "Clearing Kerberos ticket cache..."
            klist purge | Out-Null
            $fixesApplied += "Cleared Kerberos ticket cache"
            Write-Log "Kerberos tickets cleared" -Level "SUCCESS"
        }
        catch {
            Write-Log "Error clearing Kerberos tickets: $($_.Exception.Message)" -Level "ERROR"
        }
    }
    
    return $fixesApplied
}

function Test-PostRepair {
    Write-Log "Performing post-repair validation..."
    
    try {
        $validationResults = @()
        
        # Test domain authentication
        try {
            $domain = $env:USERDNSDOMAIN
            if ($domain) {
                $authTest = nltest /sc_verify:$domain 2>$null
                if ($LASTEXITCODE -eq 0) {
                    $validationResults += "Domain authentication: PASS"
                    Write-Log "Domain authentication test passed" -Level "SUCCESS"
                } else {
                    $validationResults += "Domain authentication: FAIL"
                    Write-Log "Domain authentication test failed" -Level "WARN"
                }
            }
        }
        catch {
            Write-Log "Error testing domain authentication: $($_.Exception.Message)" -Level "ERROR"
        }
        
        # Verify critical services
        $services = @("Netlogon", "NtLmSsp")
        foreach ($serviceName in $services) {
            $service = Get-Service -Name $serviceName -ErrorAction SilentlyContinue
            if ($service -and $service.Status -eq "Running") {
                $validationResults += "$serviceName service: RUNNING"
                Write-Log "$serviceName service running" -Level "SUCCESS"
            } else {
                $validationResults += "$serviceName service: FAILED"
                Write-Log "$serviceName service not running" -Level "WARN"
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
Netlogon-Service-Stopped REMEDIATION REPORT
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

RECOMMENDATIONS:
====================================================================
1. Monitor domain authentication for next 24 hours
2. Check Windows Event Logs for authentication errors
3. Verify Group Policy updates are received
4. Test network connectivity to domain controllers
5. Schedule regular Netlogon service monitoring

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
    $issues = Test-NetlogonService
    
    if ($issues.Count -eq 0) {
        Write-Log "No Netlogon service issues detected" -Level "SUCCESS"
    } else {
        Write-Log "Found $($issues.Count) Netlogon service issues" -Level "WARN"
        $Script:FixesApplied += Repair-NetlogonIssues -ServiceIssues $issues
    }
    
    Generate-Report -Issues $Script:IssuesFound -Fixes $Script:FixesApplied
    
    Write-Log "=== REMEDIATION SUMMARY ===" -Level "SUCCESS"
    Write-Log "Issues Found: $($Script:IssuesFound.Count)"
    Write-Log "Fixes Applied: $($Script:FixesApplied.Count)"
    Write-Log "Execution Time: $((Get-Date) - $Script:StartTime)"
    Write-Log "Report Location: $Script:LogFile"
    
    if (-not $LogOnly -and $Script:FixesApplied.Count -gt 0) {
        Write-Log "RECOMMENDATION: Test domain authentication and monitor system" -Level "WARN"
        Write-Log "CRITICAL: Verify no business impact from service restarts" -Level "WARN"
    }
    
    exit 0
}
catch {
    Write-Log "FATAL ERROR: $($_.Exception.Message)" -Level "ERROR"
    Write-Log "Stack Trace: $($_.ScriptStackTrace)" -Level "ERROR"
    exit 1
}
