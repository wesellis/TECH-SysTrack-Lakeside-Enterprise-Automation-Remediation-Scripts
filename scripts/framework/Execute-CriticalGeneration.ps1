
# Execute CRITICAL Trigger Generation
cd A:\GITHUB\TECH-SysTrack-Lakeside-Enterprise-Automation-Remediation-Scripts\scripts\framework

# Generate each CRITICAL trigger
Write-Host "Generating CRITICAL priority triggers..." -ForegroundColor Green

# 1. Netlogon Service Stopped
.\Generate-TriggerScripts.ps1 -TriggerName "Netlogon-Service-Stopped" -SystemsAffected 25 -ImpactPercentage 90 -Priority "CRITICAL" -Description "Netlogon service failure preventing domain authentication" -TemplateType "Service"

# 2. Qualys Cloud Agent Stopped
.\Generate-TriggerScripts.ps1 -TriggerName "Qualys-Cloud-Agent-Stopped" -SystemsAffected 25 -ImpactPercentage 88 -Priority "CRITICAL" -Description "Qualys Cloud Agent service failure affecting security scanning" -TemplateType "Service"

# 3. InTune Management Extension Stopped
.\Generate-TriggerScripts.ps1 -TriggerName "InTune-Management-Extension-Stopped" -SystemsAffected 65 -ImpactPercentage 70 -Priority "CRITICAL" -Description "Microsoft Intune Management Extension service failure" -TemplateType "Service"

# 4. Cisco AnyConnect Service Stopped
.\Generate-TriggerScripts.ps1 -TriggerName "CiscoAnyConnect-Service-Stopped" -SystemsAffected 120 -ImpactPercentage 65 -Priority "CRITICAL" -Description "Cisco AnyConnect VPN service failure preventing remote access" -TemplateType "Service"

# 5. Azure AD P2P Certificate Failure
.\Generate-TriggerScripts.ps1 -TriggerName "Azure-AD-P2P-Certificate-Failure" -SystemsAffected 85 -ImpactPercentage 75 -Priority "CRITICAL" -Description "Azure AD P2P certificate authentication failure" -TemplateType "Security"

# 6. Certificate Expiry
.\Generate-TriggerScripts.ps1 -TriggerName "Certificate-Expiry" -SystemsAffected 45 -ImpactPercentage 80 -Priority "CRITICAL" -Description "Critical certificate expiration affecting system authentication" -TemplateType "Security"

# 7. Windows Defender Signature Failed
.\Generate-TriggerScripts.ps1 -TriggerName "Windows-Defender-Signature-Failed" -SystemsAffected 35 -ImpactPercentage 85 -Priority "CRITICAL" -Description "Windows Defender signature update failure" -TemplateType "Security"

# 8. LSASS Process High Memory
.\Generate-TriggerScripts.ps1 -TriggerName "LSASS-Process-High-Memory" -SystemsAffected 42 -ImpactPercentage 78 -Priority "CRITICAL" -Description "LSASS process consuming excessive memory" -TemplateType "Memory"

# 9. System Boot Time Excessive
.\Generate-TriggerScripts.ps1 -TriggerName "System-Boot-Time-Excessive" -SystemsAffected 89 -ImpactPercentage 72 -Priority "CRITICAL" -Description "System boot time exceeding acceptable thresholds" -TemplateType "Performance"

Write-Host "CRITICAL trigger generation complete!" -ForegroundColor Green
