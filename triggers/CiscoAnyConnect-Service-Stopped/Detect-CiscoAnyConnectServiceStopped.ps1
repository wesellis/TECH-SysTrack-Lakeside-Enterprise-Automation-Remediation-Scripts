#Requires -Version 5.1
#Requires -RunAsAdministrator

<#
.SYNOPSIS
    Detection script for CiscoAnyConnect-Service-Stopped trigger.

.DESCRIPTION
    This script detects Cisco AnyConnect VPN service failure preventing remote access.
    
    Impact: 120 systems affected (65% of enterprise fleet)
    Priority: CRITICAL
    
.PARAMETER ReportPath
    Path to save diagnostic report

.EXAMPLE
    .\Detect-CiscoAnyConnectServiceStopped.ps1
    Run diagnostic scan

.NOTES
    File Name: Detect-CiscoAnyConnectServiceStopped.ps1
    Version: 1.0
    Date: 2025-07-01
    Author: Wesley Ellis (Wesley.Ellis@compucom.com)
    Company: CompuCom - SysTrack Automation Team
    Requires: Administrator privileges
    Tested: Windows 10/11, Server 2016/2019/2022
    
    Trigger: CiscoAnyConnect-Service-Stopped
    Systems Affected: 120 (65% impact)
    Priority: CRITICAL
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$ReportPath = "$env:TEMP\CiscoAnyConnect-Service-Stopped-Report-$(Get-Date -Format 'yyyyMMdd-HHmmss').log"
)

# Script metadata
$Script:ScriptVersion = "1.0"
$Script:ScriptDate = "2025-07-01"
$Script:ScriptAuthor = "Wesley Ellis (Wesley.Ellis@compucom.com)"
$Script:TriggerName = "CiscoAnyConnect-Service-Stopped"
$Script:SystemsAffected = 120
$Script:ImpactPercentage = 65
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

function Test-CiscoAnyConnectServices {
    Write-Log "Checking Cisco AnyConnect VPN service status..."
    
    try {
        # Cisco AnyConnect service names (various versions)
        $ciscoServices = @(
            "vpnagent",                    # Main AnyConnect service
            "csc_vpnagent",               # Cisco Secure Client VPN Agent
            "vpnui",                      # AnyConnect VPN UI
            "CSCAgentSvc",                # Cisco Secure Client Agent
            "acsock",                     # AnyConnect Socket Filter
            "acmon",                      # AnyConnect Monitor
            "acwebsecagent"               # AnyConnect Web Security Agent
        )
        
        $serviceIssues = @()
        $servicesFound = @()
        
        foreach ($serviceName in $ciscoServices) {
            $service = Get-Service -Name $serviceName -ErrorAction SilentlyContinue
            if ($service) {
                $servicesFound += $service
                Write-Log "Found Cisco AnyConnect service: $($service.DisplayName) ($($service.Name))"
                
                if ($service.Status -ne "Running") {
                    $serviceIssues += [PSCustomObject]@{
                        ServiceName = $service.Name
                        DisplayName = $service.DisplayName
                        Status = $service.Status
                        StartType = $service.StartType
                        Issue = "Cisco AnyConnect service not running: $($service.Status)"
                        BusinessImpact = "VPN connectivity unavailable"
                        Severity = "CRITICAL"
                        ServiceType = "Primary"
                    }
                    Write-Log "CRITICAL: Cisco AnyConnect service $($service.DisplayName) is $($service.Status)" -Level "ERROR"
                } else {
                    Write-Log "Cisco AnyConnect service $($service.DisplayName) is running normally" -Level "SUCCESS"
                    
                    # Check service health for running services
                    try {
                        $serviceProcess = Get-Process -Name $service.Name -ErrorAction SilentlyContinue
                        if (-not $serviceProcess) {
                            $serviceIssues += [PSCustomObject]@{
                                ServiceName = $service.Name
                                DisplayName = $service.DisplayName
                                Status = "Running-NoProcess"
                                StartType = $service.StartType
                                Issue = "Service shows running but no process found"
                                BusinessImpact = "Potential VPN instability"
                                Severity = "HIGH"
                                ServiceType = "HealthCheck"
                            }
                            Write-Log "WARNING: Service $($service.DisplayName) running but no associated process found" -Level "WARN"
                        }
                    }
                    catch {
                        Write-Log "Could not verify service process for $($service.DisplayName): $($_.Exception.Message)" -Level "WARN"
                    }
                }
            }
        }
        
        # Check if any Cisco AnyConnect services were found
        if ($servicesFound.Count -eq 0) {
            $serviceIssues += [PSCustomObject]@{
                ServiceName = "vpnagent"
                DisplayName = "Cisco AnyConnect VPN Agent"
                Status = "NotFound"
                StartType = "Unknown"
                Issue = "No Cisco AnyConnect services found on system"
                BusinessImpact = "VPN capability not available"
                Severity = "CRITICAL"
                ServiceType = "Installation"
            }
            Write-Log "CRITICAL: No Cisco AnyConnect services found on system" -Level "ERROR"
        } else {
            Write-Log "Found $($servicesFound.Count) Cisco AnyConnect services on system" -Level "SUCCESS"
        }
        
        $Script:IssuesFound = $serviceIssues
        return $serviceIssues.Count -gt 0
    }
    catch {
        Write-Log "Error checking Cisco AnyConnect services: $($_.Exception.Message)" -Level "ERROR"
        return $false
    }
}

function Test-CiscoAnyConnectInstallation {
    Write-Log "Performing Cisco AnyConnect installation and configuration checks..."
    
    try {
        $installationIssues = @()
        
        # Check for AnyConnect installation paths
        $anyConnectPaths = @(
            "${env:ProgramFiles}\Cisco\Cisco AnyConnect Secure Mobility Client",
            "${env:ProgramFiles(x86)}\Cisco\Cisco AnyConnect Secure Mobility Client",
            "${env:ProgramFiles}\Cisco\Cisco Secure Client",
            "${env:ProgramFiles(x86)}\Cisco\Cisco Secure Client"
        )
        
        $installationFound = $false
        foreach ($path in $anyConnectPaths) {
            if (Test-Path $path) {
                Write-Log "Cisco AnyConnect installation found: $path" -Level "SUCCESS"
                $installationFound = $true
                
                # Check for key executables
                $vpnUIPath = Join-Path $path "vpnui.exe"
                $vpnAgentPath = Join-Path $path "vpnagent.exe"
                
                if (-not (Test-Path $vpnUIPath)) {
                    $installationIssues += [PSCustomObject]@{
                        Component = "Installation"
                        Issue = "Cisco AnyConnect UI executable missing"
                        Path = $vpnUIPath
                        BusinessImpact = "User interface not available"
                        Severity = "HIGH"
                    }
                    Write-Log "WARNING: AnyConnect UI executable missing: $vpnUIPath" -Level "WARN"
                }
                
                if (-not (Test-Path $vpnAgentPath)) {
                    $installationIssues += [PSCustomObject]@{
                        Component = "Installation"
                        Issue = "Cisco AnyConnect VPN Agent executable missing"
                        Path = $vpnAgentPath
                        BusinessImpact = "VPN connectivity not possible"
                        Severity = "CRITICAL"
                    }
                    Write-Log "CRITICAL: AnyConnect VPN Agent executable missing: $vpnAgentPath" -Level "ERROR"
                }
                
                break  # Found installation, no need to check other paths
            }
        }
        
        if (-not $installationFound) {
            $installationIssues += [PSCustomObject]@{
                Component = "Installation"
                Issue = "Cisco AnyConnect installation not found"
                Path = "Multiple paths checked"
                BusinessImpact = "VPN capability not available"
                Severity = "CRITICAL"
            }
            Write-Log "CRITICAL: Cisco AnyConnect installation not found in standard locations" -Level "ERROR"
        }
        
        # Check for AnyConnect configuration files
        $profilePath = "$env:ProgramData\Cisco\Cisco AnyConnect Secure Mobility Client\Profile"
        if (Test-Path $profilePath) {
            $profiles = Get-ChildItem -Path $profilePath -Filter "*.xml" -ErrorAction SilentlyContinue
            if ($profiles.Count -eq 0) {
                $installationIssues += [PSCustomObject]@{
                    Component = "Configuration"
                    Issue = "No AnyConnect VPN profiles found"
                    Path = $profilePath
                    BusinessImpact = "VPN connections not configured"
                    Severity = "HIGH"
                }
                Write-Log "WARNING: No AnyConnect VPN profiles found" -Level "WARN"
            } else {
                Write-Log "Found $($profiles.Count) AnyConnect VPN profiles" -Level "SUCCESS"
            }
        } else {
            Write-Log "AnyConnect profile directory not found: $profilePath" -Level "WARN"
        }
        
        # Check network adapters for AnyConnect
        $anyConnectAdapters = Get-NetAdapter | Where-Object { $_.InterfaceDescription -like "*Cisco AnyConnect*" -or $_.InterfaceDescription -like "*VPN*" }
        if ($anyConnectAdapters.Count -eq 0) {
            $installationIssues += [PSCustomObject]@{
                Component = "NetworkAdapter"
                Issue = "No AnyConnect network adapters found"
                Path = "Network Adapters"
                BusinessImpact = "VPN connections cannot be established"
                Severity = "HIGH"
            }
            Write-Log "WARNING: No AnyConnect network adapters found" -Level "WARN"
        } else {
            Write-Log "Found $($anyConnectAdapters.Count) AnyConnect network adapters" -Level "SUCCESS"
        }
        
        # Add installation issues to main issues list
        $Script:IssuesFound += $installationIssues
        
        return $installationIssues.Count -gt 0
    }
    catch {
        Write-Log "Error checking Cisco AnyConnect installation: $($_.Exception.Message)" -Level "ERROR"
        return $false
    }
}

function Test-VPNConnectivity {
    Write-Log "Testing VPN connectivity capabilities..."
    
    try {
        $connectivityIssues = @()
        
        # Check if any VPN connections are currently active
        $vpnConnections = Get-VpnConnection -ErrorAction SilentlyContinue
        if ($vpnConnections) {
            $activeConnections = $vpnConnections | Where-Object { $_.ConnectionStatus -eq "Connected" }
            if ($activeConnections.Count -gt 0) {
                Write-Log "Found $($activeConnections.Count) active VPN connections" -Level "SUCCESS"
            } else {
                Write-Log "VPN connections configured but none currently active" -Level "INFO"
            }
        }
        
        # Check for common VPN connectivity issues
        # Test basic network connectivity
        try {
            $networkTest = Test-NetConnection -ComputerName "8.8.8.8" -Port 443 -InformationLevel Quiet -ErrorAction SilentlyContinue
            if (-not $networkTest) {
                $connectivityIssues += [PSCustomObject]@{
                    Component = "NetworkConnectivity"
                    Issue = "Basic internet connectivity test failed"
                    Path = "Network"
                    BusinessImpact = "Cannot establish VPN connections"
                    Severity = "HIGH"
                }
                Write-Log "WARNING: Basic internet connectivity test failed" -Level "WARN"
            } else {
                Write-Log "Basic internet connectivity verified" -Level "SUCCESS"
            }
        }
        catch {
            Write-Log "Could not test network connectivity: $($_.Exception.Message)" -Level "WARN"
        }
        
        # Add connectivity issues to main issues list
        $Script:IssuesFound += $connectivityIssues
        
        return $connectivityIssues.Count -gt 0
    }
    catch {
        Write-Log "Error testing VPN connectivity: $($_.Exception.Message)" -Level "ERROR"
        return $false
    }
}

function Generate-Report {
    param([array]$Issues)
    
    Write-Log "Generating diagnostic report..."
    
    $report = @"
====================================================================
CiscoAnyConnect-Service-Stopped DETECTION REPORT
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
Cisco AnyConnect VPN Functions:
- Secure remote access to corporate network
- Encrypted data transmission
- Authentication and authorization
- Network access control
- Split tunneling capabilities

Impact of Service Failure:
- Remote workers cannot access corporate resources
- Secure communications compromised
- Productivity loss for remote/mobile users
- Potential security exposure
- Business continuity disruption

RECOMMENDATIONS:
====================================================================
1. Run corresponding remediation script immediately if issues found
2. Verify AnyConnect license and server connectivity
3. Check firewall rules for VPN traffic
4. Test VPN profiles and certificates
5. Monitor user connection success rates

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
    $serviceIssues = Test-CiscoAnyConnectServices
    
    # Secondary detection: Installation and configuration
    $installationIssues = Test-CiscoAnyConnectInstallation
    
    # Tertiary detection: Connectivity testing
    $connectivityIssues = Test-VPNConnectivity
    
    $totalIssues = $serviceIssues -or $installationIssues -or $connectivityIssues
    
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
        Write-Log "Cisco AnyConnect VPN services are functioning normally" -Level "SUCCESS"
    }
    
    Generate-Report -Issues $Script:IssuesFound
    
    Write-Log "=== DETECTION SUMMARY ===" -Level "SUCCESS"
    Write-Log "Issues Found: $($Script:IssuesFound.Count)"
    Write-Log "Detection Time: $((Get-Date) - $Script:StartTime)"
    Write-Log "Report Location: $Script:LogFile"
    
    if ($totalIssues) {
        Write-Log "RECOMMENDATION: Run Fix-CiscoAnyConnectServiceStopped.ps1 to remediate issues" -Level "WARN"
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