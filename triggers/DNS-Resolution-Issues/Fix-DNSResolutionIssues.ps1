#Requires -Version 5.1
#Requires -RunAsAdministrator

<#
.SYNOPSIS
    Diagnoses and repairs DNS resolution issues affecting network connectivity.

.DESCRIPTION
    This script identifies and fixes common DNS problems including:
    - DNS server configuration issues
    - DNS cache corruption
    - Hosts file problems
    - DNS client service issues
    - Network adapter DNS settings

.PARAMETER LogOnly
    Run in diagnostic mode only - no changes made

.PARAMETER PrimaryDNS
    Primary DNS server to configure (default: 8.8.8.8)

.PARAMETER SecondaryDNS
    Secondary DNS server to configure (default: 8.8.4.4)

.PARAMETER ReportPath
    Path to save diagnostic report

.EXAMPLE
    .\Fix-DNSResolution.ps1 -LogOnly
    Diagnose DNS issues without making changes

.EXAMPLE
    .\Fix-DNSResolution.ps1 -PrimaryDNS "1.1.1.1" -SecondaryDNS "1.0.0.1"
    Fix DNS with Cloudflare servers

.NOTES
    File Name: Fix-DNSResolution.ps1
    Version: 1.0
    Date: June 30, 2025
    Author: Wesley Ellis (Wesley.Ellis@compucom.com)
    Company: CompuCom - SysTrack Automation Team
    
    Impact: DNS issues affect web browsing and network access
    Priority: HIGH - Critical for internet and intranet connectivity
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [switch]$LogOnly,
    
    [Parameter(Mandatory = $false)]
    [string]$PrimaryDNS = "8.8.8.8",
    
    [Parameter(Mandatory = $false)]
    [string]$SecondaryDNS = "8.8.4.4",
    
    [Parameter(Mandatory = $false)]
    [string]$ReportPath = "$env:TEMP\DNS-Resolution-Report-$(Get-Date -Format 'yyyyMMdd-HHmmss').log"
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

function Test-DNSResolution {
    Write-Log "Testing DNS resolution..."
    $dnsIssues = @()
    
    # Test common domains
    $testDomains = @("google.com", "microsoft.com", "github.com", "cloudflare.com")
    
    foreach ($domain in $testDomains) {
        try {
            $result = Resolve-DnsName -Name $domain -ErrorAction Stop
            Write-Log "DNS resolution successful for $domain"
        } catch {
            $dnsIssues += [PSCustomObject]@{
                Domain = $domain
                Issue = "DNS resolution failed"
                Error = $_.Exception.Message
            }
            Write-Log "DNS resolution failed for $domain`: $($_.Exception.Message)" -Level "ERROR"
        }
    }
    
    # Test current DNS servers
    $adapters = Get-NetAdapter | Where-Object { $_.Status -eq "Up" }
    foreach ($adapter in $adapters) {
        $dnsServers = Get-DnsClientServerAddress -InterfaceIndex $adapter.InterfaceIndex -AddressFamily IPv4
        if (-not $dnsServers.ServerAddresses -or $dnsServers.ServerAddresses.Count -eq 0) {
            $dnsIssues += [PSCustomObject]@{
                Adapter = $adapter.Name
                Issue = "No DNS servers configured"
                Error = "Missing DNS configuration"
            }
        }
    }
    
    return $dnsIssues
}

function Repair-DNSCache {
    Write-Log "Repairing DNS cache..."
    $fixes = @()
    
    if (-not $LogOnly) {
        try {
            # Flush DNS cache
            ipconfig /flushdns | Out-Null
            $fixes += "Flushed DNS cache"
            
            # Restart DNS Client service
            Restart-Service -Name "Dnscache" -Force
            $fixes += "Restarted DNS Client service"
            
            # Reset DNS registration
            ipconfig /registerdns | Out-Null
            $fixes += "Re-registered DNS entries"
            
            Write-Log "DNS cache repaired successfully" -Level "SUCCESS"
        } catch {
            Write-Log "Error repairing DNS cache: $($_.Exception.Message)" -Level "ERROR"
        }
    } else {
        Write-Log "Would flush DNS cache and restart DNS service" -Level "WARN"
    }
    
    return $fixes
}

function Repair-DNSConfiguration {
    Write-Log "Repairing DNS server configuration..."
    $fixes = @()
    
    if (-not $LogOnly) {
        try {
            $adapters = Get-NetAdapter | Where-Object { $_.Status -eq "Up" -and $_.Virtual -eq $false }
            
            foreach ($adapter in $adapters) {
                # Set DNS servers
                Set-DnsClientServerAddress -InterfaceIndex $adapter.InterfaceIndex -ServerAddresses @($PrimaryDNS, $SecondaryDNS)
                $fixes += "Set DNS servers for $($adapter.Name): $PrimaryDNS, $SecondaryDNS"
                Write-Log "Configured DNS servers for adapter: $($adapter.Name)"
            }
        } catch {
            Write-Log "Error configuring DNS servers: $($_.Exception.Message)" -Level "ERROR"
        }
    } else {
        Write-Log "Would configure DNS servers: $PrimaryDNS, $SecondaryDNS" -Level "WARN"
    }
    
    return $fixes
}

function Repair-HostsFile {
    Write-Log "Checking and repairing hosts file..."
    $fixes = @()
    
    try {
        $hostsPath = "$env:WINDIR\System32\drivers\etc\hosts"
        
        if (Test-Path $hostsPath) {
            $hostsContent = Get-Content -Path $hostsPath
            $suspiciousEntries = @()
            
            # Check for suspicious entries
            foreach ($line in $hostsContent) {
                if ($line -match "^\s*[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+\s+([^\s#]+)" -and $line -notmatch "localhost|127\.0\.0\.1") {
                    $suspiciousEntries += $line
                }
            }
            
            if ($suspiciousEntries.Count -gt 0) {
                Write-Log "Found $($suspiciousEntries.Count) suspicious hosts file entries" -Level "WARN"
                
                if (-not $LogOnly) {
                    # Backup current hosts file
                    Copy-Item -Path $hostsPath -Destination "$hostsPath.backup.$(Get-Date -Format 'yyyyMMdd')"
                    
                    # Create clean hosts file
                    $cleanHosts = @"
# Copyright (c) 1993-2009 Microsoft Corp.
#
# This is a sample HOSTS file used by Microsoft TCP/IP for Windows.
#
# This file contains the mappings of IP addresses to host names. Each
# entry should be kept on an individual line. The IP address should
# be placed in the first column followed by the corresponding host name.
# The IP address and the host name should be separated by at least one
# space.
#
# Additionally, comments (such as these) may be inserted on individual
# lines or following the machine name denoted by a '#' symbol.
#
# For example:
#
#      102.54.94.97     rhino.acme.com          # source server
#       38.25.63.10     x.acme.com              # x client host

# localhost name resolution is handled within DNS itself.
#	127.0.0.1       localhost
#	::1             localhost
"@
                    Set-Content -Path $hostsPath -Value $cleanHosts
                    $fixes += "Cleaned hosts file and removed $($suspiciousEntries.Count) suspicious entries"
                    Write-Log "Hosts file cleaned successfully" -Level "SUCCESS"
                } else {
                    Write-Log "Would clean $($suspiciousEntries.Count) suspicious hosts file entries" -Level "WARN"
                }
            } else {
                Write-Log "Hosts file appears clean"
            }
        }
    } catch {
        Write-Log "Error checking hosts file: $($_.Exception.Message)" -Level "ERROR"
    }
    
    return $fixes
}

function Reset-NetworkStack {
    Write-Log "Resetting network stack..."
    $fixes = @()
    
    if (-not $LogOnly) {
        try {
            # Reset Winsock catalog
            netsh winsock reset | Out-Null
            $fixes += "Reset Winsock catalog"
            
            # Reset TCP/IP stack
            netsh int ip reset | Out-Null
            $fixes += "Reset TCP/IP stack"
            
            # Reset proxy settings
            netsh winhttp reset proxy | Out-Null
            $fixes += "Reset proxy settings"
            
            # Renew IP configuration
            ipconfig /release | Out-Null
            Start-Sleep -Seconds 2
            ipconfig /renew | Out-Null
            $fixes += "Renewed IP configuration"
            
            Write-Log "Network stack reset completed" -Level "SUCCESS"
        } catch {
            Write-Log "Error resetting network stack: $($_.Exception.Message)" -Level "ERROR"
        }
    } else {
        Write-Log "Would reset network stack and renew IP configuration" -Level "WARN"
    }
    
    return $fixes
}

function Test-DNSPerformance {
    Write-Log "Testing DNS performance..."
    
    try {
        $testServers = @(
            @{Name="Google Primary"; IP="8.8.8.8"},
            @{Name="Google Secondary"; IP="8.8.4.4"},
            @{Name="Cloudflare Primary"; IP="1.1.1.1"},
            @{Name="Cloudflare Secondary"; IP="1.0.0.1"}
        )
        
        foreach ($server in $testServers) {
            $ping = Test-Connection -ComputerName $server.IP -Count 3 -Quiet
            if ($ping) {
                $response = Test-Connection -ComputerName $server.IP -Count 1
                Write-Log "$($server.Name) ($($server.IP)): $($response.ResponseTime)ms"
            } else {
                Write-Log "$($server.Name) ($($server.IP)): Not reachable" -Level "WARN"
            }
        }
    } catch {
        Write-Log "Error testing DNS performance: $($_.Exception.Message)" -Level "ERROR"
    }
}

# Main execution
try {
    Write-Log "Starting DNS Resolution Repair v$Script:ScriptVersion"
    Write-Log "Author: $Script:ScriptAuthor"
    Write-Log "DNS Servers: $PrimaryDNS, $SecondaryDNS"
    
    # Test DNS resolution
    $dnsIssues = Test-DNSResolution
    $Script:IssuesFound = $dnsIssues
    
    if ($dnsIssues.Count -eq 0) {
        Write-Log "No DNS resolution issues detected" -Level "SUCCESS"
    } else {
        Write-Log "Found $($dnsIssues.Count) DNS issues" -Level "WARN"
    }
    
    # Apply repairs regardless of specific issues
    $Script:FixesApplied += Repair-DNSCache
    $Script:FixesApplied += Repair-DNSConfiguration
    $Script:FixesApplied += Repair-HostsFile
    $Script:FixesApplied += Reset-NetworkStack
    
    # Test performance after repairs
    if (-not $LogOnly) {
        Start-Sleep -Seconds 5  # Wait for changes to take effect
        Test-DNSPerformance
    }
    
    # Summary
    Write-Log "=== EXECUTION SUMMARY ===" -Level "SUCCESS"
    Write-Log "DNS Issues Found: $($Script:IssuesFound.Count)"
    Write-Log "Repairs Applied: $($Script:FixesApplied.Count)"
    Write-Log "Report Location: $Script:LogFile"
    
    if (-not $LogOnly -and $Script:FixesApplied.Count -gt 0) {
        Write-Log "RECOMMENDATION: Test DNS resolution and restart if issues persist" -Level "WARN"
    }
    
    exit 0
} catch {
    Write-Log "FATAL ERROR: $($_.Exception.Message)" -Level "ERROR"
    exit 1
}
