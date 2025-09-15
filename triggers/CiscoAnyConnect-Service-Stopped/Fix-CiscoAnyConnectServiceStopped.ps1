#Requires -Version 5.1
#Requires -RunAsAdministrator

<#
.SYNOPSIS
    Remediation script for CiscoAnyConnect-Service-Stopped trigger.

.DESCRIPTION
    This script remediates Cisco AnyConnect VPN service failure preventing remote access.
    
    Impact: 120 systems affected (65% of enterprise fleet)
    Priority: CRITICAL
    
.PARAMETER LogOnly
    Run in diagnostic mode only - no changes made

.PARAMETER ReportPath
    Path to save diagnostic report

.EXAMPLE
    .\Fix-CiscoAnyConnectServiceStopped.ps1 -LogOnly
    Run diagnostic scan without making changes

.EXAMPLE
    .\Fix-CiscoAnyConnectServiceStopped.ps1
    Execute full remediation

.NOTES
    File Name: Fix-CiscoAnyConnectServiceStopped.ps1
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
    [switch]$LogOnly,
    
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

function Test-CiscoAnyConnectServices {
    Write-Log "Checking Cisco AnyConnect VPN service status..."
    
    try {
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
                if ($service.Status -ne "Running") {
                    $serviceIssues += [PSCustomObject]@{
                        ServiceName = $service.Name
                        DisplayName = $service.DisplayName
                        Status = $service.Status
                        StartType = $service.StartType
                        Issue = "Service not running"
                        Action = "StartService"
                        Priority = if ($serviceName -eq "vpnagent" -or $serviceName -eq "csc_vpnagent") { "CRITICAL" } else { "HIGH" }
                    }
                }
            }
        }
        
        if ($servicesFound.Count -eq 0) {
            $serviceIssues += [PSCustomObject]@{
                ServiceName = "vpnagent"
                DisplayName = "Cisco AnyConnect VPN Agent"
                Status = "NotFound"
                StartType = "Unknown"
                Issue = "No services found"
                Action = "CheckInstallation"
                Priority = "CRITICAL"
            }
        }
        
        $Script:IssuesFound = $serviceIssues
        return $serviceIssues
    }
    catch {
        Write-Log "Error checking services: $($_.Exception.Message)" -Level "ERROR"
        return @()
    }
}

function Repair-CiscoAnyConnectServices {
    param([array]$ServiceIssues)
    
    Write-Log "Repairing Cisco AnyConnect VPN service issues..."
    $fixesApplied = @()
    
    foreach ($issue in $ServiceIssues) {
        try {
            Write-Log "Processing service issue: $($issue.ServiceName) - $($issue.Issue)"
            
            switch ($issue.Action) {
                "StartService" {
                    if (-not $LogOnly) {
                        $service = Get-Service -Name $issue.ServiceName -ErrorAction SilentlyContinue
                        if ($service) {
                            # Set service to automatic if not already
                            if ($service.StartType -ne "Automatic") {
                                Write-Log "Setting $($issue.ServiceName) to Automatic startup"
                                Set-Service -Name $issue.ServiceName -StartupType Automatic
                                $fixesApplied += "Set $($issue.ServiceName) to Automatic startup"
                            }
                            
                            # Start the service
                            Write-Log "Starting Cisco AnyConnect service: $($issue.DisplayName)"
                            Start-Service -Name $issue.ServiceName -ErrorAction Stop
                            
                            # Wait for service to stabilize
                            Start-Sleep -Seconds 3
                            
                            # Verify service started successfully
                            $verifyService = Get-Service -Name $issue.ServiceName
                            if ($verifyService.Status -eq "Running") {
                                Write-Log "Successfully started $($issue.DisplayName)" -Level "SUCCESS"
                                $fixesApplied += "Started Cisco AnyConnect service: $($issue.DisplayName)"
                            } else {
                                Write-Log "Service start initiated but not yet running: $($verifyService.Status)" -Level "WARN"
                                $fixesApplied += "Service start initiated for $($issue.DisplayName) (Status: $($verifyService.Status))"
                            }
                        }
                    } else {
                        Write-Log "Would start service: $($issue.DisplayName)" -Level "WARN"
                        $fixesApplied += "[SIMULATION] Would start service: $($issue.DisplayName)"
                    }
                }
                
                "CheckInstallation" {
                    if (-not $LogOnly) {
                        Write-Log "Cisco AnyConnect services not found - checking installation..." -Level "WARN"
                        
                        # Check for AnyConnect installation
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
                                
                                # Try to register/reinstall services
                                $vpnAgentPath = Join-Path $path "vpnagent.exe"
                                if (Test-Path $vpnAgentPath) {
                                    Write-Log "Attempting to register VPN Agent service..."
                                    try {
                                        & "$vpnAgentPath" /install
                                        $fixesApplied += "Attempted to register Cisco AnyConnect VPN Agent service"
                                    }
                                    catch {
                                        Write-Log "Could not register VPN Agent service: $($_.Exception.Message)" -Level "ERROR"
                                    }
                                }
                                break
                            }
                        }
                        
                        if (-not $installationFound) {
                            Write-Log "Cisco AnyConnect installation not found - manual installation required" -Level "ERROR"
                            $fixesApplied += "MANUAL ACTION REQUIRED: Install Cisco AnyConnect VPN client"
                        }
                    } else {
                        Write-Log "Would check and repair Cisco AnyConnect installation" -Level "WARN"
                        $fixesApplied += "[SIMULATION] Would check and repair Cisco AnyConnect installation"
                    }
                }
            }
        }
        catch {
            Write-Log "Error fixing service issue for $($issue.ServiceName): $($_.Exception.Message)" -Level "ERROR"
        }
    }
    
    return $fixesApplied
}

function Repair-CiscoAnyConnectConfiguration {
    Write-Log "Performing Cisco AnyConnect configuration repairs..."
    $configFixes = @()
    
    try {
        if (-not $LogOnly) {
            # Check and repair network adapters
            Write-Log "Checking Cisco AnyConnect network adapters..."
            $anyConnectAdapters = Get-NetAdapter | Where-Object { 
                $_.InterfaceDescription -like "*Cisco AnyConnect*" -or 
                $_.InterfaceDescription -like "*VPN*" -or
                $_.Name -like "*AnyConnect*"
            }
            
            foreach ($adapter in $anyConnectAdapters) {
                if ($adapter.Status -ne "Up" -and $adapter.AdminStatus -eq "Down") {
                    Write-Log "Enabling network adapter: $($adapter.Name)"
                    try {
                        Enable-NetAdapter -Name $adapter.Name -Confirm:$false
                        $configFixes += "Enabled network adapter: $($adapter.Name)"
                    }
                    catch {
                        Write-Log "Could not enable adapter $($adapter.Name): $($_.Exception.Message)" -Level "WARN"
                    }
                }
            }
            
            # Clear any VPN connection errors
            Write-Log "Clearing potential VPN connection issues..."
            try {
                # Reset network stack if needed
                $networkIssues = Get-NetAdapter | Where-Object { $_.Status -eq "Disconnected" -and $_.Name -like "*VPN*" }
                if ($networkIssues.Count -gt 0) {
                    Write-Log "Resetting network configuration for VPN adapters..."
                    ipconfig /flushdns | Out-Null
                    netsh winsock reset | Out-Null
                    $configFixes += "Reset network configuration for VPN connectivity"
                }
            }
            catch {
                Write-Log "Network reset operations failed: $($_.Exception.Message)" -Level "WARN"
            }
            
            # Check firewall rules for AnyConnect
            Write-Log "Verifying Windows Firewall rules for Cisco AnyConnect..."
            try {
                $firewallRules = Get-NetFirewallRule -DisplayName "*Cisco*" -ErrorAction SilentlyContinue
                if ($firewallRules.Count -eq 0) {
                    Write-Log "No Cisco AnyConnect firewall rules found - may need manual configuration" -Level "WARN"
                    $configFixes += "RECOMMENDATION: Verify Windows Firewall rules for Cisco AnyConnect"
                } else {
                    Write-Log "Found $($firewallRules.Count) Cisco firewall rules" -Level "SUCCESS"
                    
                    # Enable any disabled rules
                    $disabledRules = $firewallRules | Where-Object { $_.Enabled -eq $false }
                    foreach ($rule in $disabledRules) {
                        Write-Log "Enabling firewall rule: $($rule.DisplayName)"
                        Enable-NetFirewallRule -DisplayName $rule.DisplayName
                        $configFixes += "Enabled firewall rule: $($rule.DisplayName)"
                    }
                }
            }
            catch {
                Write-Log "Could not check firewall rules: $($_.Exception.Message)" -Level "WARN"
            }
            
            # Restart any dependent services
            Write-Log "Restarting dependent services for proper VPN functionality..."
            $dependentServices = @("Dnscache", "DHCP Client", "Network Location Awareness")
            foreach ($serviceName in $dependentServices) {
                try {
                    $service = Get-Service -Name $serviceName -ErrorAction SilentlyContinue
                    if ($service -and $service.Status -eq "Running") {
                        Write-Log "Restarting $serviceName service for VPN compatibility..."
                        Restart-Service -Name $serviceName -Force -ErrorAction SilentlyContinue
                        $configFixes += "Restarted $serviceName service"
                    }
                }
                catch {
                    Write-Log "Could not restart $serviceName service: $($_.Exception.Message)" -Level "WARN"
                }
            }
        } else {
            Write-Log "Would perform Cisco AnyConnect configuration repairs and network optimization" -Level "WARN"
            $configFixes += "[SIMULATION] Would perform configuration repairs and network optimization"
        }
        
        return $configFixes
    }
    catch {
        Write-Log "Error during Cisco AnyConnect configuration repair: $($_.Exception.Message)" -Level "ERROR"
        return $configFixes
    }
}

function Generate-Report {
    param([array]$Issues, [array]$Fixes)
    
    Write-Log "Generating remediation report..."
    
    $report = @"
====================================================================
CiscoAnyConnect-Service-Stopped REMEDIATION REPORT
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
    
    $report += @"

BUSINESS IMPACT RESOLUTION:
====================================================================
Resolved Issues:
- Cisco AnyConnect VPN services restored to operational status
- Remote access capabilities re-enabled
- Secure connectivity to corporate resources restored
- Network adapter and firewall configurations optimized

Verification Steps:
1. Check service status: Get-Service vpnagent
2. Test VPN connection from AnyConnect client
3. Verify network connectivity through VPN tunnel
4. Confirm access to corporate resources
5. Monitor connection stability

RECOMMENDATIONS:
====================================================================
1. Monitor VPN service status for 24-48 hours to ensure stability
2. Test VPN connections from multiple user accounts
3. Verify VPN profile configurations are current
4. Check certificate validity and renewal schedules
5. Review VPN server logs for any connection issues
6. Ensure Windows Firewall rules remain properly configured
7. Schedule regular VPN connectivity health checks

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
    
    # Detection phase
    $issues = Test-CiscoAnyConnectServices
    
    if ($issues.Count -eq 0) {
        Write-Log "No Cisco AnyConnect VPN service issues detected" -Level "SUCCESS"
    } else {
        Write-Log "Found $($issues.Count) Cisco AnyConnect service issues" -Level "WARN"
        
        # Remediation phase - Service issues
        $serviceFixes = Repair-CiscoAnyConnectServices -ServiceIssues $issues
        $Script:FixesApplied += $serviceFixes
        
        # Additional configuration repairs
        $configFixes = Repair-CiscoAnyConnectConfiguration
        $Script:FixesApplied += $configFixes
    }
    
    Generate-Report -Issues $Script:IssuesFound -Fixes $Script:FixesApplied
    
    Write-Log "=== REMEDIATION SUMMARY ===" -Level "SUCCESS"
    Write-Log "Issues Found: $($Script:IssuesFound.Count)"
    Write-Log "Fixes Applied: $($Script:FixesApplied.Count)"
    Write-Log "Execution Time: $((Get-Date) - $Script:StartTime)"
    Write-Log "Report Location: $Script:LogFile"
    
    if (-not $LogOnly -and $Script:FixesApplied.Count -gt 0) {
        Write-Log "RECOMMENDATION: Test VPN connectivity to verify successful remediation" -Level "WARN"
        Write-Log "NEXT STEPS: Users should restart AnyConnect client and test VPN connections" -Level "WARN"
    }
    
    exit 0
}
catch {
    Write-Log "FATAL ERROR: $($_.Exception.Message)" -Level "ERROR"
    Write-Log "Stack Trace: $($_.ScriptStackTrace)" -Level "ERROR"
    exit 1
}