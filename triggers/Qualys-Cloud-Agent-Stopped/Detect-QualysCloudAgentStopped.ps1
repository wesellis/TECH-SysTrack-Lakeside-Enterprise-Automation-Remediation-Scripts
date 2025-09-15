#Requires -Version 5.1
#Requires -RunAsAdministrator

<#
.SYNOPSIS
    Detection script for Qualys-Cloud-Agent-Stopped trigger.

.DESCRIPTION
    This script detects Qualys Cloud Agent service failure affecting security scanning.
    
    Impact: 25 systems affected (88% of enterprise fleet)
    Priority: CRITICAL
    
.PARAMETER ReportPath
    Path to save diagnostic report

.EXAMPLE
    .\Detect-QualysCloudAgentStopped.ps1
    Run diagnostic scan

.NOTES
    File Name: Detect-QualysCloudAgentStopped.ps1
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
            if ($service) {
                if ($service.Status -ne "Running") {
                    $serviceIssues += [PSCustomObject]@{
                        ServiceName = $service.Name
                        DisplayName = $service.DisplayName
                        Status = $service.Status
                        StartType = $service.StartType
                        Issue = "Service not running: $($service.Status)"
                        Severity = "CRITICAL"
                        Impact = "Security scanning disabled"
                        ProcessId = $service.Id
                    }
                    Write-Log "CRITICAL: $($service.DisplayName) is $($service.Status)" -Level "ERROR"
                }
                else {
                    Write-Log "OK: $($service.DisplayName) is running (PID: $($service.Id))" -Level "SUCCESS"
                    
                    # Check service health even if running
                    $process = Get-Process -Id $service.Id -ErrorAction SilentlyContinue
                    if ($process) {
                        $memoryMB = [math]::Round($process.WorkingSet / 1MB, 2)
                        if ($memoryMB -gt 500) {
                            $serviceIssues += [PSCustomObject]@{
                                ServiceName = $service.Name
                                DisplayName = $service.DisplayName
                                Status = "Running"
                                StartType = $service.StartType
                                Issue = "High memory usage: $memoryMB MB"
                                Severity = "HIGH"
                                Impact = "Performance degradation"
                                ProcessId = $service.Id
                            }
                            Write-Log "HIGH: $($service.DisplayName) using $memoryMB MB memory" -Level "WARN"
                        }
                    }
                }
            } else {
                Write-Log "Service not found: $serviceName" -Level "WARN"
            }
        }
        
        # If no Qualys services found, this is critical
        if ($qualysServices | ForEach-Object { Get-Service -Name $_ -ErrorAction SilentlyContinue } | Where-Object { $_ }) {
            # At least one service exists
        } else {
            $serviceIssues += [PSCustomObject]@{
                ServiceName = "QualysAgent"
                DisplayName = "Qualys Cloud Agent"
                Status = "NotInstalled"
                StartType = "Unknown"
                Issue = "Qualys Cloud Agent not installed"
                Severity = "CRITICAL"
                Impact = "No security scanning capability"
                ProcessId = 0
            }
            Write-Log "CRITICAL: Qualys Cloud Agent not installed" -Level "ERROR"
        }
        
        $Script:IssuesFound = $serviceIssues
        return $serviceIssues.Count -gt 0
    }
    catch {
        Write-Log "Error checking Qualys services: $($_.Exception.Message)" -Level "ERROR"
        return $false
    }
}

function Test-QualysConnectivity {
    Write-Log "Testing Qualys Cloud connectivity..."
    
    try {
        $connectivityIssues = @()
        
        # Test Qualys cloud endpoints
        $qualysEndpoints = @(
            "qualysguard.qualys.com",
            "qualysapi.qualys.com", 
            "qualysguard.qg2.apps.qualys.com"
        )
        
        foreach ($endpoint in $qualysEndpoints) {
            try {
                $pingResult = Test-Connection -ComputerName $endpoint -Count 2 -ErrorAction SilentlyContinue
                if ($pingResult) {
                    $avgLatency = ($pingResult.ResponseTime | Measure-Object -Average).Average
                    Write-Log "Qualys endpoint reachable: $endpoint ($avgLatency ms)" -Level "SUCCESS"
                } else {
                    $connectivityIssues += [PSCustomObject]@{
                        Component = "Qualys Endpoint"
                        Target = $endpoint
                        Issue = "Cannot reach Qualys cloud endpoint"
                        Severity = "HIGH"
                        Impact = "Agent cannot communicate with Qualys cloud"
                    }
                    Write-Log "Cannot reach Qualys endpoint: $endpoint" -Level "WARN"
                }
            }
            catch {
                Write-Log "Error testing endpoint $endpoint : $($_.Exception.Message)" -Level "ERROR"
            }
        }
        
        # Test HTTPS connectivity to Qualys
        foreach ($endpoint in $qualysEndpoints) {
            try {
                $httpsTest = Invoke-WebRequest -Uri "https://$endpoint" -TimeoutSec 10 -UseBasicParsing -ErrorAction SilentlyContinue
                if ($httpsTest.StatusCode -eq 200 -or $httpsTest.StatusCode -eq 403) {
                    Write-Log "HTTPS connectivity OK: $endpoint" -Level "SUCCESS"
                } else {
                    $connectivityIssues += [PSCustomObject]@{
                        Component = "HTTPS Connection"
                        Target = $endpoint
                        Issue = "HTTPS connection failed: $($httpsTest.StatusCode)"
                        Severity = "HIGH"
                        Impact = "Agent cannot authenticate with Qualys"
                    }
                }
            }
            catch {
                Write-Log "HTTPS test failed for $endpoint" -Level "WARN"
            }
        }
        
        $Script:IssuesFound += $connectivityIssues
        return $connectivityIssues.Count -gt 0
    }
    catch {
        Write-Log "Error testing Qualys connectivity: $($_.Exception.Message)" -Level "ERROR"
        return $false
    }
}

function Test-QualysConfiguration {
    Write-Log "Checking Qualys configuration..."
    
    try {
        $configIssues = @()
        
        # Check Qualys registry entries
        $qualysRegPaths = @(
            "HKLM:\SOFTWARE\Qualys\QualysAgent",
            "HKLM:\SYSTEM\CurrentControlSet\Services\QualysAgent"
        )
        
        foreach ($regPath in $qualysRegPaths) {
            if (Test-Path $regPath) {
                Write-Log "Qualys registry path exists: $regPath" -Level "SUCCESS"
                
                # Check for activation key
                try {
                    $activationKey = Get-ItemProperty -Path $regPath -Name "ActivationId" -ErrorAction SilentlyContinue
                    if (-not $activationKey) {
                        $configIssues += [PSCustomObject]@{
                            Component = "Configuration"
                            Setting = "ActivationId"
                            Issue = "Qualys activation key missing"
                            Severity = "HIGH"
                            Impact = "Agent cannot activate with Qualys cloud"
                        }
                        Write-Log "Qualys activation key missing" -Level "WARN"
                    } else {
                        Write-Log "Qualys activation key configured" -Level "SUCCESS"
                    }
                }
                catch {
                    Write-Log "Error checking activation key: $($_.Exception.Message)" -Level "ERROR"
                }
            } else {
                $configIssues += [PSCustomObject]@{
                    Component = "Configuration"
                    Setting = "Registry"
                    Issue = "Qualys registry configuration missing: $regPath"
                    Severity = "HIGH"
                    Impact = "Agent configuration incomplete"
                }
                Write-Log "Qualys registry path missing: $regPath" -Level "WARN"
            }
        }
        
        # Check Qualys log files
        $logPaths = @(
            "$env:ProgramFiles\Qualys\QualysAgent\log",
            "$env:ProgramData\Qualys\QualysAgent\log"
        )
        
        foreach ($logPath in $logPaths) {
            if (Test-Path $logPath) {
                Write-Log "Qualys log directory exists: $logPath" -Level "SUCCESS"
                
                # Check for recent log entries
                $logFiles = Get-ChildItem -Path $logPath -Filter "*.log" -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending
                if ($logFiles) {
                    $recentLog = $logFiles[0]
                    $daysSinceUpdate = (Get-Date) - $recentLog.LastWriteTime
                    if ($daysSinceUpdate.Days -gt 7) {
                        $configIssues += [PSCustomObject]@{
                            Component = "Logs"
                            Setting = "LastUpdate"
                            Issue = "Qualys logs not updated for $($daysSinceUpdate.Days) days"
                            Severity = "MEDIUM"
                            Impact = "Agent may not be functioning properly"
                        }
                        Write-Log "Qualys logs outdated: $($daysSinceUpdate.Days) days" -Level "WARN"
                    }
                }
            }
        }
        
        $Script:IssuesFound += $configIssues
        return $configIssues.Count -gt 0
    }
    catch {
        Write-Log "Error checking Qualys configuration: $($_.Exception.Message)" -Level "ERROR"
        return $false
    }
}

function Generate-Report {
    param([array]$Issues)
    
    Write-Log "Generating diagnostic report..."
    
    $report = @"
====================================================================
Qualys-Cloud-Agent-Stopped DETECTION REPORT
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

QUALYS SERVICE STATUS:
====================================================================
"@
    
    $services = @("QualysAgent", "Qualys Cloud Agent", "QualysCloudAgent")
    foreach ($serviceName in $services) {
        $service = Get-Service -Name $serviceName -ErrorAction SilentlyContinue
        if ($service) {
            $report += "- $($service.DisplayName): $($service.Status) ($($service.StartType))`n"
        } else {
            $report += "- $serviceName: NOT FOUND`n"
        }
    }
    
    $report += @"

SECURITY SCANNING IMPACT:
====================================================================
- Vulnerability Scanning: $(if ($Issues | Where-Object {$_.Severity -eq "CRITICAL"}) { "DISABLED" } else { "ACTIVE" })
- Compliance Monitoring: $(if ($Issues | Where-Object {$_.Impact -like "*scanning*"}) { "IMPACTED" } else { "NORMAL" })
- Policy Compliance: $(if ($Issues | Where-Object {$_.Component -eq "Configuration"}) { "AT RISK" } else { "COMPLIANT" })

RECOMMENDATIONS:
====================================================================
1. Run corresponding remediation script if issues found
2. Verify Qualys cloud connectivity
3. Check firewall rules for Qualys endpoints
4. Review Qualys activation and configuration
5. Monitor vulnerability scan schedules

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
    
    $serviceIssues = Test-QualysServices
    $connectivityIssues = Test-QualysConnectivity
    $configIssues = Test-QualysConfiguration
    
    $totalIssues = $Script:IssuesFound.Count
    
    if ($totalIssues -gt 0) {
        Write-Log "Issues detected for $Script:TriggerName" -Level "WARN"
        Write-Log "Found $totalIssues issues requiring attention"
        
        $criticalIssues = ($Script:IssuesFound | Where-Object { $_.Severity -eq "CRITICAL" }).Count
        if ($criticalIssues -gt 0) {
            Write-Log "CRITICAL: $criticalIssues issues require immediate attention!" -Level "ERROR"
            Write-Log "SECURITY RISK: Vulnerability scanning may be disabled" -Level "ERROR"
        }
    } else {
        Write-Log "No issues detected for $Script:TriggerName" -Level "SUCCESS"
        Write-Log "Qualys Cloud Agent functioning normally" -Level "SUCCESS"
    }
    
    Generate-Report -Issues $Script:IssuesFound
    
    Write-Log "=== DETECTION SUMMARY ===" -Level "SUCCESS"
    Write-Log "Issues Found: $totalIssues"
    Write-Log "Critical Issues: $(($Script:IssuesFound | Where-Object { $_.Severity -eq 'CRITICAL' }).Count)"
    Write-Log "High Issues: $(($Script:IssuesFound | Where-Object { $_.Severity -eq 'HIGH' }).Count)"
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
