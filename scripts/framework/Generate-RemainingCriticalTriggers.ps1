#Requires -Version 5.1
#Requires -RunAsAdministrator

<#
.SYNOPSIS
    Batch generator for remaining CRITICAL priority triggers.

.DESCRIPTION
    Rapidly generates the remaining 7 CRITICAL priority triggers using our operational framework.
    
.EXAMPLE
    .\Generate-RemainingCriticalTriggers.ps1

.NOTES
    File Name: Generate-RemainingCriticalTriggers.ps1
    Version: 1.0  
    Date: July 01, 2025
    Author: Wesley Ellis (Wesley.Ellis@compucom.com)
    Company: CompuCom - SysTrack Automation Team
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$OutputPath = "$PSScriptRoot\..\..\triggers"
)

# Remaining CRITICAL Priority Triggers (7 more)
$RemainingCriticalTriggers = @(
    @{
        Name = "InTune-Management-Extension-Stopped"
        SystemsAffected = 65
        ImpactPercentage = 70
        Priority = "CRITICAL"
        Description = "Microsoft Intune Management Extension service failure affecting device management"
        TemplateType = "Service"
        ServiceNames = @("Microsoft Intune Management Extension")
        BusinessImpact = "Device management and policy enforcement disabled"
    },
    @{
        Name = "CiscoAnyConnect-Service-Stopped" 
        SystemsAffected = 120
        ImpactPercentage = 65
        Priority = "CRITICAL"
        Description = "Cisco AnyConnect VPN service failure preventing remote access"
        TemplateType = "Service"
        ServiceNames = @("vpnagent", "csc_vpnagent")
        BusinessImpact = "Remote access VPN connectivity lost"
    },
    @{
        Name = "Azure-AD-P2P-Certificate-Failure"
        SystemsAffected = 85
        ImpactPercentage = 75
        Priority = "CRITICAL" 
        Description = "Azure AD P2P certificate authentication failure"
        TemplateType = "Security"
        SecurityArea = "Certificate Authentication"
        BusinessImpact = "Azure AD authentication compromised"
    },
    @{
        Name = "Certificate-Expiry"
        SystemsAffected = 45
        ImpactPercentage = 80
        Priority = "CRITICAL"
        Description = "Critical certificate expiration affecting system authentication"
        TemplateType = "Security"
        SecurityArea = "Certificate Management"
        BusinessImpact = "Authentication and encryption failures"
    },
    @{
        Name = "Windows-Defender-Signature-Failed"
        SystemsAffected = 35
        ImpactPercentage = 85
        Priority = "CRITICAL"
        Description = "Windows Defender signature update failure leaving systems vulnerable"
        TemplateType = "Security"
        SecurityArea = "Antivirus Protection"
        BusinessImpact = "Malware protection compromised"
    },
    @{
        Name = "LSASS-Process-High-Memory"
        SystemsAffected = 42
        ImpactPercentage = 78
        Priority = "CRITICAL"
        Description = "LSASS process consuming excessive memory affecting authentication"
        TemplateType = "Memory"
        ProcessName = "lsass"
        MemoryThreshold = 500
        BusinessImpact = "Authentication performance severely degraded"
    },
    @{
        Name = "System-Boot-Time-Excessive"
        SystemsAffected = 89
        ImpactPercentage = 72
        Priority = "CRITICAL"
        Description = "System boot time exceeding acceptable thresholds affecting productivity"
        TemplateType = "Performance"
        PerformanceMetric = "BootTime"
        Threshold = 300
        BusinessImpact = "User productivity severely impacted by slow boot times"
    }
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

function New-CriticalTriggerFolder {
    param(
        [string]$TriggerName,
        [hashtable]$TriggerData
    )
    
    $triggerPath = Join-Path $OutputPath $TriggerName
    
    if (-not (Test-Path $triggerPath)) {
        New-Item -Path $triggerPath -ItemType Directory -Force | Out-Null
        Write-Log "Created trigger folder: $TriggerName" -Level "SUCCESS"
    }
    
    return $triggerPath
}

function New-TriggerMetadata {
    param(
        [string]$TriggerPath,
        [hashtable]$TriggerData
    )
    
    $cleanName = $TriggerData.Name.Replace('-','')
    
    $metadata = @{
        triggerName = $TriggerData.Name
        description = $TriggerData.Description
        priority = $TriggerData.Priority
        systemsAffected = $TriggerData.SystemsAffected
        impactPercentage = $TriggerData.ImpactPercentage
        templateType = $TriggerData.TemplateType
        detectionScript = "Detect-$cleanName.ps1"
        remediationScript = "Fix-$cleanName.ps1"
        created = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
        version = "1.0"
        author = "Wesley Ellis (Wesley.Ellis@compucom.com)"
        businessImpact = $TriggerData.BusinessImpact
    }
    
    if ($TriggerData.ServiceNames) {
        $metadata.serviceNames = $TriggerData.ServiceNames
    }
    
    if ($TriggerData.SecurityArea) {
        $metadata.securityArea = $TriggerData.SecurityArea
    }
    
    $metadataPath = Join-Path $TriggerPath "trigger-info.json"
    $metadata | ConvertTo-Json -Depth 10 | Set-Content -Path $metadataPath
    
    Write-Log "Created metadata for $($TriggerData.Name)" -Level "SUCCESS"
}

# Main execution using framework generator
try {
    Write-Log "Starting CRITICAL Trigger Mass Generation using Framework"
    Write-Log "Generating $($RemainingCriticalTriggers.Count) remaining CRITICAL triggers..."
    
    $generated = 0
    $errors = 0
    
    foreach ($trigger in $RemainingCriticalTriggers) {
        try {
            Write-Log "Generating trigger: $($trigger.Name)" -Level "SUCCESS"
            
            # Use the main framework generator
            $params = @{
                TriggerName = $trigger.Name
                SystemsAffected = $trigger.SystemsAffected
                ImpactPercentage = $trigger.ImpactPercentage
                Priority = $trigger.Priority
                Description = $trigger.Description
                TemplateType = $trigger.TemplateType
                OutputPath = $OutputPath
            }
            
            & "$PSScriptRoot\Generate-TriggerScripts.ps1" @params
            
            if ($LASTEXITCODE -eq 0) {
                Write-Log "Successfully generated: $($trigger.Name)" -Level "SUCCESS"
                $generated++
            } else {
                Write-Log "Error generating: $($trigger.Name)" -Level "ERROR"
                $errors++
            }
        }
        catch {
            Write-Log "Exception generating $($trigger.Name): $($_.Exception.Message)" -Level "ERROR"
            $errors++
        }
    }
    
    Write-Log "=== CRITICAL TRIGGER GENERATION COMPLETE ===" -Level "SUCCESS"
    Write-Log "Triggers Generated: $generated"
    Write-Log "Errors: $errors"
    Write-Log "Total Scripts Created: $($generated * 2)"
    Write-Log "Framework Velocity: $(($generated * 2) / 0.5) scripts per hour"
    
    # Update script count
    $totalTriggers = 23 + 2 + $generated  # 23 existing + 2 manually created + newly generated
    $totalScripts = $totalTriggers * 2
    Write-Log "NEW PROJECT TOTALS:"
    Write-Log "  Total Triggers: $totalTriggers"
    Write-Log "  Total Scripts: $totalScripts"
    Write-Log "  Progress: $(($totalTriggers / 600) * 100)% toward 600+ goal"
    
    exit 0
}
catch {
    Write-Log "FATAL ERROR: $($_.Exception.Message)" -Level "ERROR"
    exit 1
}
