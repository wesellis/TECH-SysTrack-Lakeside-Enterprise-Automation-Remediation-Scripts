@{
    # Module manifest for SysTrack Enterprise Automation
    RootModule = 'SysTrackAutomation.psm1'
    ModuleVersion = '1.0.0'
    GUID = 'a1b2c3d4-e5f6-4789-a012-3456789abcde'
    Author = 'Wes Ellis'
    CompanyName = 'Enterprise IT Operations'
    Copyright = '(c) 2025 Wes Ellis. All rights reserved.'
    Description = 'PowerShell module for automating SysTrack/Lakeside Software operations including remediation, monitoring, and endpoint management.'

    # Minimum PowerShell version
    PowerShellVersion = '5.1'

    # Compatible PSEditions
    CompatiblePSEditions = @('Desktop', 'Core')

    # Functions to export
    FunctionsToExport = @(
        # Connection & Setup
        'Connect-SysTrack'
        'Disconnect-SysTrack'
        'Initialize-SysTrackAutomation'
        'Test-SysTrackConnection'

        # Data Collection
        'Get-SysTrackMetrics'
        'Get-SysTrackInventory'
        'Get-UserExperienceScore'
        'Get-SystemHealth'
        'Get-OutdatedSoftware'

        # Remediation - Performance
        'Fix-HighCPUUsage'
        'Fix-MemoryLeaks'
        'Fix-DiskPerformance'
        'Fix-SlowBootup'
        'Optimize-CPU'
        'Clear-Cache'

        # Remediation - Network
        'Fix-NetworkAdapters'
        'Fix-DNSResolution'
        'Repair-AnyConnectAdapter'
        'Test-NetworkConnectivity'
        'Reset-NetworkStack'
        'Update-DNSServers'

        # Remediation - Applications
        'Fix-OfficeApplications'
        'Fix-BrowserIssues'
        'Repair-Office365'
        'Clear-TeamsCache'
        'Repair-Chrome'
        'Fix-Outlook'

        # Remediation - System
        'Fix-WindowsUpdate'
        'Fix-AudioDevices'
        'Fix-PrinterIssues'
        'Fix-RegistryIssues'
        'Fix-CPUInterrupts'
        'Fix-AzureADPasswordExpiration'
        'Repair-SysTrackAgent'

        # Automation & Monitoring
        'Start-AutoRemediation'
        'Watch-SysTrackAlerts'
        'New-RemediationRule'
        'Get-RemediationHistory'
        'New-SysTrackDashboard'

        # Reporting
        'Generate-DashboardData'
        'Export-UserExperience'
        'Get-TrendAnalysis'
        'Create-ExecutiveReport'
        'Export-Compliance'
        'Send-RemediationReport'

        # Scheduled Tasks
        'Schedule-SysTrackTask'
        'Get-ScheduledRemediations'
        'Remove-ScheduledRemediation'

        # Integration
        'Send-ToServiceNow'
        'Send-TeamsNotification'
        'Send-EmailAlert'
    )

    # Cmdlets to export
    CmdletsToExport = @()

    # Variables to export
    VariablesToExport = @()

    # Aliases to export
    AliasesToExport = @(
        'Connect-ST'
        'Get-STMetrics'
        'Start-AutoFix'
        'Get-STHealth'
    )

    # Required modules
    RequiredModules = @()

    # Private data
    PrivateData = @{
        PSData = @{
            Tags = @(
                'SysTrack'
                'Lakeside'
                'Automation'
                'Remediation'
                'Monitoring'
                'IT-Operations'
                'Digital-Experience'
                'PowerShell'
                'Enterprise'
            )

            LicenseUri = 'https://github.com/wesellis/TECH-SysTrack-Lakeside-Enterprise-Automation-Remediation-Scripts/blob/master/LICENSE'
            ProjectUri = 'https://github.com/wesellis/TECH-SysTrack-Lakeside-Enterprise-Automation-Remediation-Scripts'
            ReleaseNotes = @'
Version 1.0.0 (October 2025)
- Initial release with 168 PowerShell scripts
- 16 core remediation scripts for common issues
- Performance, network, application, and system fixes
- Integration with SysTrack/Lakeside Software
- Automated monitoring and alerting
- Dashboard and reporting capabilities
- ServiceNow and Teams integration
- Scheduled task automation
'@
        }
    }
}
