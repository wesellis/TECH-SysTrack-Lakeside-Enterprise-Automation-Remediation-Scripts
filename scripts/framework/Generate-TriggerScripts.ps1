#Requires -Version 5.1
#Requires -RunAsAdministrator

<#
.SYNOPSIS
    Automated PowerShell script generator for SysTrack triggers.

.DESCRIPTION
    This framework generates standardized detection and remediation scripts for SysTrack triggers
    using template-based generation with data-driven parameters. Creates production-ready
    scripts with comprehensive error handling, logging, and enterprise features.

.PARAMETER TriggerName
    Name of the trigger (e.g., "Thread-Count", "Memory-Leaks")

.PARAMETER SystemsAffected
    Number of systems affected by this trigger

.PARAMETER ImpactPercentage
    Percentage impact of this trigger

.PARAMETER Priority
    Priority level: CRITICAL, HIGH, MEDIUM, LOW

.PARAMETER Description
    Description of what this trigger detects/fixes

.PARAMETER TemplateType
    Template type: Memory, Network, Service, Application, System, Security

.PARAMETER OutputPath
    Base path for generated scripts (default: current triggers directory)

.PARAMETER GenerateDetection
    Generate detection script

.PARAMETER GenerateRemediation
    Generate remediation script

.PARAMETER GenerateMetadata
    Generate trigger-info.json metadata

.EXAMPLE
    .\Generate-TriggerScripts.ps1 -TriggerName "Java-Memory-Leak" -SystemsAffected 150 -ImpactPercentage 25 -Priority "HIGH" -Description "Java process memory leak detection" -TemplateType "Memory"

.EXAMPLE
    .\Generate-TriggerScripts.ps1 -TriggerName "Supervisor-Service-Stopped" -SystemsAffected 45 -ImpactPercentage 78 -Priority "CRITICAL" -Description "SysTrack Supervisor service failure" -TemplateType "Service"

.NOTES
    File Name: Generate-TriggerScripts.ps1
    Version: 1.0
    Date: July 01, 2025
    Author: Wesley Ellis (Wesley.Ellis@compucom.com)
    Company: CompuCom - SysTrack Automation Team
    
    This script generates the infrastructure for scaling to 600+ automation scripts
    by providing template-based generation with enterprise standards.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$TriggerName,
    
    [Parameter(Mandatory = $true)]
    [int]$SystemsAffected,
    
    [Parameter(Mandatory = $true)]
    [int]$ImpactPercentage,
    
    [Parameter(Mandatory = $true)]
    [ValidateSet("CRITICAL", "HIGH", "MEDIUM", "LOW")]
    [string]$Priority,
    
    [Parameter(Mandatory = $true)]
    [string]$Description,
    
    [Parameter(Mandatory = $true)]
    [ValidateSet("Memory", "Network", "Service", "Application", "System", "Security", "Hardware", "Performance")]
    [string]$TemplateType,
    
    [Parameter(Mandatory = $false)]
    [string]$OutputPath = "$PSScriptRoot\..\..\triggers",
    
    [Parameter(Mandatory = $false)]
    [switch]$GenerateDetection = $true,
    
    [Parameter(Mandatory = $false)]
    [switch]$GenerateRemediation = $true,
    
    [Parameter(Mandatory = $false)]
    [switch]$GenerateMetadata = $true
)

# Script metadata
$Script:Version = "1.0"
$Script:Date = "2025-07-01"
$Script:Author = "Wesley Ellis (Wesley.Ellis@compucom.com)"

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
}

function Get-ScriptTemplate {
    param(
        [string]$TemplateType,
        [string]$ScriptType  # "Detection" or "Remediation"
    )
    
    $commonHeader = @"
#Requires -Version 5.1
#Requires -RunAsAdministrator

<#
.SYNOPSIS
    $ScriptType script for $TriggerName trigger.

.DESCRIPTION
    This script $(if ($ScriptType -eq "Detection") { "detects" } else { "remediates" }) $Description.
    
    Impact: $SystemsAffected systems affected ($ImpactPercentage% of enterprise fleet)
    Priority: $Priority
    
.PARAMETER LogOnly
    Run in diagnostic mode only - no changes made (remediation scripts only)

.PARAMETER ReportPath
    Path to save diagnostic report

.EXAMPLE
    .\$ScriptType-$($TriggerName.Replace('-','')).ps1 -LogOnly
    Run diagnostic scan without making changes

.NOTES
    File Name: $ScriptType-$($TriggerName.Replace('-','')).ps1
    Version: 1.0
    Date: $Script:Date
    Author: $Script:Author
    Company: CompuCom - SysTrack Automation Team
    Requires: Administrator privileges
    Tested: Windows 10/11, Server 2016/2019/2022
    
    Trigger: $TriggerName
    Systems Affected: $SystemsAffected ($ImpactPercentage% impact)
    Priority: $Priority
#>

[CmdletBinding()]
param(
"@

    if ($ScriptType -eq "Remediation") {
        $commonHeader += @"
    [Parameter(Mandatory = `$false)]
    [switch]`$LogOnly,
    
"@
    }

    $commonHeader += @"
    [Parameter(Mandatory = `$false)]
    [string]`$ReportPath = "`$env:TEMP\$TriggerName-Report-`$(Get-Date -Format 'yyyyMMdd-HHmmss').log"
)

# Script metadata
`$Script:ScriptVersion = "1.0"
`$Script:ScriptDate = "$Script:Date"
`$Script:ScriptAuthor = "$Script:Author"
`$Script:TriggerName = "$TriggerName"
`$Script:SystemsAffected = $SystemsAffected
`$Script:ImpactPercentage = $ImpactPercentage
`$Script:Priority = "$Priority"

# Initialize logging
`$Script:LogFile = `$ReportPath
`$Script:StartTime = Get-Date
`$Script:IssuesFound = @()
"@

    if ($ScriptType -eq "Remediation") {
        $commonHeader += "`$Script:FixesApplied = @()`n"
    }

    $commonHeader += @"

function Write-Log {
    param(
        [string]`$Message,
        [string]`$Level = "INFO"
    )
    `$timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    `$logEntry = "[`$timestamp] [`$Level] `$Message"
    Write-Host `$logEntry -ForegroundColor `$(
        switch (`$Level) {
            "ERROR" { "Red" }
            "WARN" { "Yellow" }
            "SUCCESS" { "Green" }
            default { "White" }
        }
    )
    Add-Content -Path `$Script:LogFile -Value `$logEntry -ErrorAction SilentlyContinue
}

"@

    # Add template-specific functions based on type
    switch ($TemplateType) {
        "Memory" {
            $templateFunctions = Get-MemoryTemplate -ScriptType $ScriptType
        }
        "Network" {
            $templateFunctions = Get-NetworkTemplate -ScriptType $ScriptType
        }
        "Service" {
            $templateFunctions = Get-ServiceTemplate -ScriptType $ScriptType
        }
        "Application" {
            $templateFunctions = Get-ApplicationTemplate -ScriptType $ScriptType
        }
        "System" {
            $templateFunctions = Get-SystemTemplate -ScriptType $ScriptType
        }
        "Security" {
            $templateFunctions = Get-SecurityTemplate -ScriptType $ScriptType
        }
        "Hardware" {
            $templateFunctions = Get-HardwareTemplate -ScriptType $ScriptType
        }
        "Performance" {
            $templateFunctions = Get-PerformanceTemplate -ScriptType $ScriptType
        }
        default {
            $templateFunctions = Get-GenericTemplate -ScriptType $ScriptType
        }
    }

    return $commonHeader + $templateFunctions + (Get-CommonFooter -ScriptType $ScriptType)
}

function Get-MemoryTemplate {
    param([string]$ScriptType)
    
    if ($ScriptType -eq "Detection") {
        return @"
function Test-MemoryLeaks {
    Write-Log "Analyzing memory usage patterns..."
    
    try {
        `$processes = Get-Process | Where-Object { `$_.WorkingSet -gt 100MB }
        `$memoryIssues = @()
        
        foreach (`$process in `$processes) {
            `$memoryMB = [math]::Round(`$process.WorkingSet / 1MB, 2)
            
            # Check for memory leak indicators
            if (`$memoryMB -gt 500) {  # Customize threshold based on specific trigger
                `$memoryIssues += [PSCustomObject]@{
                    ProcessName = `$process.ProcessName
                    PID = `$process.Id
                    WorkingSetMB = `$memoryMB
                    Issue = "High memory usage: `$memoryMB MB"
                    StartTime = `$process.StartTime
                }
                Write-Log "Memory issue detected: `$(`$process.ProcessName) using `$memoryMB MB" -Level "WARN"
            }
        }
        
        `$Script:IssuesFound = `$memoryIssues
        return `$memoryIssues.Count -gt 0
    }
    catch {
        Write-Log "Error analyzing memory: `$(`$_.Exception.Message)" -Level "ERROR"
        return `$false
    }
}

"@
    } else {
        return @"
function Test-MemoryLeaks {
    Write-Log "Analyzing memory usage patterns..."
    
    try {
        `$processes = Get-Process | Where-Object { `$_.WorkingSet -gt 100MB }
        `$memoryIssues = @()
        
        foreach (`$process in `$processes) {
            `$memoryMB = [math]::Round(`$process.WorkingSet / 1MB, 2)
            
            if (`$memoryMB -gt 500) {  # Customize threshold
                `$memoryIssues += [PSCustomObject]@{
                    ProcessName = `$process.ProcessName
                    PID = `$process.Id
                    WorkingSetMB = `$memoryMB
                    Issue = "High memory usage: `$memoryMB MB"
                    StartTime = `$process.StartTime
                }
            }
        }
        
        `$Script:IssuesFound = `$memoryIssues
        return `$memoryIssues
    }
    catch {
        Write-Log "Error analyzing memory: `$(`$_.Exception.Message)" -Level "ERROR"
        return @()
    }
}

function Repair-MemoryLeaks {
    param([array]`$MemoryIssues)
    
    Write-Log "Repairing memory leak issues..."
    `$fixesApplied = @()
    
    foreach (`$issue in `$MemoryIssues) {
        try {
            Write-Log "Processing high memory process: `$(`$issue.ProcessName) (PID: `$(`$issue.PID))"
            
            if (-not `$LogOnly) {
                # Restart the problematic process if safe to do so
                `$process = Get-Process -Id `$issue.PID -ErrorAction SilentlyContinue
                if (`$process -and `$process.ProcessName -notin @("explorer", "winlogon", "csrss", "lsass", "services")) {
                    Write-Log "Terminating high memory process: `$(`$process.ProcessName)"
                    Stop-Process -Id `$issue.PID -Force -ErrorAction SilentlyContinue
                    `$fixesApplied += "Terminated high memory process: `$(`$issue.ProcessName) (`$(`$issue.WorkingSetMB) MB)"
                }
            } else {
                Write-Log "Would terminate process: `$(`$issue.ProcessName) (`$(`$issue.WorkingSetMB) MB)" -Level "WARN"
            }
        }
        catch {
            Write-Log "Error fixing memory issue for `$(`$issue.ProcessName): `$(`$_.Exception.Message)" -Level "ERROR"
        }
    }
    
    return `$fixesApplied
}

"@
    }
}

function Get-ServiceTemplate {
    param([string]$ScriptType)
    
    if ($ScriptType -eq "Detection") {
        return @"
function Test-ServiceStatus {
    Write-Log "Checking critical service status..."
    
    try {
        # Customize service names based on specific trigger
        `$criticalServices = @("Supervisor", "SysTrack", "Netlogon", "W32Time")  # Customize for specific trigger
        `$serviceIssues = @()
        
        foreach (`$serviceName in `$criticalServices) {
            `$service = Get-Service -Name `$serviceName -ErrorAction SilentlyContinue
            if (`$service) {
                if (`$service.Status -ne "Running") {
                    `$serviceIssues += [PSCustomObject]@{
                        ServiceName = `$service.Name
                        DisplayName = `$service.DisplayName
                        Status = `$service.Status
                        StartType = `$service.StartType
                        Issue = "Service not running: `$(`$service.Status)"
                    }
                    Write-Log "Service issue detected: `$(`$service.DisplayName) is `$(`$service.Status)" -Level "WARN"
                }
            } else {
                `$serviceIssues += [PSCustomObject]@{
                    ServiceName = `$serviceName
                    DisplayName = "Unknown"
                    Status = "NotFound"
                    StartType = "Unknown"
                    Issue = "Service not found"
                }
                Write-Log "Service not found: `$serviceName" -Level "WARN"
            }
        }
        
        `$Script:IssuesFound = `$serviceIssues
        return `$serviceIssues.Count -gt 0
    }
    catch {
        Write-Log "Error checking services: `$(`$_.Exception.Message)" -Level "ERROR"
        return `$false
    }
}

"@
    } else {
        return @"
function Test-ServiceStatus {
    Write-Log "Checking critical service status..."
    
    try {
        `$criticalServices = @("Supervisor", "SysTrack", "Netlogon", "W32Time")  # Customize
        `$serviceIssues = @()
        
        foreach (`$serviceName in `$criticalServices) {
            `$service = Get-Service -Name `$serviceName -ErrorAction SilentlyContinue
            if (`$service -and `$service.Status -ne "Running") {
                `$serviceIssues += [PSCustomObject]@{
                    ServiceName = `$service.Name
                    DisplayName = `$service.DisplayName
                    Status = `$service.Status
                    StartType = `$service.StartType
                    Issue = "Service not running"
                }
            }
        }
        
        `$Script:IssuesFound = `$serviceIssues
        return `$serviceIssues
    }
    catch {
        Write-Log "Error checking services: `$(`$_.Exception.Message)" -Level "ERROR"
        return @()
    }
}

function Repair-ServiceIssues {
    param([array]`$ServiceIssues)
    
    Write-Log "Repairing service issues..."
    `$fixesApplied = @()
    
    foreach (`$issue in `$ServiceIssues) {
        try {
            Write-Log "Processing service: `$(`$issue.ServiceName)"
            
            if (-not `$LogOnly) {
                `$service = Get-Service -Name `$issue.ServiceName -ErrorAction SilentlyContinue
                if (`$service) {
                    # Set service to automatic if not already
                    if (`$service.StartType -ne "Automatic") {
                        Set-Service -Name `$issue.ServiceName -StartupType Automatic
                        Write-Log "Set `$(`$issue.ServiceName) to Automatic startup"
                    }
                    
                    # Start the service
                    Start-Service -Name `$issue.ServiceName -ErrorAction Stop
                    Write-Log "Started service: `$(`$issue.DisplayName)" -Level "SUCCESS"
                    `$fixesApplied += "Started service: `$(`$issue.DisplayName)"
                }
            } else {
                Write-Log "Would start service: `$(`$issue.DisplayName)" -Level "WARN"
            }
        }
        catch {
            Write-Log "Error starting service `$(`$issue.ServiceName): `$(`$_.Exception.Message)" -Level "ERROR"
        }
    }
    
    return `$fixesApplied
}

"@
    }
}

function Get-NetworkTemplate {
    param([string]$ScriptType)
    
    if ($ScriptType -eq "Detection") {
        return @"
function Test-NetworkConnectivity {
    Write-Log "Testing network connectivity and performance..."
    
    try {
        `$networkIssues = @()
        
        # Test default gateway latency
        `$gateway = (Get-NetRoute -DestinationPrefix "0.0.0.0/0").NextHop | Select-Object -First 1
        if (`$gateway) {
            `$pingResult = Test-Connection -ComputerName `$gateway -Count 4 -ErrorAction SilentlyContinue
            if (`$pingResult) {
                `$avgLatency = (`$pingResult.ResponseTime | Measure-Object -Average).Average
                if (`$avgLatency -gt 50) {  # Customize threshold
                    `$networkIssues += [PSCustomObject]@{
                        Component = "Default Gateway"
                        Address = `$gateway
                        Latency = `$avgLatency
                        Issue = "High latency to default gateway: `$avgLatency ms"
                    }
                    Write-Log "High gateway latency detected: `$avgLatency ms" -Level "WARN"
                }
            } else {
                `$networkIssues += [PSCustomObject]@{
                    Component = "Default Gateway"
                    Address = `$gateway
                    Latency = "Timeout"
                    Issue = "Cannot reach default gateway"
                }
            }
        }
        
        # Test DNS resolution
        try {
            `$dnsTest = Resolve-DnsName -Name "google.com" -ErrorAction Stop
            if (-not `$dnsTest) {
                `$networkIssues += [PSCustomObject]@{
                    Component = "DNS Resolution"
                    Address = "N/A"
                    Latency = "N/A"
                    Issue = "DNS resolution failed"
                }
            }
        }
        catch {
            `$networkIssues += [PSCustomObject]@{
                Component = "DNS Resolution"
                Address = "N/A"
                Latency = "N/A"
                Issue = "DNS resolution error: `$(`$_.Exception.Message)"
            }
        }
        
        `$Script:IssuesFound = `$networkIssues
        return `$networkIssues.Count -gt 0
    }
    catch {
        Write-Log "Error testing network: `$(`$_.Exception.Message)" -Level "ERROR"
        return `$false
    }
}

"@
    } else {
        return @"
function Test-NetworkConnectivity {
    Write-Log "Testing network connectivity and performance..."
    
    try {
        `$networkIssues = @()
        
        # Test gateway latency and DNS
        `$gateway = (Get-NetRoute -DestinationPrefix "0.0.0.0/0").NextHop | Select-Object -First 1
        if (`$gateway) {
            `$pingResult = Test-Connection -ComputerName `$gateway -Count 4 -ErrorAction SilentlyContinue
            if (`$pingResult) {
                `$avgLatency = (`$pingResult.ResponseTime | Measure-Object -Average).Average
                if (`$avgLatency -gt 50) {
                    `$networkIssues += [PSCustomObject]@{
                        Component = "Default Gateway"
                        Address = `$gateway
                        Issue = "High latency: `$avgLatency ms"
                    }
                }
            }
        }
        
        `$Script:IssuesFound = `$networkIssues
        return `$networkIssues
    }
    catch {
        Write-Log "Error testing network: `$(`$_.Exception.Message)" -Level "ERROR"
        return @()
    }
}

function Repair-NetworkIssues {
    param([array]`$NetworkIssues)
    
    Write-Log "Repairing network connectivity issues..."
    `$fixesApplied = @()
    
    foreach (`$issue in `$NetworkIssues) {
        try {
            Write-Log "Processing network issue: `$(`$issue.Component)"
            
            if (-not `$LogOnly) {
                switch (`$issue.Component) {
                    "Default Gateway" {
                        # Reset network adapter
                        `$adapters = Get-NetAdapter | Where-Object { `$_.Status -eq "Up" }
                        foreach (`$adapter in `$adapters) {
                            Write-Log "Resetting network adapter: `$(`$adapter.Name)"
                            Restart-NetAdapter -Name `$adapter.Name -Confirm:`$false
                            `$fixesApplied += "Reset network adapter: `$(`$adapter.Name)"
                        }
                    }
                    "DNS Resolution" {
                        # Flush DNS cache
                        ipconfig /flushdns | Out-Null
                        Write-Log "Flushed DNS cache"
                        `$fixesApplied += "Flushed DNS cache"
                    }
                }
            } else {
                Write-Log "Would repair network issue: `$(`$issue.Component)" -Level "WARN"
            }
        }
        catch {
            Write-Log "Error fixing network issue `$(`$issue.Component): `$(`$_.Exception.Message)" -Level "ERROR"
        }
    }
    
    return `$fixesApplied
}

"@
    }
}

function Get-GenericTemplate {
    param([string]$ScriptType)
    
    if ($ScriptType -eq "Detection") {
        return @"
function Test-TriggerCondition {
    Write-Log "Testing for $TriggerName condition..."
    
    try {
        # TODO: Implement specific detection logic for $TriggerName
        `$issues = @()
        
        # Placeholder detection logic - customize based on specific trigger
        Write-Log "Placeholder detection logic for $TriggerName"
        
        `$Script:IssuesFound = `$issues
        return `$issues.Count -gt 0
    }
    catch {
        Write-Log "Error detecting condition: `$(`$_.Exception.Message)" -Level "ERROR"
        return `$false
    }
}

"@
    } else {
        return @"
function Test-TriggerCondition {
    Write-Log "Testing for $TriggerName condition..."
    
    try {
        # TODO: Implement detection logic
        `$issues = @()
        
        `$Script:IssuesFound = `$issues
        return `$issues
    }
    catch {
        Write-Log "Error detecting condition: `$(`$_.Exception.Message)" -Level "ERROR"
        return @()
    }
}

function Repair-TriggerIssues {
    param([array]`$Issues)
    
    Write-Log "Repairing $TriggerName issues..."
    `$fixesApplied = @()
    
    foreach (`$issue in `$Issues) {
        try {
            if (-not `$LogOnly) {
                # TODO: Implement specific remediation logic for $TriggerName
                Write-Log "Placeholder remediation logic for $TriggerName"
                `$fixesApplied += "Applied fix for: `$(`$issue.ToString())"
            } else {
                Write-Log "Would apply fix for: `$(`$issue.ToString())" -Level "WARN"
            }
        }
        catch {
            Write-Log "Error applying fix: `$(`$_.Exception.Message)" -Level "ERROR"
        }
    }
    
    return `$fixesApplied
}

"@
    }
}

function Get-CommonFooter {
    param([string]$ScriptType)
    
    if ($ScriptType -eq "Detection") {
        return @"
function Generate-Report {
    param([array]`$Issues)
    
    Write-Log "Generating diagnostic report..."
    
    `$report = @"
====================================================================
$TriggerName DETECTION REPORT
====================================================================
Report Generated: `$(Get-Date)
Script Version: `$Script:ScriptVersion
Computer: `$env:COMPUTERNAME
User: `$env:USERNAME
Trigger: `$Script:TriggerName
Systems Affected: `$Script:SystemsAffected (`$Script:ImpactPercentage% impact)
Priority: `$Script:Priority

DETECTION RESULTS:
====================================================================
Issues Found: `$(`$Issues.Count)

"@
    
    foreach (`$issue in `$Issues) {
        `$report += "Issue: `$(`$issue | ConvertTo-Json -Compress)`n"
    }
    
    `$report += @"

RECOMMENDATIONS:
====================================================================
1. Run corresponding remediation script if issues found
2. Monitor system after remediation
3. Schedule regular detection scans
4. Review SysTrack alerts for pattern analysis

====================================================================
Report saved to: `$Script:LogFile
Detection time: `$((Get-Date) - `$Script:StartTime)
====================================================================
"@
    
    Add-Content -Path `$Script:LogFile -Value `$report
    Write-Log "Report saved to: `$Script:LogFile" -Level "SUCCESS"
}

# Main execution
try {
    Write-Log "Starting $TriggerName Detection Script v`$Script:ScriptVersion"
    Write-Log "Priority: `$Script:Priority | Impact: `$Script:ImpactPercentage% | Systems: `$Script:SystemsAffected"
    
    `$detected = Test-TriggerCondition
    
    if (`$detected) {
        Write-Log "Issues detected for $TriggerName" -Level "WARN"
        Write-Log "Found `$(`$Script:IssuesFound.Count) issues requiring attention"
    } else {
        Write-Log "No issues detected for $TriggerName" -Level "SUCCESS"
    }
    
    Generate-Report -Issues `$Script:IssuesFound
    
    Write-Log "=== DETECTION SUMMARY ===" -Level "SUCCESS"
    Write-Log "Issues Found: `$(`$Script:IssuesFound.Count)"
    Write-Log "Detection Time: `$((Get-Date) - `$Script:StartTime)"
    Write-Log "Report Location: `$Script:LogFile"
    
    if (`$detected) {
        exit 1  # Issues found
    } else {
        exit 0  # No issues
    }
}
catch {
    Write-Log "FATAL ERROR: `$(`$_.Exception.Message)" -Level "ERROR"
    Write-Log "Stack Trace: `$(`$_.ScriptStackTrace)" -Level "ERROR"
    exit 2  # Error occurred
}
"@
    } else {
        return @"
function Generate-Report {
    param([array]`$Issues, [array]`$Fixes)
    
    Write-Log "Generating remediation report..."
    
    `$report = @"
====================================================================
$TriggerName REMEDIATION REPORT
====================================================================
Report Generated: `$(Get-Date)
Script Version: `$Script:ScriptVersion
Computer: `$env:COMPUTERNAME
User: `$env:USERNAME
Script Mode: `$(if (`$LogOnly) { "DIAGNOSTIC ONLY" } else { "REMEDIATION" })
Trigger: `$Script:TriggerName
Systems Affected: `$Script:SystemsAffected (`$Script:ImpactPercentage% impact)
Priority: `$Script:Priority

REMEDIATION RESULTS:
====================================================================
Issues Found: `$(`$Issues.Count)
Fixes Applied: `$(`$Fixes.Count)

DETAILED FINDINGS:
====================================================================
"@
    
    foreach (`$issue in `$Issues) {
        `$report += "Issue: `$(`$issue | ConvertTo-Json -Compress)`n"
    }
    
    if (`$Fixes.Count -gt 0) {
        `$report += @"

REMEDIATION ACTIONS TAKEN:
====================================================================
"@
        foreach (`$fix in `$Fixes) {
            `$report += "- `$fix`n"
        }
    }
    
    `$report += @"

RECOMMENDATIONS:
====================================================================
1. Monitor system performance after remediation
2. Run detection script to verify fixes
3. Schedule regular preventive maintenance
4. Review SysTrack metrics for improvement

====================================================================
Report saved to: `$Script:LogFile
Remediation time: `$((Get-Date) - `$Script:StartTime)
====================================================================
"@
    
    Add-Content -Path `$Script:LogFile -Value `$report
    Write-Log "Report saved to: `$Script:LogFile" -Level "SUCCESS"
}

# Main execution
try {
    Write-Log "Starting $TriggerName Remediation Script v`$Script:ScriptVersion"
    Write-Log "Priority: `$Script:Priority | Impact: `$Script:ImpactPercentage% | Systems: `$Script:SystemsAffected"
    Write-Log "Mode: `$(if (`$LogOnly) { 'DIAGNOSTIC ONLY' } else { 'REMEDIATION' })"
    
    `$issues = Test-TriggerCondition
    
    if (`$issues.Count -eq 0) {
        Write-Log "No issues detected for $TriggerName" -Level "SUCCESS"
    } else {
        Write-Log "Found `$(`$issues.Count) issues for $TriggerName" -Level "WARN"
        `$Script:FixesApplied += Repair-TriggerIssues -Issues `$issues
    }
    
    Generate-Report -Issues `$Script:IssuesFound -Fixes `$Script:FixesApplied
    
    Write-Log "=== REMEDIATION SUMMARY ===" -Level "SUCCESS"
    Write-Log "Issues Found: `$(`$Script:IssuesFound.Count)"
    Write-Log "Fixes Applied: `$(`$Script:FixesApplied.Count)"
    Write-Log "Execution Time: `$((Get-Date) - `$Script:StartTime)"
    Write-Log "Report Location: `$Script:LogFile"
    
    if (-not `$LogOnly -and `$Script:FixesApplied.Count -gt 0) {
        Write-Log "RECOMMENDATION: Monitor system to ensure fixes are effective" -Level "WARN"
    }
    
    exit 0
}
catch {
    Write-Log "FATAL ERROR: `$(`$_.Exception.Message)" -Level "ERROR"
    Write-Log "Stack Trace: `$(`$_.ScriptStackTrace)" -Level "ERROR"
    exit 1
}
"@
    }
}

function New-TriggerFolder {
    param([string]$TriggerPath)
    
    if (-not (Test-Path $TriggerPath)) {
        New-Item -Path $TriggerPath -ItemType Directory -Force | Out-Null
        Write-Log "Created trigger folder: $TriggerPath" -Level "SUCCESS"
    }
}

function New-TriggerMetadata {
    param([string]$TriggerPath)
    
    $metadata = @{
        triggerName = $TriggerName
        description = $Description
        priority = $Priority
        systemsAffected = $SystemsAffected
        impactPercentage = $ImpactPercentage
        templateType = $TemplateType
        detectionScript = "Detect-$($TriggerName.Replace('-','')).ps1"
        remediationScript = "Fix-$($TriggerName.Replace('-','')).ps1"
        created = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
        version = "1.0"
        author = $Script:Author
    }
    
    $metadataPath = Join-Path $TriggerPath "trigger-info.json"
    $metadata | ConvertTo-Json -Depth 10 | Set-Content -Path $metadataPath
    Write-Log "Created metadata file: $metadataPath" -Level "SUCCESS"
}

# Main execution
try {
    Write-Log "Starting Trigger Script Generator v$Script:Version"
    Write-Log "Author: $Script:Author"
    Write-Log "Generating scripts for trigger: $TriggerName"
    Write-Log "Template Type: $TemplateType"
    Write-Log "Priority: $Priority ($SystemsAffected systems, $ImpactPercentage% impact)"
    
    # Create trigger folder
    $triggerFolder = $TriggerName
    $triggerPath = Join-Path $OutputPath $triggerFolder
    New-TriggerFolder -TriggerPath $triggerPath
    
    # Generate detection script
    if ($GenerateDetection) {
        $detectionScript = Get-ScriptTemplate -TemplateType $TemplateType -ScriptType "Detection"
        $detectionPath = Join-Path $triggerPath "Detect-$($TriggerName.Replace('-','')).ps1"
        $detectionScript | Set-Content -Path $detectionPath
        Write-Log "Generated detection script: $detectionPath" -Level "SUCCESS"
    }
    
    # Generate remediation script
    if ($GenerateRemediation) {
        $remediationScript = Get-ScriptTemplate -TemplateType $TemplateType -ScriptType "Remediation"
        $remediationPath = Join-Path $triggerPath "Fix-$($TriggerName.Replace('-','')).ps1"
        $remediationScript | Set-Content -Path $remediationPath
        Write-Log "Generated remediation script: $remediationPath" -Level "SUCCESS"
    }
    
    # Generate metadata
    if ($GenerateMetadata) {
        New-TriggerMetadata -TriggerPath $triggerPath
    }
    
    Write-Log "=== GENERATION COMPLETE ===" -Level "SUCCESS"
    Write-Log "Trigger Folder: $triggerPath"
    Write-Log "Files Generated: $(if($GenerateDetection){'Detection, '})$(if($GenerateRemediation){'Remediation, '})$(if($GenerateMetadata){'Metadata'})"
    Write-Log "Template Type: $TemplateType"
    Write-Log "Ready for customization and testing"
    
    exit 0
}
catch {
    Write-Log "FATAL ERROR: $($_.Exception.Message)" -Level "ERROR"
    Write-Log "Stack Trace: $($_.ScriptStackTrace)" -Level "ERROR"
    exit 1
}
