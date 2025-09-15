#Requires -Version 5.1
#Requires -RunAsAdministrator

<#
.SYNOPSIS
    Mass generation script for high-impact SysTrack automation triggers.

.DESCRIPTION
    Generates detection and remediation scripts for the top priority triggers
    identified from SysTrack data analysis. Automates the creation of 50+ 
    high-impact trigger scripts using data-driven generation.

.PARAMETER GenerateAll
    Generate all high-impact triggers

.PARAMETER GenerateCritical
    Generate only CRITICAL priority triggers

.PARAMETER GenerateHigh
    Generate only HIGH priority triggers

.PARAMETER OutputPath
    Base path for generated scripts

.EXAMPLE
    .\Generate-HighImpactTriggers.ps1 -GenerateCritical
    Generate only critical priority triggers

.EXAMPLE
    .\Generate-HighImpactTriggers.ps1 -GenerateAll
    Generate all high-impact triggers

.NOTES
    File Name: Generate-HighImpactTriggers.ps1
    Version: 1.0
    Date: July 01, 2025
    Author: Wesley Ellis (Wesley.Ellis@compucom.com)
    Company: CompuCom - SysTrack Automation Team
    
    This script creates the foundation for rapid scaling to 600+ scripts
    by generating all high-impact triggers with production-ready templates.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [switch]$GenerateAll,
    
    [Parameter(Mandatory = $false)]
    [switch]$GenerateCritical,
    
    [Parameter(Mandatory = $false)]
    [switch]$GenerateHigh,
    
    [Parameter(Mandatory = $false)]
    [string]$OutputPath = "$PSScriptRoot\..\..\triggers"
)

# High-impact triggers data from SysTrack analysis
$HighImpactTriggers = @(
    # CRITICAL PRIORITY - Immediate Automation Required
    @{Name="Supervisor-Service-Stopped"; Systems=45; Impact=95; Priority="CRITICAL"; Description="SysTrack Supervisor service failure"; TemplateType="Service"},
    @{Name="Netlogon-Service-Stopped"; Systems=25; Impact=90; Priority="CRITICAL"; Description="Domain authentication service failure"; TemplateType="Service"},
    @{Name="Persistent-Blue-Screen"; Systems=15; Impact=100; Priority="CRITICAL"; Description="Recurring system crashes and blue screens"; TemplateType="System"},
    @{Name="Azure-AD-P2P-Certificate-Failure"; Systems=85; Impact=75; Priority="CRITICAL"; Description="Azure AD certificate authentication failure"; TemplateType="Security"},
    @{Name="Certificate-Expiry"; Systems=45; Impact=80; Priority="CRITICAL"; Description="Critical certificate expiration monitoring"; TemplateType="Security"},
    @{Name="Windows-Defender-Signature-Failed"; Systems=35; Impact=85; Priority="CRITICAL"; Description="Antivirus signature update failures"; TemplateType="Security"},
    @{Name="Qualys-Cloud-Agent-Stopped"; Systems=25; Impact=88; Priority="CRITICAL"; Description="Security scanning agent failure"; TemplateType="Service"},
    @{Name="InTune-Management-Extension-Stopped"; Systems=65; Impact=70; Priority="CRITICAL"; Description="Device management service failure"; TemplateType="Service"},
    @{Name="CiscoAnyConnect-Service-Stopped"; Systems=120; Impact=65; Priority="CRITICAL"; Description="VPN service failure"; TemplateType="Service"},
    
    # HIGH PRIORITY - Week 1-2 Implementation  
    @{Name="Azure-AD-Logon-Failure"; Systems=180; Impact=60; Priority="HIGH"; Description="Azure AD authentication failures"; TemplateType="Security"},
    @{Name="Azure-AD-CloudAP-Plugin-Error"; Systems=152; Impact=55; Priority="HIGH"; Description="Cloud authentication plugin errors"; TemplateType="Security"},
    @{Name="Azure-AD-Grant-Token-Failure"; Systems=114; Impact=50; Priority="HIGH"; Description="Token grant authentication failures"; TemplateType="Security"},
    @{Name="Azure-AD-Refresh-Token-Failure"; Systems=114; Impact=50; Priority="HIGH"; Description="Token refresh authentication failures"; TemplateType="Security"},
    @{Name="Azure-AD-HTTP-Transport-Error"; Systems=85; Impact=45; Priority="HIGH"; Description="HTTP transport errors in Azure AD"; TemplateType="Network"},
    @{Name="User-Group-Add-Local-Admin"; Systems=87; Impact=85; Priority="HIGH"; Description="Unauthorized local admin privilege escalation"; TemplateType="Security"},
    @{Name="Citrix-Workspace-Outdated"; Systems=77; Impact=40; Priority="HIGH"; Description="Outdated Citrix Workspace application"; TemplateType="Application"},
    @{Name="Trellix-Agent-Not-Installed"; Systems=65; Impact=75; Priority="HIGH"; Description="Missing security agent installation"; TemplateType="Service"},
    @{Name="Agent-Not-Talking-Supervisor"; Systems=55; Impact=70; Priority="HIGH"; Description="SysTrack agent communication failure"; TemplateType="Service"},
    @{Name="SysTrack-TrayApp-Not-Running"; Systems=26; Impact=60; Priority="HIGH"; Description="SysTrack tray application not running"; TemplateType="Service"},
    
    # HIGH PRIORITY - Memory Management
    @{Name="Memory-Leak-Lsaiso"; Systems=180; Impact=55; Priority="HIGH"; Description="LSA Isolation process memory leak"; TemplateType="Memory"},
    @{Name="Non-Paged-Pool-Leak-Lsaiso"; Systems=194; Impact=50; Priority="HIGH"; Description="Non-paged pool leak in LSA Isolation"; TemplateType="Memory"},
    @{Name="Memory-Leak-Tabtip"; Systems=36; Impact=25; Priority="HIGH"; Description="Touch keyboard process memory leak"; TemplateType="Memory"},
    @{Name="Memory-Leak-Chrome"; Systems=36; Impact=30; Priority="HIGH"; Description="Chrome browser memory leak"; TemplateType="Memory"},
    @{Name="Memory-Leak-Wfcrun32"; Systems=32; Impact=25; Priority="HIGH"; Description="Windows Font Cache memory leak"; TemplateType="Memory"},
    @{Name="Memory-Leak-Wudfcompanionhost"; Systems=29; Impact=20; Priority="HIGH"; Description="Windows driver framework memory leak"; TemplateType="Memory"},
    @{Name="Non-Paged-Pool-Leak-Litssvc"; Systems=58; Impact=35; Priority="HIGH"; Description="Lenovo system service pool leak"; TemplateType="Memory"},
    @{Name="Paged-Pool-Leak-Litssvc"; Systems=55; Impact=30; Priority="HIGH"; Description="Lenovo system service paged pool leak"; TemplateType="Memory"},
    @{Name="Non-Paged-Pool-Leak-Wudfcompanionhost"; Systems=47; Impact=25; Priority="HIGH"; Description="Driver framework non-paged pool leak"; TemplateType="Memory"},
    
    # HIGH PRIORITY - Application Issues
    @{Name="PowerPivot-AddIn-Not-Loading"; Systems=383; Impact=34; Priority="HIGH"; Description="Excel PowerPivot add-in loading failures"; TemplateType="Application"},
    @{Name="Outlook-Skype-Addin-Disabled"; Systems=184; Impact=30; Priority="HIGH"; Description="Skype for Business Outlook add-in disabled"; TemplateType="Application"},
    @{Name="AddIns-Not-Loading-AccessAddin"; Systems=115; Impact=25; Priority="HIGH"; Description="Access database add-in loading failures"; TemplateType="Application"},
    @{Name="Critical-Application-Crash-Excel"; Systems=45; Impact=40; Priority="HIGH"; Description="Microsoft Excel critical crashes"; TemplateType="Application"},
    @{Name="Critical-Application-Hang-Outlook"; Systems=35; Impact=45; Priority="HIGH"; Description="Microsoft Outlook application hangs"; TemplateType="Application"},
    @{Name="Critical-Application-Crash-Teams"; Systems=25; Impact=35; Priority="HIGH"; Description="Microsoft Teams critical crashes"; TemplateType="Application"},
    @{Name="Critical-Application-Hang-Teams"; Systems=20; Impact=30; Priority="HIGH"; Description="Microsoft Teams application hangs"; TemplateType="Application"},
    
    # HIGH PRIORITY - Network & Connectivity
    @{Name="Default-Gateway-Latency-Corp"; Systems=317; Impact=28; Priority="HIGH"; Description="High latency to corporate gateway"; TemplateType="Network"},
    @{Name="Available-Bandwidth-Below-Limit"; Systems=188; Impact=35; Priority="HIGH"; Description="Network bandwidth below acceptable limits"; TemplateType="Network"},
    @{Name="High-Retransmission-Rate"; Systems=85; Impact=40; Priority="HIGH"; Description="High network packet retransmission rates"; TemplateType="Network"},
    @{Name="Default-Gateway-Latency-Impact"; Systems=65; Impact=30; Priority="HIGH"; Description="Gateway latency affecting performance"; TemplateType="Network"},
    @{Name="Unsecured-WiFi-Network"; Systems=55; Impact=60; Priority="HIGH"; Description="Connection to unsecured wireless networks"; TemplateType="Security"},
    @{Name="High-RDP-UDP-Latency"; Systems=45; Impact=35; Priority="HIGH"; Description="High Remote Desktop UDP latency"; TemplateType="Network"},
    @{Name="High-RDP-TCP-Latency"; Systems=35; Impact=30; Priority="HIGH"; Description="High Remote Desktop TCP latency"; TemplateType="Network"},
    @{Name="Global-Protect-VPN-Disconnected"; Systems=25; Impact=55; Priority="HIGH"; Description="GlobalProtect VPN connection failures"; TemplateType="Network"},
    @{Name="Frequent-Network-Disconnects"; Systems=45; Impact=45; Priority="HIGH"; Description="Frequent network connectivity interruptions"; TemplateType="Network"},
    @{Name="Network-Connection-Saturation"; Systems=15; Impact=70; Priority="HIGH"; Description="Network connection bandwidth saturation"; TemplateType="Network"},
    
    # HIGH PRIORITY - Group Policy & Security
    @{Name="GPO-Not-Refreshed-Registry"; Systems=256; Impact=40; Priority="HIGH"; Description="Group Policy registry refresh failures"; TemplateType="System"},
    @{Name="GPO-Not-Refreshed-Wireless"; Systems=64; Impact=35; Priority="HIGH"; Description="Wireless Group Policy refresh failures"; TemplateType="Network"},
    @{Name="GPO-Not-Refreshed-Scripts"; Systems=64; Impact=30; Priority="HIGH"; Description="Group Policy scripts refresh failures"; TemplateType="System"},
    @{Name="GPO-Not-Refreshed-802dot3"; Systems=62; Impact=25; Priority="HIGH"; Description="802.3 Group Policy refresh failures"; TemplateType="Network"},
    @{Name="Remote-Desktop-Logins-Disabled"; Systems=85; Impact=50; Priority="HIGH"; Description="Remote Desktop access disabled"; TemplateType="Security"},
    @{Name="FileVault-Off"; Systems=45; Impact=75; Priority="HIGH"; Description="macOS FileVault encryption disabled"; TemplateType="Security"},
    @{Name="Firewall-Status-Issues"; Systems=35; Impact=65; Priority="HIGH"; Description="Windows Firewall configuration issues"; TemplateType="Security"},
    @{Name="Windows-Defender-Firewall-Disabled-Private"; Systems=25; Impact=70; Priority="HIGH"; Description="Windows Defender Firewall disabled for private networks"; TemplateType="Security"},
    @{Name="Windows-Defender-Firewall-Disabled-Public"; Systems=15; Impact=80; Priority="HIGH"; Description="Windows Defender Firewall disabled for public networks"; TemplateType="Security"},
    @{Name="InTune-Compliance-Issue"; Systems=55; Impact=45; Priority="HIGH"; Description="Microsoft Intune compliance policy violations"; TemplateType="Security"}
)

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

function Invoke-TriggerGeneration {
    param([array]$Triggers)
    
    $successCount = 0
    $errorCount = 0
    $generatorScript = Join-Path $PSScriptRoot "Generate-TriggerScripts.ps1"
    
    if (-not (Test-Path $generatorScript)) {
        Write-Log "ERROR: Generator script not found: $generatorScript" -Level "ERROR"
        return
    }
    
    foreach ($trigger in $Triggers) {
        try {
            Write-Log "Generating scripts for: $($trigger.Name)"
            
            $params = @{
                TriggerName = $trigger.Name
                SystemsAffected = $trigger.Systems
                ImpactPercentage = $trigger.Impact
                Priority = $trigger.Priority
                Description = $trigger.Description
                TemplateType = $trigger.TemplateType
                OutputPath = $OutputPath
            }
            
            & $generatorScript @params
            
            if ($LASTEXITCODE -eq 0) {
                Write-Log "Successfully generated: $($trigger.Name)" -Level "SUCCESS"
                $successCount++
            } else {
                Write-Log "Failed to generate: $($trigger.Name)" -Level "ERROR"
                $errorCount++
            }
        }
        catch {
            Write-Log "Error generating $($trigger.Name): $($_.Exception.Message)" -Level "ERROR"
            $errorCount++
        }
    }
    
    Write-Log "=== GENERATION SUMMARY ===" -Level "SUCCESS"
    Write-Log "Successfully Generated: $successCount"
    Write-Log "Errors: $errorCount"
    Write-Log "Total Triggers: $($successCount + $errorCount)"
}

# Main execution
try {
    Write-Log "Starting High-Impact Trigger Generation"
    Write-Log "Output Path: $OutputPath"
    
    $triggersToGenerate = @()
    
    if ($GenerateAll) {
        $triggersToGenerate = $HighImpactTriggers
        Write-Log "Generating ALL high-impact triggers ($($HighImpactTriggers.Count) triggers)"
    }
    elseif ($GenerateCritical) {
        $triggersToGenerate = $HighImpactTriggers | Where-Object { $_.Priority -eq "CRITICAL" }
        Write-Log "Generating CRITICAL priority triggers ($($triggersToGenerate.Count) triggers)"
    }
    elseif ($GenerateHigh) {
        $triggersToGenerate = $HighImpactTriggers | Where-Object { $_.Priority -eq "HIGH" }
        Write-Log "Generating HIGH priority triggers ($($triggersToGenerate.Count) triggers)"
    }
    else {
        # Default: Generate critical and high priority
        $triggersToGenerate = $HighImpactTriggers | Where-Object { $_.Priority -in @("CRITICAL", "HIGH") }
        Write-Log "Generating CRITICAL and HIGH priority triggers ($($triggersToGenerate.Count) triggers)"
    }
    
    if ($triggersToGenerate.Count -eq 0) {
        Write-Log "No triggers selected for generation" -Level "WARN"
        exit 1
    }
    
    # Display summary before generation
    Write-Log "=== GENERATION PLAN ===" -Level "SUCCESS"
    $priorityGroups = $triggersToGenerate | Group-Object Priority
    foreach ($group in $priorityGroups) {
        Write-Log "$($group.Name): $($group.Count) triggers"
    }
    
    $templateGroups = $triggersToGenerate | Group-Object TemplateType
    foreach ($group in $templateGroups) {
        Write-Log "$($group.Name) Templates: $($group.Count) triggers"
    }
    
    Write-Log "Starting generation process..."
    Invoke-TriggerGeneration -Triggers $triggersToGenerate
    
    Write-Log "=== HIGH-IMPACT TRIGGER GENERATION COMPLETE ===" -Level "SUCCESS"
    Write-Log "Generated scripts are ready for customization and testing"
    Write-Log "Next steps:"
    Write-Log "1. Review and customize generated scripts"
    Write-Log "2. Test in lab environment"
    Write-Log "3. Deploy to pilot systems"
    Write-Log "4. Monitor effectiveness and tune"
    
    exit 0
}
catch {
    Write-Log "FATAL ERROR: $($_.Exception.Message)" -Level "ERROR"
    Write-Log "Stack Trace: $($_.ScriptStackTrace)" -Level "ERROR"
    exit 1
}
