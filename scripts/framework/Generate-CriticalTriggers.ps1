#Requires -Version 5.1
#Requires -RunAsAdministrator

<#
.SYNOPSIS
    Mass generator for CRITICAL priority triggers.

.DESCRIPTION
    Batch generates all 9 CRITICAL priority triggers using the operational framework
    for immediate deployment. These triggers have the highest business impact.

.EXAMPLE
    .\Generate-CriticalTriggers.ps1

.NOTES
    File Name: Generate-CriticalTriggers.ps1
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

# CRITICAL Priority Trigger Definitions
$CriticalTriggers = @(
    @{
        Name = "Netlogon-Service-Stopped"
        SystemsAffected = 25
        ImpactPercentage = 90
        Priority = "CRITICAL"
        Description = "Netlogon service failure preventing domain authentication"
        TemplateType = "Service"
    },
    @{
        Name = "Qualys-Cloud-Agent-Stopped"
        SystemsAffected = 25
        ImpactPercentage = 88
        Priority = "CRITICAL"
        Description = "Qualys Cloud Agent service failure affecting security scanning"
        TemplateType = "Service"
    },
    @{
        Name = "InTune-Management-Extension-Stopped"
        SystemsAffected = 65
        ImpactPercentage = 70
        Priority = "CRITICAL"
        Description = "Microsoft Intune Management Extension service failure"
        TemplateType = "Service"
    },
    @{
        Name = "CiscoAnyConnect-Service-Stopped"
        SystemsAffected = 120
        ImpactPercentage = 65
        Priority = "CRITICAL"
        Description = "Cisco AnyConnect VPN service failure preventing remote access"
        TemplateType = "Service"
    },
    @{
        Name = "Azure-AD-P2P-Certificate-Failure"
        SystemsAffected = 85
        ImpactPercentage = 75
        Priority = "CRITICAL"
        Description = "Azure AD P2P certificate authentication failure"
        TemplateType = "Security"
    },
    @{
        Name = "Certificate-Expiry"
        SystemsAffected = 45
        ImpactPercentage = 80
        Priority = "CRITICAL"
        Description = "Critical certificate expiration affecting system authentication"
        TemplateType = "Security"
    },
    @{
        Name = "Windows-Defender-Signature-Failed"
        SystemsAffected = 35
        ImpactPercentage = 85
        Priority = "CRITICAL"
        Description = "Windows Defender signature update failure"
        TemplateType = "Security"
    },
    @{
        Name = "LSASS-Process-High-Memory"
        SystemsAffected = 42
        ImpactPercentage = 78
        Priority = "CRITICAL"
        Description = "LSASS process consuming excessive memory"
        TemplateType = "Memory"
    },
    @{
        Name = "System-Boot-Time-Excessive"
        SystemsAffected = 89
        ImpactPercentage = 72
        Priority = "CRITICAL"
        Description = "System boot time exceeding acceptable thresholds"
        TemplateType = "Performance"
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

try {
    Write-Log "Starting CRITICAL Trigger Generation Session"
    Write-Log "Generating $($CriticalTriggers.Count) CRITICAL priority triggers"
    
    $generated = 0
    $errors = 0
    
    foreach ($trigger in $CriticalTriggers) {
        try {
            Write-Log "Generating trigger: $($trigger.Name)"
            
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
    
    exit 0
}
catch {
    Write-Log "FATAL ERROR: $($_.Exception.Message)" -Level "ERROR"
    exit 1
}
