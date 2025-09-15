# Stop-Gap Scripts Complete Action Plan
# Comprehensive automation coverage for SysTrack deployment gaps
# Created: July 1, 2025

## PROJECT OVERVIEW

**Objective**: Create detection, remediation, and follow-up PowerShell scripts for all 75 missing SysTrack automations

**Structure**: Each automation gets its own folder with 3 standardized scripts
- `Detect_[AutomationName].ps1` - Issue detection and validation
- `Remediate_[AutomationName].ps1` - Automated remediation execution  
- `FollowUp_[AutomationName].ps1` - Post-remediation validation and tracking

**Base Location**: `A:\GITHUB\TECH-SysTrack-Lakeside-Enterprise-Automation-Remediation-Scripts\Stop-Gaps\`

## FOLDER STRUCTURE AND FILE LOCATIONS

### PHASE I PRIORITY AUTOMATIONS (33 Automations)

#### M365 Applications (5 Automations)

**1. M365_Office365_Repair**
- Folder: `A:\GITHUB\TECH-SysTrack-Lakeside-Enterprise-Automation-Remediation-Scripts\Stop-Gaps\M365_Office365_Repair\`
- Files:
  - `Detect_M365_Office365_Repair.ps1`
  - `Remediate_M365_Office365_Repair.ps1`
  - `FollowUp_M365_Office365_Repair.ps1`
- Status: COMPLETED

**2. M365_OneDrive_Reset**
- Folder: `A:\GITHUB\TECH-SysTrack-Lakeside-Enterprise-Automation-Remediation-Scripts\Stop-Gaps\M365_OneDrive_Reset\`
- Files:
  - `Detect_M365_OneDrive_Reset.ps1`
  - `Remediate_M365_OneDrive_Reset.ps1`
  - `FollowUp_M365_OneDrive_Reset.ps1`
- Status: COMPLETED

**3. M365_Teams_ClearCache**
- Folder: `A:\GITHUB\TECH-SysTrack-Lakeside-Enterprise-Automation-Remediation-Scripts\Stop-Gaps\M365_Teams_ClearCache\`
- Files:
  - `Detect_M365_Teams_ClearCache.ps1`
  - `Remediate_M365_Teams_ClearCache.ps1`
  - `FollowUp_M365_Teams_ClearCache.ps1`
- Status: COMPLETED

**4. M365_Excel_EnableAllMacros**
- Folder: `A:\GITHUB\TECH-SysTrack-Lakeside-Enterprise-Automation-Remediation-Scripts\Stop-Gaps\M365_Excel_EnableAllMacros\`
- Files:
  - `Detect_M365_Excel_EnableAllMacros.ps1`
  - `Remediate_M365_Excel_EnableAllMacros.ps1`
  - `FollowUp_M365_Excel_EnableAllMacros.ps1`
- Status: COMPLETED

**5. M365_Office_ClearCachedCredentials**
- Folder: `A:\GITHUB\TECH-SysTrack-Lakeside-Enterprise-Automation-Remediation-Scripts\Stop-Gaps\M365_Office_ClearCachedCredentials\`
- Files:
  - `Detect_M365_Office_ClearCachedCredentials.ps1`
  - `Remediate_M365_Office_ClearCachedCredentials.ps1`
  - `FollowUp_M365_Office_ClearCachedCredentials.ps1`
- Status: COMPLETED

#### Browser Management (4 Automations)

**6. Browser_Chrome_ClearCache**
- Folder: `A:\GITHUB\TECH-SysTrack-Lakeside-Enterprise-Automation-Remediation-Scripts\Stop-Gaps\Browser_Chrome_ClearCache\`
- Files:
  - `Detect_Browser_Chrome_ClearCache.ps1`
  - `Remediate_Browser_Chrome_ClearCache.ps1`
  - `FollowUp_Browser_Chrome_ClearCache.ps1`
- Status: COMPLETED

**7. Browser_Chrome_ClearCacheAndCookies**
- Folder: `A:\GITHUB\TECH-SysTrack-Lakeside-Enterprise-Automation-Remediation-Scripts\Stop-Gaps\Browser_Chrome_ClearCacheAndCookies\`
- Files:
  - `Detect_Browser_Chrome_ClearCacheAndCookies.ps1`
  - `Remediate_Browser_Chrome_ClearCacheAndCookies.ps1`
  - `FollowUp_Browser_Chrome_ClearCacheAndCookies.ps1`
- Status: COMPLETED

**8. Browser_Edge_ClearCache**
- Folder: `A:\GITHUB\TECH-SysTrack-Lakeside-Enterprise-Automation-Remediation-Scripts\Stop-Gaps\Browser_Edge_ClearCache\`
- Files:
  - `Detect_Browser_Edge_ClearCache.ps1`
  - `Remediate_Browser_Edge_ClearCache.ps1`
  - `FollowUp_Browser_Edge_ClearCache.ps1`
- Status: COMPLETED

**9. Browser_Edge_ClearCacheAndCookies**
- Folder: `A:\GITHUB\TECH-SysTrack-Lakeside-Enterprise-Automation-Remediation-Scripts\Stop-Gaps\Browser_Edge_ClearCacheAndCookies\`
- Files:
  - `Detect_Browser_Edge_ClearCacheAndCookies.ps1`
  - `Remediate_Browser_Edge_ClearCacheAndCookies.ps1`
  - `FollowUp_Browser_Edge_ClearCacheAndCookies.ps1`
- Status: COMPLETED

#### Core Windows Services (9 Automations)

**10. Windows_Defender_RestartService**
- Folder: `A:\GITHUB\TECH-SysTrack-Lakeside-Enterprise-Automation-Remediation-Scripts\Stop-Gaps\Windows_Defender_RestartService\`
- Files:
  - `Detect_Windows_Defender_RestartService.ps1`
  - `Remediate_Windows_Defender_RestartService.ps1`
  - `FollowUp_Windows_Defender_RestartService.ps1`
- Status: COMPLETED

**11. Windows_GPO_UpdateComputer**
- Folder: `A:\GITHUB\TECH-SysTrack-Lakeside-Enterprise-Automation-Remediation-Scripts\Stop-Gaps\Windows_GPO_UpdateComputer\`
- Files:
  - `Detect_Windows_GPO_UpdateComputer.ps1`
  - `Remediate_Windows_GPO_UpdateComputer.ps1`
  - `FollowUp_Windows_GPO_UpdateComputer.ps1`
- Status: COMPLETED

**12. Windows_GPO_UpdateFull**
- Folder: `A:\GITHUB\TECH-SysTrack-Lakeside-Enterprise-Automation-Remediation-Scripts\Stop-Gaps\Windows_GPO_UpdateFull\`
- Files:
  - `Detect_Windows_GPO_UpdateFull.ps1`
  - `Remediate_Windows_GPO_UpdateFull.ps1`
  - `FollowUp_Windows_GPO_UpdateFull.ps1`
- Status: COMPLETED

**13. Windows_GPO_UpdateUser**
- Folder: `A:\GITHUB\TECH-SysTrack-Lakeside-Enterprise-Automation-Remediation-Scripts\Stop-Gaps\Windows_GPO_UpdateUser\`
- Files:
  - `Detect_Windows_GPO_UpdateUser.ps1`
  - `Remediate_Windows_GPO_UpdateUser.ps1`
  - `FollowUp_Windows_GPO_UpdateUser.ps1`

**14. Windows_DNS_FixCache**
- Folder: `A:\GITHUB\TECH-SysTrack-Lakeside-Enterprise-Automation-Remediation-Scripts\Stop-Gaps\Windows_DNS_FixCache\`
- Files:
  - `Detect_Windows_DNS_FixCache.ps1`
  - `Remediate_Windows_DNS_FixCache.ps1`
  - `FollowUp_Windows_DNS_FixCache.ps1`
- Status: COMPLETED

**15. Windows_DNSClient_RestartService**
- Folder: `A:\GITHUB\TECH-SysTrack-Lakeside-Enterprise-Automation-Remediation-Scripts\Stop-Gaps\Windows_DNSClient_RestartService\`
- Files:
  - `Detect_Windows_DNSClient_RestartService.ps1`
  - `Remediate_Windows_DNSClient_RestartService.ps1`
  - `FollowUp_Windows_DNSClient_RestartService.ps1`
- Status: COMPLETED

**16. Windows_Netlogon_RestartService**
- Folder: `A:\GITHUB\TECH-SysTrack-Lakeside-Enterprise-Automation-Remediation-Scripts\Stop-Gaps\Windows_Netlogon_RestartService\`
- Files:
  - `Detect_Windows_Netlogon_RestartService.ps1`
  - `Remediate_Windows_Netlogon_RestartService.ps1`
  - `FollowUp_Windows_Netlogon_RestartService.ps1`

**17. Windows_PrinterSpooler_RestartService**
- Folder: `A:\GITHUB\TECH-SysTrack-Lakeside-Enterprise-Automation-Remediation-Scripts\Stop-Gaps\Windows_PrinterSpooler_RestartService\`
- Files:
  - `Detect_Windows_PrinterSpooler_RestartService.ps1`
  - `Remediate_Windows_PrinterSpooler_RestartService.ps1`
  - `FollowUp_Windows_PrinterSpooler_RestartService.ps1`
- Status: COMPLETED

**18. Windows_TaskScheduler_RestartService**
- Folder: `A:\GITHUB\TECH-SysTrack-Lakeside-Enterprise-Automation-Remediation-Scripts\Stop-Gaps\Windows_TaskScheduler_RestartService\`
- Files:
  - `Detect_Windows_TaskScheduler_RestartService.ps1`
  - `Remediate_Windows_TaskScheduler_RestartService.ps1`
  - `FollowUp_Windows_TaskScheduler_RestartService.ps1`
- Status: COMPLETED

#### System Maintenance (1 Automation)

**19. Windows_Disk_CleanupFiles**
- Folder: `A:\GITHUB\TECH-SysTrack-Lakeside-Enterprise-Automation-Remediation-Scripts\Stop-Gaps\Windows_Disk_CleanupFiles\`
- Files:
  - `Detect_Windows_Disk_CleanupFiles.ps1`
  - `Remediate_Windows_Disk_CleanupFiles.ps1`
  - `FollowUp_Windows_Disk_CleanupFiles.ps1`

#### SCCM Management (15 Automations)

**20. SCCM_Client_AppDeployEvalCycle**
- Folder: `A:\GITHUB\TECH-SysTrack-Lakeside-Enterprise-Automation-Remediation-Scripts\Stop-Gaps\SCCM_Client_AppDeployEvalCycle\`
- Files:
  - `Detect_SCCM_Client_AppDeployEvalCycle.ps1`
  - `Remediate_SCCM_Client_AppDeployEvalCycle.ps1`
  - `FollowUp_SCCM_Client_AppDeployEvalCycle.ps1`

**21. SCCM_Client_ClearCache**
- Folder: `A:\GITHUB\TECH-SysTrack-Lakeside-Enterprise-Automation-Remediation-Scripts\Stop-Gaps\SCCM_Client_ClearCache\`
- Files:
  - `Detect_SCCM_Client_ClearCache.ps1`
  - `Remediate_SCCM_Client_ClearCache.ps1`
  - `FollowUp_SCCM_Client_ClearCache.ps1`

**22. SCCM_Client_DiscoveryDataCollectionCycle**
- Folder: `A:\GITHUB\TECH-SysTrack-Lakeside-Enterprise-Automation-Remediation-Scripts\Stop-Gaps\SCCM_Client_DiscoveryDataCollectionCycle\`
- Files:
  - `Detect_SCCM_Client_DiscoveryDataCollectionCycle.ps1`
  - `Remediate_SCCM_Client_DiscoveryDataCollectionCycle.ps1`
  - `FollowUp_SCCM_Client_DiscoveryDataCollectionCycle.ps1`

**23. SCCM_Client_FileCollectionCycle**
- Folder: `A:\GITHUB\TECH-SysTrack-Lakeside-Enterprise-Automation-Remediation-Scripts\Stop-Gaps\SCCM_Client_FileCollectionCycle\`
- Files:
  - `Detect_SCCM_Client_FileCollectionCycle.ps1`
  - `Remediate_SCCM_Client_FileCollectionCycle.ps1`
  - `FollowUp_SCCM_Client_FileCollectionCycle.ps1`

**24. SCCM_Client_HardwareInventoryCycle**
- Folder: `A:\GITHUB\TECH-SysTrack-Lakeside-Enterprise-Automation-Remediation-Scripts\Stop-Gaps\SCCM_Client_HardwareInventoryCycle\`
- Files:
  - `Detect_SCCM_Client_HardwareInventoryCycle.ps1`
  - `Remediate_SCCM_Client_HardwareInventoryCycle.ps1`
  - `FollowUp_SCCM_Client_HardwareInventoryCycle.ps1`

**25. SCCM_Client_MachinePolicyEvaluationCycle**
- Folder: `A:\GITHUB\TECH-SysTrack-Lakeside-Enterprise-Automation-Remediation-Scripts\Stop-Gaps\SCCM_Client_MachinePolicyEvaluationCycle\`
- Files:
  - `Detect_SCCM_Client_MachinePolicyEvaluationCycle.ps1`
  - `Remediate_SCCM_Client_MachinePolicyEvaluationCycle.ps1`
  - `FollowUp_SCCM_Client_MachinePolicyEvaluationCycle.ps1`

**26. SCCM_Client_MachinePolicyRetrievalCycle**
- Folder: `A:\GITHUB\TECH-SysTrack-Lakeside-Enterprise-Automation-Remediation-Scripts\Stop-Gaps\SCCM_Client_MachinePolicyRetrievalCycle\`
- Files:
  - `Detect_SCCM_Client_MachinePolicyRetrievalCycle.ps1`
  - `Remediate_SCCM_Client_MachinePolicyRetrievalCycle.ps1`
  - `FollowUp_SCCM_Client_MachinePolicyRetrievalCycle.ps1`

**27. SCCM_Client_RepairAgent**
- Folder: `A:\GITHUB\TECH-SysTrack-Lakeside-Enterprise-Automation-Remediation-Scripts\Stop-Gaps\SCCM_Client_RepairAgent\`
- Files:
  - `Detect_SCCM_Client_RepairAgent.ps1`
  - `Remediate_SCCM_Client_RepairAgent.ps1`
  - `FollowUp_SCCM_Client_RepairAgent.ps1`

**28. SCCM_Client_RestartAgent**
- Folder: `A:\GITHUB\TECH-SysTrack-Lakeside-Enterprise-Automation-Remediation-Scripts\Stop-Gaps\SCCM_Client_RestartAgent\`
- Files:
  - `Detect_SCCM_Client_RestartAgent.ps1`
  - `Remediate_SCCM_Client_RestartAgent.ps1`
  - `FollowUp_SCCM_Client_RestartAgent.ps1`
- Status: COMPLETED

**29. SCCM_Client_SetSite**
- Folder: `A:\GITHUB\TECH-SysTrack-Lakeside-Enterprise-Automation-Remediation-Scripts\Stop-Gaps\SCCM_Client_SetSite\`
- Files:
  - `Detect_SCCM_Client_SetSite.ps1`
  - `Remediate_SCCM_Client_SetSite.ps1`
  - `FollowUp_SCCM_Client_SetSite.ps1`

**30. SCCM_Client_SftwrMeteringRptCycle**
- Folder: `A:\GITHUB\TECH-SysTrack-Lakeside-Enterprise-Automation-Remediation-Scripts\Stop-Gaps\SCCM_Client_SftwrMeteringRptCycle\`
- Files:
  - `Detect_SCCM_Client_SftwrMeteringRptCycle.ps1`
  - `Remediate_SCCM_Client_SftwrMeteringRptCycle.ps1`
  - `FollowUp_SCCM_Client_SftwrMeteringRptCycle.ps1`

**31. SCCM_Client_SftwrUpdateAssgnmtEval**
- Folder: `A:\GITHUB\TECH-SysTrack-Lakeside-Enterprise-Automation-Remediation-Scripts\Stop-Gaps\SCCM_Client_SftwrUpdateAssgnmtEval\`
- Files:
  - `Detect_SCCM_Client_SftwrUpdateAssgnmtEval.ps1`
  - `Remediate_SCCM_Client_SftwrUpdateAssgnmtEval.ps1`
  - `FollowUp_SCCM_Client_SftwrUpdateAssgnmtEval.ps1`

**32. SCCM_Client_SoftwareInventoryCycle**
- Folder: `A:\GITHUB\TECH-SysTrack-Lakeside-Enterprise-Automation-Remediation-Scripts\Stop-Gaps\SCCM_Client_SoftwareInventoryCycle\`
- Files:
  - `Detect_SCCM_Client_SoftwareInventoryCycle.ps1`
  - `Remediate_SCCM_Client_SoftwareInventoryCycle.ps1`
  - `FollowUp_SCCM_Client_SoftwareInventoryCycle.ps1`

**33. SCCM_Client_SoftwareUpdateScanCycle**
- Folder: `A:\GITHUB\TECH-SysTrack-Lakeside-Enterprise-Automation-Remediation-Scripts\Stop-Gaps\SCCM_Client_SoftwareUpdateScanCycle\`
- Files:
  - `Detect_SCCM_Client_SoftwareUpdateScanCycle.ps1`
  - `Remediate_SCCM_Client_SoftwareUpdateScanCycle.ps1`
  - `FollowUp_SCCM_Client_SoftwareUpdateScanCycle.ps1`

**34. SCCM_Client_StateMessageRefresh**
- Folder: `A:\GITHUB\TECH-SysTrack-Lakeside-Enterprise-Automation-Remediation-Scripts\Stop-Gaps\SCCM_Client_StateMessageRefresh\`
- Files:
  - `Detect_SCCM_Client_StateMessageRefresh.ps1`
  - `Remediate_SCCM_Client_StateMessageRefresh.ps1`
  - `FollowUp_SCCM_Client_StateMessageRefresh.ps1`

**35. SCCM_Client_UserPolicyEvaluationCycle**
- Folder: `A:\GITHUB\TECH-SysTrack-Lakeside-Enterprise-Automation-Remediation-Scripts\Stop-Gaps\SCCM_Client_UserPolicyEvaluationCycle\`
- Files:
  - `Detect_SCCM_Client_UserPolicyEvaluationCycle.ps1`
  - `Remediate_SCCM_Client_UserPolicyEvaluationCycle.ps1`
  - `FollowUp_SCCM_Client_UserPolicyEvaluationCycle.ps1`

**36. SCCM_Client_UserPolicyRetrievalCycle**
- Folder: `A:\GITHUB\TECH-SysTrack-Lakeside-Enterprise-Automation-Remediation-Scripts\Stop-Gaps\SCCM_Client_UserPolicyRetrievalCycle\`
- Files:
  - `Detect_SCCM_Client_UserPolicyRetrievalCycle.ps1`
  - `Remediate_SCCM_Client_UserPolicyRetrievalCycle.ps1`
  - `FollowUp_SCCM_Client_UserPolicyRetrievalCycle.ps1`

**37. SCCM_Client_WindowsSrcListUpdate**
- Folder: `A:\GITHUB\TECH-SysTrack-Lakeside-Enterprise-Automation-Remediation-Scripts\Stop-Gaps\SCCM_Client_WindowsSrcListUpdate\`
- Files:
  - `Detect_SCCM_Client_WindowsSrcListUpdate.ps1`
  - `Remediate_SCCM_Client_WindowsSrcListUpdate.ps1`
  - `FollowUp_SCCM_Client_WindowsSrcListUpdate.ps1`

### PHASE II PRIORITY AUTOMATIONS (42 Automations)

#### M365 Advanced Features (6 Automations)

**38. M365_Outlook_EnableSearch**
- Folder: `A:\GITHUB\TECH-SysTrack-Lakeside-Enterprise-Automation-Remediation-Scripts\Stop-Gaps\M365_Outlook_EnableSearch\`
- Files:
  - `Detect_M365_Outlook_EnableSearch.ps1`
  - `Remediate_M365_Outlook_EnableSearch.ps1`
  - `FollowUp_M365_Outlook_EnableSearch.ps1`

**39. M365_PowerPoint_EndableAllMacros**
- Folder: `A:\GITHUB\TECH-SysTrack-Lakeside-Enterprise-Automation-Remediation-Scripts\Stop-Gaps\M365_PowerPoint_EndableAllMacros\`
- Files:
  - `Detect_M365_PowerPoint_EndableAllMacros.ps1`
  - `Remediate_M365_PowerPoint_EndableAllMacros.ps1`
  - `FollowUp_M365_PowerPoint_EndableAllMacros.ps1`

**40. M365_PowerPoint_EndableDeveloperTools**
- Folder: `A:\GITHUB\TECH-SysTrack-Lakeside-Enterprise-Automation-Remediation-Scripts\Stop-Gaps\M365_PowerPoint_EndableDeveloperTools\`
- Files:
  - `Detect_M365_PowerPoint_EndableDeveloperTools.ps1`
  - `Remediate_M365_PowerPoint_EndableDeveloperTools.ps1`
  - `FollowUp_M365_PowerPoint_EndableDeveloperTools.ps1`

**41. M365_PowerPoint_EndableSignedMacros**
- Folder: `A:\GITHUB\TECH-SysTrack-Lakeside-Enterprise-Automation-Remediation-Scripts\Stop-Gaps\M365_PowerPoint_EndableSignedMacros\`
- Files:
  - `Detect_M365_PowerPoint_EndableSignedMacros.ps1`
  - `Remediate_M365_PowerPoint_EndableSignedMacros.ps1`
  - `FollowUp_M365_PowerPoint_EndableSignedMacros.ps1`

**42. M365_Word_EnableAllMacros**
- Folder: `A:\GITHUB\TECH-SysTrack-Lakeside-Enterprise-Automation-Remediation-Scripts\Stop-Gaps\M365_Word_EnableAllMacros\`
- Files:
  - `Detect_M365_Word_EnableAllMacros.ps1`
  - `Remediate_M365_Word_EnableAllMacros.ps1`
  - `FollowUp_M365_Word_EnableAllMacros.ps1`

**43. M365_Word_EnableDevloperTools**
- Folder: `A:\GITHUB\TECH-SysTrack-Lakeside-Enterprise-Automation-Remediation-Scripts\Stop-Gaps\M365_Word_EnableDevloperTools\`
- Files:
  - `Detect_M365_Word_EnableDevloperTools.ps1`
  - `Remediate_M365_Word_EnableDevloperTools.ps1`
  - `FollowUp_M365_Word_EnableDevloperTools.ps1`

**44. M365_Word_EnableSignedMacros**
- Folder: `A:\GITHUB\TECH-SysTrack-Lakeside-Enterprise-Automation-Remediation-Scripts\Stop-Gaps\M365_Word_EnableSignedMacros\`
- Files:
  - `Detect_M365_Word_EnableSignedMacros.ps1`
  - `Remediate_M365_Word_EnableSignedMacros.ps1`
  - `FollowUp_M365_Word_EnableSignedMacros.ps1`

#### Security Services (6 Automations)

**45. Windows_Bitlocker_EnableService**
- Folder: `A:\GITHUB\TECH-SysTrack-Lakeside-Enterprise-Automation-Remediation-Scripts\Stop-Gaps\Windows_Bitlocker_EnableService\`
- Files:
  - `Detect_Windows_Bitlocker_EnableService.ps1`
  - `Remediate_Windows_Bitlocker_EnableService.ps1`
  - `FollowUp_Windows_Bitlocker_EnableService.ps1`

**46. Windows_Defender_EnableFirewallService**
- Folder: `A:\GITHUB\TECH-SysTrack-Lakeside-Enterprise-Automation-Remediation-Scripts\Stop-Gaps\Windows_Defender_EnableFirewallService\`
- Files:
  - `Detect_Windows_Defender_EnableFirewallService.ps1`
  - `Remediate_Windows_Defender_EnableFirewallService.ps1`
  - `FollowUp_Windows_Defender_EnableFirewallService.ps1`

**47. Windows_Defender_RestartFirewallService**
- Folder: `A:\GITHUB\TECH-SysTrack-Lakeside-Enterprise-Automation-Remediation-Scripts\Stop-Gaps\Windows_Defender_RestartFirewallService\`
- Files:
  - `Detect_Windows_Defender_RestartFirewallService.ps1`
  - `Remediate_Windows_Defender_RestartFirewallService.ps1`
  - `FollowUp_Windows_Defender_RestartFirewallService.ps1`

**48. Windows_Update_RestartService**
- Folder: `A:\GITHUB\TECH-SysTrack-Lakeside-Enterprise-Automation-Remediation-Scripts\Stop-Gaps\Windows_Update_RestartService\`
- Files:
  - `Detect_Windows_Update_RestartService.ps1`
  - `Remediate_Windows_Update_RestartService.ps1`
  - `FollowUp_Windows_Update_RestartService.ps1`

**49. Windows_CrowdStrikeFalcon_EnableService**
- Folder: `A:\GITHUB\TECH-SysTrack-Lakeside-Enterprise-Automation-Remediation-Scripts\Stop-Gaps\Windows_CrowdStrikeFalcon_EnableService\`
- Files:
  - `Detect_Windows_CrowdStrikeFalcon_EnableService.ps1`
  - `Remediate_Windows_CrowdStrikeFalcon_EnableService.ps1`
  - `FollowUp_Windows_CrowdStrikeFalcon_EnableService.ps1`

**50. Windows_CrowdStrikeFalcon_RestartService**
- Folder: `A:\GITHUB\TECH-SysTrack-Lakeside-Enterprise-Automation-Remediation-Scripts\Stop-Gaps\Windows_CrowdStrikeFalcon_RestartService\`
- Files:
  - `Detect_Windows_CrowdStrikeFalcon_RestartService.ps1`
  - `Remediate_Windows_CrowdStrikeFalcon_RestartService.ps1`
  - `FollowUp_Windows_CrowdStrikeFalcon_RestartService.ps1`

#### System Services (25 Automations)

**51. Windows_Computer_Restart**
- Folder: `A:\GITHUB\TECH-SysTrack-Lakeside-Enterprise-Automation-Remediation-Scripts\Stop-Gaps\Windows_Computer_Restart\`
- Files:
  - `Detect_Windows_Computer_Restart.ps1`
  - `Remediate_Windows_Computer_Restart.ps1`
  - `FollowUp_Windows_Computer_Restart.ps1`

**52. Windows_Cryptographic_RestartService**
- Folder: `A:\GITHUB\TECH-SysTrack-Lakeside-Enterprise-Automation-Remediation-Scripts\Stop-Gaps\Windows_Cryptographic_RestartService\`
- Files:
  - `Detect_Windows_Cryptographic_RestartService.ps1`
  - `Remediate_Windows_Cryptographic_RestartService.ps1`
  - `FollowUp_Windows_Cryptographic_RestartService.ps1`

**53. Windows_DCOM_RestartService**
- Folder: `A:\GITHUB\TECH-SysTrack-Lakeside-Enterprise-Automation-Remediation-Scripts\Stop-Gaps\Windows_DCOM_RestartService\`
- Files:
  - `Detect_Windows_DCOM_RestartService.ps1`
  - `Remediate_Windows_DCOM_RestartService.ps1`
  - `FollowUp_Windows_DCOM_RestartService.ps1`

**54. Windows_Defender_ScanFull**
- Folder: `A:\GITHUB\TECH-SysTrack-Lakeside-Enterprise-Automation-Remediation-Scripts\Stop-Gaps\Windows_Defender_ScanFull\`
- Files:
  - `Detect_Windows_Defender_ScanFull.ps1`
  - `Remediate_Windows_Defender_ScanFull.ps1`
  - `FollowUp_Windows_Defender_ScanFull.ps1`

**55. Windows_DefenderATP_RestartService**
- Folder: `A:\GITHUB\TECH-SysTrack-Lakeside-Enterprise-Automation-Remediation-Scripts\Stop-Gaps\Windows_DefenderATP_RestartService\`
- Files:
  - `Detect_Windows_DefenderATP_RestartService.ps1`
  - `Remediate_Windows_DefenderATP_RestartService.ps1`
  - `FollowUp_Windows_DefenderATP_RestartService.ps1`

**56. Windows_DefenderNIS_EnableService**
- Folder: `A:\GITHUB\TECH-SysTrack-Lakeside-Enterprise-Automation-Remediation-Scripts\Stop-Gaps\Windows_DefenderNIS_EnableService\`
- Files:
  - `Detect_Windows_DefenderNIS_EnableService.ps1`
  - `Remediate_Windows_DefenderNIS_EnableService.ps1`
  - `FollowUp_Windows_DefenderNIS_EnableService.ps1`

**57. Windows_DefenderNIS_RestartService**
- Folder: `A:\GITHUB\TECH-SysTrack-Lakeside-Enterprise-Automation-Remediation-Scripts\Stop-Gaps\Windows_DefenderNIS_RestartService\`
- Files:
  - `Detect_Windows_DefenderNIS_RestartService.ps1`
  - `Remediate_Windows_DefenderNIS_RestartService.ps1`
  - `FollowUp_Windows_DefenderNIS_RestartService.ps1`

**58. Windows_DHCP_RestartService**
- Folder: `A:\GITHUB\TECH-SysTrack-Lakeside-Enterprise-Automation-Remediation-Scripts\Stop-Gaps\Windows_DHCP_RestartService\`
- Files:
  - `Detect_Windows_DHCP_RestartService.ps1`
  - `Remediate_Windows_DHCP_RestartService.ps1`
  - `FollowUp_Windows_DHCP_RestartService.ps1`

**59. Windows_EventBroker_RestartService**
- Folder: `A:\GITHUB\TECH-SysTrack-Lakeside-Enterprise-Automation-Remediation-Scripts\Stop-Gaps\Windows_EventBroker_RestartService\`
- Files:
  - `Detect_Windows_EventBroker_RestartService.ps1`
  - `Remediate_Windows_EventBroker_RestartService.ps1`
  - `FollowUp_Windows_EventBroker_RestartService.ps1`

**60. Windows_EventLog_RestartService**
- Folder: `A:\GITHUB\TECH-SysTrack-Lakeside-Enterprise-Automation-Remediation-Scripts\Stop-Gaps\Windows_EventLog_RestartService\`
- Files:
  - `Detect_Windows_EventLog_RestartService.ps1`
  - `Remediate_Windows_EventLog_RestartService.ps1`
  - `FollowUp_Windows_EventLog_RestartService.ps1`

**61. Windows_LANManager_RestartService**
- Folder: `A:\GITHUB\TECH-SysTrack-Lakeside-Enterprise-Automation-Remediation-Scripts\Stop-Gaps\Windows_LANManager_RestartService\`
- Files:
  - `Detect_Windows_LANManager_RestartService.ps1`
  - `Remediate_Windows_LANManager_RestartService.ps1`
  - `FollowUp_Windows_LANManager_RestartService.ps1`

**62. Windows_NIC_RestartService**
- Folder: `A:\GITHUB\TECH-SysTrack-Lakeside-Enterprise-Automation-Remediation-Scripts\Stop-Gaps\Windows_NIC_RestartService\`
- Files:
  - `Detect_Windows_NIC_RestartService.ps1`
  - `Remediate_Windows_NIC_RestartService.ps1`
  - `FollowUp_Windows_NIC_RestartService.ps1`

**63. Windows_NLA_RestartService**
- Folder: `A:\GITHUB\TECH-SysTrack-Lakeside-Enterprise-Automation-Remediation-Scripts\Stop-Gaps\Windows_NLA_RestartService\`
- Files:
  - `Detect_Windows_NLA_RestartService.ps1`
  - `Remediate_Windows_NLA_RestartService.ps1`
  - `FollowUp_Windows_NLA_RestartService.ps1`

**64. Windows_PlugAndPlay_RestartService**
- Folder: `A:\GITHUB\TECH-SysTrack-Lakeside-Enterprise-Automation-Remediation-Scripts\Stop-Gaps\Windows_PlugAndPlay_RestartService\`
- Files:
  - `Detect_Windows_PlugAndPlay_RestartService.ps1`
  - `Remediate_Windows_PlugAndPlay_RestartService.ps1`
  - `FollowUp_Windows_PlugAndPlay_RestartService.ps1`

**65. Windows_RPC_RestartService**
- Folder: `A:\GITHUB\TECH-SysTrack-Lakeside-Enterprise-Automation-Remediation-Scripts\Stop-Gaps\Windows_RPC_RestartService\`
- Files:
  - `Detect_Windows_RPC_RestartService.ps1`
  - `Remediate_Windows_RPC_RestartService.ps1`
  - `FollowUp_Windows_RPC_RestartService.ps1`

**66. Windows_Server_RestartService**
- Folder: `A:\GITHUB\TECH-SysTrack-Lakeside-Enterprise-Automation-Remediation-Scripts\Stop-Gaps\Windows_Server_RestartService\`
- Files:
  - `Detect_Windows_Server_RestartService.ps1`
  - `Remediate_Windows_Server_RestartService.ps1`
  - `FollowUp_Windows_Server_RestartService.ps1`

**67. Windows_TimeBroker_RestartService**
- Folder: `A:\GITHUB\TECH-SysTrack-Lakeside-Enterprise-Automation-Remediation-Scripts\Stop-Gaps\Windows_TimeBroker_RestartService\`
- Files:
  - `Detect_Windows_TimeBroker_RestartService.ps1`
  - `Remediate_Windows_TimeBroker_RestartService.ps1`
  - `FollowUp_Windows_TimeBroker_RestartService.ps1`

**68. Windows_UserProfile_RestartService**
- Folder: `A:\GITHUB\TECH-SysTrack-Lakeside-Enterprise-Automation-Remediation-Scripts\Stop-Gaps\Windows_UserProfile_RestartService\`
- Files:
  - `Detect_Windows_UserProfile_RestartService.ps1`
  - `Remediate_Windows_UserProfile_RestartService.ps1`
  - `FollowUp_Windows_UserProfile_RestartService.ps1`

**69. Windows_Search_RestartService**
- Folder: `A:\GITHUB\TECH-SysTrack-Lakeside-Enterprise-Automation-Remediation-Scripts\Stop-Gaps\Windows_Search_RestartService\`
- Files:
  - `Detect_Windows_Search_RestartService.ps1`
  - `Remediate_Windows_Search_RestartService.ps1`
  - `FollowUp_Windows_Search_RestartService.ps1`

**70. Windows_ZoomSharing_RestartService**
- Folder: `A:\GITHUB\TECH-SysTrack-Lakeside-Enterprise-Automation-Remediation-Scripts\Stop-Gaps\Windows_ZoomSharing_RestartService\`
- Files:
  - `Detect_Windows_ZoomSharing_RestartService.ps1`
  - `Remediate_Windows_ZoomSharing_RestartService.ps1`
  - `FollowUp_Windows_ZoomSharing_RestartService.ps1`

**71. Windows_Zscaler_RestartService**
- Folder: `A:\GITHUB\TECH-SysTrack-Lakeside-Enterprise-Automation-Remediation-Scripts\Stop-Gaps\Windows_Zscaler_RestartService\`
- Files:
  - `Detect_Windows_Zscaler_RestartService.ps1`
  - `Remediate_Windows_Zscaler_RestartService.ps1`
  - `FollowUp_Windows_Zscaler_RestartService.ps1`

**72. Windows_ZscalerTunnel_RestartService**
- Folder: `A:\GITHUB\TECH-SysTrack-Lakeside-Enterprise-Automation-Remediation-Scripts\Stop-Gaps\Windows_ZscalerTunnel_RestartService\`
- Files:
  - `Detect_Windows_ZscalerTunnel_RestartService.ps1`
  - `Remediate_Windows_ZscalerTunnel_RestartService.ps1`
  - `FollowUp_Windows_ZscalerTunnel_RestartService.ps1`

#### System Tools (5 Automations)

**73. Windows_Hardware_DefragDisk**
- Folder: `A:\GITHUB\TECH-SysTrack-Lakeside-Enterprise-Automation-Remediation-Scripts\Stop-Gaps\Windows_Hardware_DefragDisk\`
- Files:
  - `Detect_Windows_Hardware_DefragDisk.ps1`
  - `Remediate_Windows_Hardware_DefragDisk.ps1`
  - `FollowUp_Windows_Hardware_DefragDisk.ps1`

**74. Windows_Logon_ReRunScript**
- Folder: `A:\GITHUB\TECH-SysTrack-Lakeside-Enterprise-Automation-Remediation-Scripts\Stop-Gaps\Windows_Logon_ReRunScript\`
- Files:
  - `Detect_Windows_Logon_ReRunScript.ps1`
  - `Remediate_Windows_Logon_ReRunScript.ps1`
  - `FollowUp_Windows_Logon_ReRunScript.ps1`

**75. Windows_Update_ResetDownloadFolders**
- Folder: `A:\GITHUB\TECH-SysTrack-Lakeside-Enterprise-Automation-Remediation-Scripts\Stop-Gaps\Windows_Update_ResetDownloadFolders\`
- Files:
  - `Detect_Windows_Update_ResetDownloadFolders.ps1`
  - `Remediate_Windows_Update_ResetDownloadFolders.ps1`
  - `FollowUp_Windows_Update_ResetDownloadFolders.ps1`

**76. Windows_System_CheckFile**
- Folder: `A:\GITHUB\TECH-SysTrack-Lakeside-Enterprise-Automation-Remediation-Scripts\Stop-Gaps\Windows_System_CheckFile\`
- Files:
  - `Detect_Windows_System_CheckFile.ps1`
  - `Remediate_Windows_System_CheckFile.ps1`
  - `FollowUp_Windows_System_CheckFile.ps1`

#### Diagnostics (5 Automations)

**77. Windows_Hardware_Diagnostics**
- Folder: `A:\GITHUB\TECH-SysTrack-Lakeside-Enterprise-Automation-Remediation-Scripts\Stop-Gaps\Windows_Hardware_Diagnostics\`
- Files:
  - `Detect_Windows_Hardware_Diagnostics.ps1`
  - `Remediate_Windows_Hardware_Diagnostics.ps1`
  - `FollowUp_Windows_Hardware_Diagnostics.ps1`

**78. Windows_Internet_Diagnostics**
- Folder: `A:\GITHUB\TECH-SysTrack-Lakeside-Enterprise-Automation-Remediation-Scripts\Stop-Gaps\Windows_Internet_Diagnostics\`
- Files:
  - `Detect_Windows_Internet_Diagnostics.ps1`
  - `Remediate_Windows_Internet_Diagnostics.ps1`
  - `FollowUp_Windows_Internet_Diagnostics.ps1`

**79. Windows_Network_Diagnostics**
- Folder: `A:\GITHUB\TECH-SysTrack-Lakeside-Enterprise-Automation-Remediation-Scripts\Stop-Gaps\Windows_Network_Diagnostics\`
- Files:
  - `Detect_Windows_Network_Diagnostics.ps1`
  - `Remediate_Windows_Network_Diagnostics.ps1`
  - `FollowUp_Windows_Network_Diagnostics.ps1`

**80. Windows_Printer_Diagnostics**
- Folder: `A:\GITHUB\TECH-SysTrack-Lakeside-Enterprise-Automation-Remediation-Scripts\Stop-Gaps\Windows_Printer_Diagnostics\`
- Files:
  - `Detect_Windows_Printer_Diagnostics.ps1`
  - `Remediate_Windows_Printer_Diagnostics.ps1`
  - `FollowUp_Windows_Printer_Diagnostics.ps1`

**81. Windows_Update_Diagnostics**
- Folder: `A:\GITHUB\TECH-SysTrack-Lakeside-Enterprise-Automation-Remediation-Scripts\Stop-Gaps\Windows_Update_Diagnostics\`
- Files:
  - `Detect_Windows_Update_Diagnostics.ps1`
  - `Remediate_Windows_Update_Diagnostics.ps1`
  - `FollowUp_Windows_Update_Diagnostics.ps1`

## SCRIPT SPECIFICATIONS

### File Standards
- **Language**: PowerShell 5.1 compatible
- **Encoding**: UTF-8 with BOM
- **Line Endings**: Windows (CRLF)
- **No Emojis**: Professional text only
- **Error Handling**: Comprehensive try-catch blocks
- **Logging**: Windows Event Log integration
- **Output Format**: SysTrack compatible structured output

### Detection Scripts (Detect_*.ps1)
**Purpose**: Identify if the automation action is needed
**Requirements**:
- Check current system state
- Identify specific issues requiring remediation
- Return boolean result for automation triggering
- Provide detailed issue description
- Log findings to Event Log
- Exit codes: 0 (no action needed), 1 (action required)

### Remediation Scripts (Remediate_*.ps1)
**Purpose**: Execute the automation action
**Requirements**:
- Perform the specific automation task
- Handle pre-conditions and dependencies
- Provide progress feedback
- Log all actions taken
- Return success/failure status
- Exit codes: 0 (success), 1 (failure), 2 (partial success)

### Follow-up Scripts (FollowUp_*.ps1)
**Purpose**: Validate remediation success and track health improvement
**Requirements**:
- Verify remediation resolved original issues
- Check for any new issues introduced
- Provide recommendations for further action
- Schedule re-checks if needed
- Integration with health clinic tracking
- Exit codes: 0 (success), 1 (failed validation), 2 (partial success)

## QUALITY REQUIREMENTS

### Code Standards
- Professional PowerShell coding standards
- Comprehensive error handling
- Detailed logging and event tracking
- Consistent parameter validation
- Clear function documentation
- No hardcoded paths where possible
- Environment variable usage
- Secure credential handling

### Testing Requirements
- Syntax validation for all scripts
- Functional testing in lab environment
- Integration testing with SysTrack
- Performance benchmarking
- Security review for privileged operations
- Documentation validation

### Integration Requirements
- SysTrack automation policy compatibility
- Health clinic loopback integration
- Event Log structured logging
- Follow-up scheduling coordination
- Escalation workflow integration

## COMPLETION TRACKING

**Total Project Scope**: 75 Automations × 3 Scripts = 225 Files
**Current Status**: 28 Complete, 0 In Progress, 47 Remaining
**Files Completed**: 87 of 225 (38.7%)
**Estimated Completion Time**: 22-32 hours development remaining
**Priority Completion**: Phase I (33 automations) = 99 files

**Recently Completed** (July 2, 2025):
- Windows_Defender_RestartService - COMPLETED (Session 1)
- M365_Office_ClearCachedCredentials - COMPLETED (Session 1)
- Browser_Chrome_ClearCache - COMPLETED (Session 1)
- Browser_Chrome_ClearCacheAndCookies - COMPLETED (Session 1)
- M365_OneDrive_Reset - COMPLETED (Session 1)
- M365_Teams_ClearCache - COMPLETED (Session 1)
- M365_Excel_EnableAllMacros - COMPLETED (Session 1)
- Browser_Edge_ClearCache - COMPLETED (Session 1)
- Browser_Edge_ClearCacheAndCookies - COMPLETED (Session 1)
- Windows_DNS_FixCache - COMPLETED (Session 2)
- Windows_DNSClient_RestartService - COMPLETED (Session 3)
- Windows_PrinterSpooler_RestartService - COMPLETED (Session 4)
- Windows_TaskScheduler_RestartService - COMPLETED (Session 5)
- Windows_GPO_UpdateComputer - COMPLETED (Session 6)
- Windows_GPO_UpdateFull - COMPLETED (Session 7)

**Current Status**: Core Windows Services group in progress (7 of 9 complete, 0 in progress)

## SUCCESS METRICS

### Phase I Completion Targets
- M365 productivity issues resolution: 95% automation success rate
- Core Windows service issues: 90% automation success rate
- SCCM management tasks: 85% automation success rate
- Browser performance issues: 98% automation success rate

### Phase II Completion Targets
- Advanced M365 features: 80% automation success rate
- Security service management: 95% automation success rate
- System service maintenance: 90% automation success rate
- Diagnostic tool execution: 85% automation success rate

### Overall Project Success
- Comprehensive automation coverage for 75 common IT issues
- Integration with existing health tracking system
- Reduced manual intervention by 70-80%
- Improved endpoint health scores through proactive automation
- Complete follow-up and validation framework

---
**Document Location**: `A:\GITHUB\TECH-SysTrack-Lakeside-Enterprise-Automation-Remediation-Scripts\Stop-Gaps\Complete_Action_Plan.md`
**Last Updated**: July 1, 2025
**Next Review**: After Phase I completion