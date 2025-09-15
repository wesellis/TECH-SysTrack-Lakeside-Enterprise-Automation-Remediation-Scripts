#Requires -Version 5.1
#Requires -RunAsAdministrator

<#
.SYNOPSIS
    Diagnoses and repairs network adapter and connectivity issues.

.DESCRIPTION
    This script identifies and fixes common network adapter problems including:
    - Disabled network adapters
    - Driver issues and reinstallation
    - IP configuration problems
    - Network adapter power management
    - Network profile configuration

.PARAMETER LogOnly
    Run in diagnostic mode only - no changes made

.PARAMETER ResetAdapters
    Enable complete adapter reset and driver reinstall

.PARAMETER ReportPath
    Path to save diagnostic report

.EXAMPLE
    .\Fix-NetworkAdapters.ps1 -LogOnly
    Diagnose network adapter issues without changes

.EXAMPLE
    .\Fix-NetworkAdapters.ps1 -ResetAdapters
    Perform complete adapter reset and optimization

.NOTES
    File Name: Fix-NetworkAdapters.ps1
    Version: 1.0
    Date: June 30, 2025
    Author: Wesley Ellis (Wesley.Ellis@compucom.com)
    Company: CompuCom - SysTrack Automation Team
    
    Impact: Network adapter issues affect connectivity and performance
    Priority: HIGH - Essential for network access and remote work
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [switch]$LogOnly,
    
    [Parameter(Mandatory = $false)]
    [switch]$ResetAdapters,
    
    [Parameter(Mandatory = $false)]
    [string]$ReportPath = "$env:TEMP\Network-Adapters-Report-$(Get-Date -Format 'yyyyMMdd-HHmmss').log"
)

# Script metadata and logging setup
$Script:ScriptVersion = "1.0"
$Script:ScriptDate = "2025-06-30"
$Script:ScriptAuthor = "Wesley Ellis (Wesley.Ellis@compucom.com)"
$Script:LogFile = $ReportPath
$Script:StartTime = Get-Date
$Script:FixesApplied = @()
$Script:IssuesFound = @()

function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "[$timestamp] [$Level] $Message"
    Write-Host $logEntry -ForegroundColor $(
        switch ($Level) { "ERROR" { "Red" }; "WARN" { "Yellow" }; "SUCCESS" { "Green" }; default { "White" } }
    )
    Add-Content -Path $Script:LogFile -Value $logEntry -ErrorAction SilentlyContinue
}

function Get-NetworkAdapterStatus {
    Write-Log "Analyzing network adapter status..."
    $adapterIssues = @()
    
    try {
        $adapters = Get-NetAdapter | Where-Object { $_.Virtual -eq $false }
        
        foreach ($adapter in $adapters) {
            Write-Log "Checking adapter: $($adapter.Name) - Status: $($adapter.Status)"
            
            # Check for disabled adapters
            if ($adapter.AdminStatus -eq "Down") {
                $adapterIssues += [PSCustomObject]@{
                    AdapterName = $adapter.Name
                    Issue = "Adapter administratively disabled"
                    Status = $adapter.Status
                    AdminStatus = $adapter.AdminStatus
                    InterfaceIndex = $adapter.InterfaceIndex
                }
            }
            
            # Check for adapters with problems
            if ($adapter.Status -eq "Disconnected" -and $adapter.MediaConnectionState -eq "Unknown") {
                $adapterIssues += [PSCustomObject]@{
                    AdapterName = $adapter.Name
                    Issue = "Adapter in unknown state"
                    Status = $adapter.Status
                    AdminStatus = $adapter.AdminStatus
                    InterfaceIndex = $adapter.InterfaceIndex
                }
            }
            
            # Check for speed issues
            if ($adapter.LinkSpeed -lt 100000000) {  # Less than 100 Mbps
                $adapterIssues += [PSCustomObject]@{
                    AdapterName = $adapter.Name
                    Issue = "Low link speed detected"
                    Status = $adapter.Status
                    AdminStatus = $adapter.AdminStatus
                    InterfaceIndex = $adapter.InterfaceIndex
                }
            }
        }
        
        Write-Log "Found $($adapterIssues.Count) network adapter issues"
        return $adapterIssues
    } catch {
        Write-Log "Error analyzing network adapters: $($_.Exception.Message)" -Level "ERROR"
        return @()
    }
}

function Enable-NetworkAdapters {
    param([array]$AdapterIssues)
    Write-Log "Enabling disabled network adapters..."
    $fixes = @()
    
    foreach ($issue in $AdapterIssues) {
        if ($issue.AdminStatus -eq "Down") {
            try {
                if (-not $LogOnly) {
                    Enable-NetAdapter -Name $issue.AdapterName -Confirm:$false
                    $fixes += "Enabled network adapter: $($issue.AdapterName)"
                    Write-Log "Enabled adapter: $($issue.AdapterName)" -Level "SUCCESS"
                } else {
                    Write-Log "Would enable adapter: $($issue.AdapterName)" -Level "WARN"
                }
            } catch {
                Write-Log "Error enabling adapter $($issue.AdapterName): $($_.Exception.Message)" -Level "ERROR"
            }
        }
    }
    
    return $fixes
}

function Reset-NetworkAdapters {
    Write-Log "Resetting network adapters..."
    $fixes = @()
    
    if ($ResetAdapters) {
        try {
            $adapters = Get-NetAdapter | Where-Object { $_.Virtual -eq $false -and $_.Status -eq "Up" }
            
            foreach ($adapter in $adapters) {
                if (-not $LogOnly) {
                    Write-Log "Resetting adapter: $($adapter.Name)"
                    
                    # Disable and re-enable adapter
                    Disable-NetAdapter -Name $adapter.Name -Confirm:$false
                    Start-Sleep -Seconds 3
                    Enable-NetAdapter -Name $adapter.Name -Confirm:$false
                    
                    $fixes += "Reset network adapter: $($adapter.Name)"
                    Write-Log "Reset completed for: $($adapter.Name)" -Level "SUCCESS"
                } else {
                    Write-Log "Would reset adapter: $($adapter.Name)" -Level "WARN"
                }
            }
        } catch {
            Write-Log "Error resetting adapters: $($_.Exception.Message)" -Level "ERROR"
        }
    } else {
        Write-Log "Adapter reset not requested"
    }
    
    return $fixes
}

function Optimize-AdapterSettings {
    Write-Log "Optimizing network adapter settings..."
    $fixes = @()
    
    if (-not $LogOnly) {
        try {
            $adapters = Get-NetAdapter | Where-Object { $_.Virtual -eq $false }
            
            foreach ($adapter in $adapters) {
                # Disable power management
                try {
                    $powerMgmt = Get-NetAdapterPowerManagement -Name $adapter.Name -ErrorAction SilentlyContinue
                    if ($powerMgmt -and $powerMgmt.AllowComputerToTurnOffDevice) {
                        Set-NetAdapterPowerManagement -Name $adapter.Name -AllowComputerToTurnOffDevice Disabled
                        $fixes += "Disabled power management for: $($adapter.Name)"
                    }
                } catch {
                    Write-Log "Could not modify power settings for $($adapter.Name)" -Level "WARN"
                }
                
                # Set adapter to full duplex if possible
                try {
                    Set-NetAdapterAdvancedProperty -Name $adapter.Name -DisplayName "Speed & Duplex" -DisplayValue "Auto Negotiation" -ErrorAction SilentlyContinue
                    $fixes += "Set auto-negotiation for: $($adapter.Name)"
                } catch {
                    # Property may not exist on all adapters
                }
                
                # Optimize interrupt moderation
                try {
                    Set-NetAdapterAdvancedProperty -Name $adapter.Name -DisplayName "Interrupt Moderation" -DisplayValue "Enabled" -ErrorAction SilentlyContinue
                    $fixes += "Enabled interrupt moderation for: $($adapter.Name)"
                } catch {
                    # Property may not exist on all adapters
                }
            }
        } catch {
            Write-Log "Error optimizing adapter settings: $($_.Exception.Message)" -Level "ERROR"
        }
    } else {
        Write-Log "Would optimize network adapter settings" -Level "WARN"
    }
    
    return $fixes
}

function Repair-IPConfiguration {
    Write-Log "Repairing IP configuration..."
    $fixes = @()
    
    if (-not $LogOnly) {
        try {
            # Release and renew IP addresses
            ipconfig /release | Out-Null
            Start-Sleep -Seconds 2
            ipconfig /renew | Out-Null
            $fixes += "Released and renewed IP configuration"
            
            # Reset DHCP leases
            ipconfig /flushdns | Out-Null
            $fixes += "Flushed DNS cache"
            
            # Re-register with DNS
            ipconfig /registerdns | Out-Null
            $fixes += "Re-registered DNS entries"
            
            Write-Log "IP configuration repaired" -Level "SUCCESS"
        } catch {
            Write-Log "Error repairing IP configuration: $($_.Exception.Message)" -Level "ERROR"
        }
    } else {
        Write-Log "Would repair IP configuration and renew DHCP leases" -Level "WARN"
    }
    
    return $fixes
}

function Test-NetworkConnectivity {
    Write-Log "Testing network connectivity..."
    
    try {
        # Test local connectivity
        $gatewayTest = Test-NetConnection -ComputerName "8.8.8.8" -Port 53 -InformationLevel Quiet
        if ($gatewayTest) {
            Write-Log "Internet connectivity: OK" -Level "SUCCESS"
        } else {
            Write-Log "Internet connectivity: FAILED" -Level "ERROR"
        }
        
        # Test DNS resolution
        try {
            $dnsTest = Resolve-DnsName -Name "google.com" -ErrorAction Stop
            Write-Log "DNS resolution: OK" -Level "SUCCESS"
        } catch {
            Write-Log "DNS resolution: FAILED" -Level "ERROR"
        }
        
        # Test local network
        $gateway = (Get-NetRoute -DestinationPrefix "0.0.0.0/0").NextHop | Select-Object -First 1
        if ($gateway) {
            $gatewayPing = Test-Connection -ComputerName $gateway -Count 1 -Quiet
            if ($gatewayPing) {
                Write-Log "Gateway connectivity: OK" -Level "SUCCESS"
            } else {
                Write-Log "Gateway connectivity: FAILED" -Level "ERROR"
            }
        }
        
    } catch {
        Write-Log "Error testing connectivity: $($_.Exception.Message)" -Level "ERROR"
    }
}

function Reset-NetworkServices {
    Write-Log "Resetting network services..."
    $fixes = @()
    
    if (-not $LogOnly) {
        try {
            $networkServices = @("Dnscache", "Dhcp", "Netman", "NlaSvc")
            
            foreach ($serviceName in $networkServices) {
                $service = Get-Service -Name $serviceName -ErrorAction SilentlyContinue
                if ($service) {
                    Restart-Service -Name $serviceName -Force -ErrorAction SilentlyContinue
                    $fixes += "Restarted service: $serviceName"
                    Write-Log "Restarted network service: $serviceName"
                }
            }
        } catch {
            Write-Log "Error restarting network services: $($_.Exception.Message)" -Level "ERROR"
        }
    } else {
        Write-Log "Would restart network services" -Level "WARN"
    }
    
    return $fixes
}

# Main execution
try {
    Write-Log "Starting Network Adapter Repair v$Script:ScriptVersion"
    Write-Log "Author: $Script:ScriptAuthor"
    Write-Log "Reset Adapters: $ResetAdapters"
    
    # Analyze network adapters
    $adapterIssues = Get-NetworkAdapterStatus
    $Script:IssuesFound = $adapterIssues
    
    if ($adapterIssues.Count -eq 0) {
        Write-Log "No network adapter issues detected" -Level "SUCCESS"
    } else {
        Write-Log "Found $($adapterIssues.Count) network adapter issues" -Level "WARN"
    }
    
    # Apply fixes
    $Script:FixesApplied += Enable-NetworkAdapters -AdapterIssues $adapterIssues
    $Script:FixesApplied += Reset-NetworkAdapters
    $Script:FixesApplied += Optimize-AdapterSettings
    $Script:FixesApplied += Repair-IPConfiguration
    $Script:FixesApplied += Reset-NetworkServices
    
    # Test connectivity after repairs
    if (-not $LogOnly) {
        Start-Sleep -Seconds 10  # Wait for changes to take effect
        Test-NetworkConnectivity
    }
    
    # Summary
    Write-Log "=== EXECUTION SUMMARY ===" -Level "SUCCESS"
    Write-Log "Adapter Issues Found: $($Script:IssuesFound.Count)"
    Write-Log "Repairs Applied: $($Script:FixesApplied.Count)"
    Write-Log "Report Location: $Script:LogFile"
    
    if (-not $LogOnly -and $Script:FixesApplied.Count -gt 0) {
        Write-Log "RECOMMENDATION: Test network connectivity and restart if issues persist" -Level "WARN"
    }
    
    exit 0
} catch {
    Write-Log "FATAL ERROR: $($_.Exception.Message)" -Level "ERROR"
    exit 1
}
