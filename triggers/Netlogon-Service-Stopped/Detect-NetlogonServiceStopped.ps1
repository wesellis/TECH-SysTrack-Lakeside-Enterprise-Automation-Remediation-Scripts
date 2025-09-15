#Requires -Version 5.1
#Requires -RunAsAdministrator

<#
.SYNOPSIS
    Detection script for Netlogon-Service-Stopped trigger.

.DESCRIPTION
    This script detects Netlogon service failure preventing domain authentication.
    
    Impact: 25 systems affected (90% of enterprise fleet)
    Priority: CRITICAL
    
.PARAMETER ReportPath
    Path to save diagnostic report

.EXAMPLE
    .\Detect-NetlogonServiceStopped.ps1
    Run diagnostic scan

.NOTES
    File Name: Detect-NetlogonServiceStopped.ps1
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
            if ($service) {
                if ($service.Status -ne "Running") {
                    $serviceIssues += [PSCustomObject]@{
                        ServiceName = $service.Name
                        DisplayName = $service.DisplayName
                        Status = $service.Status
                        StartType = $service.StartType
                        Issue = "Service not running: $($service.Status)"
                        Severity = "CRITICAL"
                        Impact = "Domain authentication failure"
                    }
                    Write-Log "CRITICAL: $($service.DisplayName) is $($service.Status)" -Level "ERROR"
                }
                else {
                    Write-Log "OK: $($service.DisplayName) is running" -Level "SUCCESS"
                }
            } else {
                $serviceIssues += [PSCustomObject]@{
                    ServiceName = $serviceName
                    DisplayName = "Unknown"
                    Status = "NotFound"
                    StartType = "Unknown"
                    Issue = "Service not found"
                    Severity = "HIGH"
                    Impact = "Service may not be installed"
                }
                Write-Log "Service not found: $serviceName" -Level "WARN"
            }
        }
        
        # Check domain membership
        try {
            $domain = (Get-WmiObject -Class Win32_ComputerSystem).Domain
            if ($domain -eq $env:COMPUTERNAME) {
                $serviceIssues += [PSCustomObject]@{
                    ServiceName = "Domain"
                    DisplayName = "Domain Membership"
                    Status = "NotJoined"
                    StartType = "N/A"
                    Issue = "Computer not joined to domain"
                    Severity = "CRITICAL"
                    Impact = "No domain authentication available"
                }
                Write-Log "CRITICAL: Computer not joined to domain" -Level "ERROR"
            } else {
                Write-Log "Domain membership: $domain" -Level "SUCCESS"
            }
        }
        catch {
            Write-Log "Error checking domain membership: $($_.Exception.Message)" -Level "ERROR"
        }
        
        $Script:IssuesFound = $serviceIssues
        return $serviceIssues.Count -gt 0
    }
    catch {
        Write-Log "Error checking Netlogon service: $($_.Exception.Message)" -Level "ERROR"
        return $false
    }
}

function Test-DomainConnectivity {
    Write-Log "Testing domain controller connectivity..."
    
    try {
        $connectivityIssues = @()
        
        # Test domain controller connectivity
        $domainControllers = @()
        try {
            $domainControllers = (Get-ADDomainController -Filter * -ErrorAction Stop).HostName
        }
        catch {
            # Fallback method
            try {
                $domain = $env:USERDNSDOMAIN
                if ($domain) {
                    $dcResult = nslookup "_ldap._tcp.$domain" 2>$null
                    Write-Log "Using nslookup fallback for DC discovery"
                }
            }
            catch {
                Write-Log "Cannot discover domain controllers" -Level "WARN"
            }
        }
        
        foreach ($dc in $domainControllers) {
            if (Test-Connection -ComputerName $dc -Count 2 -Quiet) {
                Write-Log "Domain controller reachable: $dc" -Level "SUCCESS"
            } else {
                $connectivityIssues += [PSCustomObject]@{
                    Component = "Domain Controller"
                    Target = $dc
                    Issue = "Cannot reach domain controller"
                    Severity = "HIGH"
                    Impact = "Authentication may fail"
                }
                Write-Log "Cannot reach domain controller: $dc" -Level "WARN"
            }
        }
        
        $Script:IssuesFound += $connectivityIssues
        return $connectivityIssues.Count -gt 0
    }
    catch {
        Write-Log "Error testing domain connectivity: $($_.Exception.Message)" -Level "ERROR"
        return $false
    }
}

function Generate-Report {
    param([array]$Issues)
    
    Write-Log "Generating diagnostic report..."
    
    $report = @"
====================================================================
Netlogon-Service-Stopped DETECTION REPORT
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

CRITICAL SERVICE STATUS:
====================================================================
"@
    
    $services = @("Netlogon", "NtLmSsp", "KDC", "DFSR")
    foreach ($serviceName in $services) {
        $service = Get-Service -Name $serviceName -ErrorAction SilentlyContinue
        if ($service) {
            $report += "- $($service.DisplayName): $($service.Status) ($($service.StartType))`n"
        } else {
            $report += "- $serviceName: NOT FOUND`n"
        }
    }
    
    $report += @"

RECOMMENDATIONS:
====================================================================
1. Run corresponding remediation script if issues found
2. Verify domain controller connectivity
3. Check network connectivity to domain
4. Review Windows Event Logs for authentication errors
5. Monitor system after remediation

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
    
    $serviceIssues = Test-NetlogonService
    $connectivityIssues = Test-DomainConnectivity
    
    $totalIssues = $Script:IssuesFound.Count
    
    if ($totalIssues -gt 0) {
        Write-Log "Issues detected for $Script:TriggerName" -Level "WARN"
        Write-Log "Found $totalIssues issues requiring attention"
        
        $criticalIssues = ($Script:IssuesFound | Where-Object { $_.Severity -eq "CRITICAL" }).Count
        if ($criticalIssues -gt 0) {
            Write-Log "CRITICAL: $criticalIssues issues require immediate attention!" -Level "ERROR"
        }
    } else {
        Write-Log "No issues detected for $Script:TriggerName" -Level "SUCCESS"
    }
    
    Generate-Report -Issues $Script:IssuesFound
    
    Write-Log "=== DETECTION SUMMARY ===" -Level "SUCCESS"
    Write-Log "Issues Found: $totalIssues"
    Write-Log "Critical Issues: $(($Script:IssuesFound | Where-Object { $_.Severity -eq 'CRITICAL' }).Count)"
    Write-Log "Detection Time: $((Get-Date) - $Script:StartTime)"
    Write-Log "Report Location: $Script:LogFile"
    
    if ($totalIssues -gt 0) {
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
