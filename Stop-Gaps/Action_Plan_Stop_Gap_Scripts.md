# Stop-Gap Scripts Action Plan
# Complete automation coverage for SysTrack deployment gaps
# Created: July 1, 2025

## OVERVIEW
Total Automations: 75
Files per Automation: 3 (Detect, Remediate, FollowUp)
Total Files to Create: 225

## PROGRESS TRACKING

### ✅ COMPLETED (Detection, Remediation, Follow-up):
1. M365_Office365_Repair ✓✓✓

### 🔄 IN PROGRESS:
2. M365_OneDrive_Reset ✓ (Detect only)

### 📋 REMAINING (73 automations):

#### **PHASE I PRIORITY (Critical - Do First):**

**M365 Applications (4 remaining):**
- M365_OneDrive_Reset (in progress)
- M365_Teams_ClearCache
- M365_Excel_EnableAllMacros  
- M365_Office_ClearCachedCredentials

**Browser Management (4 - May already be working):**
- Browser_Chrome_ClearCache
- Browser_Chrome_ClearCacheAndCookies
- Browser_Edge_ClearCache
- Browser_Edge_ClearCacheAndCookies

**Core Windows Services (9):**
- Windows_Defender_RestartService
- Windows_GPO_UpdateComputer
- Windows_GPO_UpdateFull
- Windows_GPO_UpdateUser
- Windows_DNS_FixCache
- Windows_DNSClient_RestartService
- Windows_Netlogon_RestartService
- Windows_PrinterSpooler_RestartService
- Windows_TaskScheduler_RestartService

**System Maintenance (1):**
- Windows_Disk_CleanupFiles

**SCCM Management (15):**
- SCCM_Client_AppDeployEvalCycle
- SCCM_Client_ClearCache
- SCCM_Client_DiscoveryDataCollectionCycle
- SCCM_Client_FileCollectionCycle
- SCCM_Client_HardwareInventoryCycle
- SCCM_Client_MachinePolicyEvaluationCycle
- SCCM_Client_MachinePolicyRetrievalCycle
- SCCM_Client_RepairAgent
- SCCM_Client_RestartAgent
- SCCM_Client_SetSite
- SCCM_Client_SftwrMeteringRptCycle
- SCCM_Client_SftwrUpdateAssgnmtEval
- SCCM_Client_SoftwareInventoryCycle
- SCCM_Client_SoftwareUpdateScanCycle
- SCCM_Client_StateMessageRefresh
- SCCM_Client_UserPolicyEvaluationCycle
- SCCM_Client_UserPolicyRetrievalCycle
- SCCM_Client_WindowsSrcListUpdate

#### **PHASE II PRIORITY (Secondary):**

**M365 Advanced (6):**
- M365_Outlook_EnableSearch
- M365_PowerPoint_EndableAllMacros
- M365_PowerPoint_EndableDeveloperTools
- M365_PowerPoint_EndableSignedMacros
- M365_Word_EnableAllMacros
- M365_Word_EnableDevloperTools
- M365_Word_EnableSignedMacros

**Security Services (6):**
- Windows_Bitlocker_EnableService
- Windows_Defender_EnableFirewallService
- Windows_Defender_RestartFirewallService
- Windows_Update_RestartService
- Windows_CrowdStrikeFalcon_EnableService
- Windows_CrowdStrikeFalcon_RestartService

**System Services (20):**
- Windows_Computer_Restart
- Windows_Cryptographic_RestartService
- Windows_DCOM_RestartService
- Windows_Defender_ScanFull
- Windows_DefenderATP_RestartService
- Windows_DefenderNIS_EnableService
- Windows_DefenderNIS_RestartService
- Windows_DHCP_RestartService
- Windows_EventBroker_RestartService
- Windows_EventLog_RestartService
- Windows_LANManager_RestartService
- Windows_NIC_RestartService
- Windows_NLA_RestartService
- Windows_PlugAndPlay_RestartService
- Windows_RPC_RestartService
- Windows_Server_RestartService
- Windows_TimeBroker_RestartService
- Windows_UserProfile_RestartService
- Windows_Search_RestartService
- Windows_ZoomSharing_RestartService
- Windows_Zscaler_RestartService
- Windows_ZscalerTunnel_RestartService

**System Tools (5):**
- Windows_Hardware_DefragDisk
- Windows_Logon_ReRunScript
- Windows_Update_ResetDownloadFolders
- Windows_System_CheckFile

**Diagnostics (5):**
- Windows_Hardware_Diagnostics
- Windows_Internet_Diagnostics
- Windows_Network_Diagnostics
- Windows_Printer_Diagnostics
- Windows_Update_Diagnostics

## COMPLETION STRATEGY

### Option 1: Complete in This Chat
- Continue creating all 225 files
- Systematic approach: Complete each automation fully before moving to next
- Pros: Everything done at once
- Cons: Very long chat, may hit limits

### Option 2: Batch Approach
- Create batches of 10-15 automations per chat session
- Focus on Phase I critical first
- Pros: More manageable, can refine as we go
- Cons: Multiple sessions needed

### Option 3: Template + Bulk Generation
- Create standardized templates for each type
- Generate scripts programmatically 
- Pros: Faster, consistent
- Cons: Less customization per automation

## RECOMMENDED APPROACH

**Immediate (This Chat):**
1. Complete top 10 Phase I critical automations (30 files)
2. Focus on M365 and core Windows services
3. Create detailed templates for replication

**Next Session:**
1. Complete remaining Phase I (SCCM focus)
2. Begin Phase II security services

**Following Sessions:**
1. Complete all Phase II automations
2. Testing and validation scripts
3. Integration with health tracking system

## FILE NAMING CONVENTION

For automation "AutomationName":
- `Detect_AutomationName.ps1` - Detection script
- `Remediate_AutomationName.ps1` - Remediation script  
- `FollowUp_AutomationName.ps1` - Follow-up validation script

## SCRIPT STRUCTURE TEMPLATE

Each script includes:
- Proper header with automation name
- Error handling and logging
- SysTrack-compatible output format
- Event log integration
- Appropriate exit codes
- Follow-up scheduling integration

## TESTING REQUIREMENTS

After creation:
1. Syntax validation for all PowerShell scripts
2. Test in lab environment
3. Validate SysTrack integration
4. Confirm health tracking integration
5. Performance testing

---
**Status: 1 of 75 automations complete (225 files total)**
**Recommendation: Continue with top 10 Phase I critical in this chat**