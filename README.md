# 🖥️ SysTrack Enterprise Automation & Remediation Scripts
### Lakeside Software Integration for IT Operations

[![PowerShell](https://img.shields.io/badge/PowerShell-7.0+-5391FE?style=for-the-badge&logo=powershell)](https://docs.microsoft.com/powershell/)
[![SysTrack](https://img.shields.io/badge/SysTrack-10.0+-00A4EF?style=for-the-badge)](https://www.lakesidesoftware.com)
[![License](https://img.shields.io/badge/License-MIT-green?style=for-the-badge)](LICENSE)

## 🎯 Overview

Collection of PowerShell scripts for automating SysTrack/Lakeside Software operations. Automate remediation, extract performance data, and manage endpoints at scale. Designed for IT teams using SysTrack for digital experience monitoring.

### 📊 What These Scripts Do

- **Automated Remediation** - Fix common issues automatically
- **Performance Monitoring** - Extract and analyze metrics
- **Endpoint Management** - Bulk operations on devices
- **Report Generation** - Custom reports from SysTrack data
- **Alert Integration** - Connect to ticketing systems
- **Health Checks** - Proactive system maintenance

## 💡 Key Scripts

### Remediation Scripts
```powershell
# Auto-fix high CPU usage
.\Remediate-HighCPU.ps1 -Threshold 90 -Action "RestartService"

# Clear disk space automatically
.\Clear-DiskSpace.ps1 -MinFreeGB 10 -DeleteTempFiles -ClearLogs

# Fix network connectivity
.\Repair-NetworkConnection.ps1 -ResetAdapter -FlushDNS
```

### Data Collection
```powershell
# Get performance metrics
Get-SysTrackMetrics -Computer $computerName -Days 7 |
    Export-Csv "performance.csv"

# Extract user experience scores
Get-UserExperienceScore -Department "Finance" |
    Where {$_.Score -lt 70}

# Collect system inventory
Get-SysTrackInventory | Export-Excel "inventory.xlsx"
```

### Automated Actions
```powershell
# Restart services based on SysTrack alerts
Watch-SysTrackAlerts -Type "ServiceDown" -Action {
    Restart-Service $_.ServiceName -Force
}

# Update software when outdated
Get-OutdatedSoftware | Update-SoftwarePackage -Silent

# Reboot systems with issues
Get-SystemsNeedingReboot | Restart-Computer -Wait
```

## ⚡ Quick Start

```powershell
# Import SysTrack module
Import-Module .\SysTrackAutomation.psd1

# Connect to SysTrack
Connect-SysTrack -Server "systrack.company.com" -Credential (Get-Credential)

# Run first remediation
Start-AutoRemediation -Scope "AllSystems"
```

## 🛠️ Script Categories

### Performance
- `Fix-HighMemory.ps1` - Memory leak remediation
- `Optimize-CPU.ps1` - CPU optimization
- `Clear-Cache.ps1` - Clear various caches
- `Defrag-Drives.ps1` - Disk defragmentation
- `Optimize-Services.ps1` - Service optimization

### Network
- `Test-Connectivity.ps1` - Network diagnostics
- `Reset-NetworkStack.ps1` - TCP/IP reset
- `Update-DNSServers.ps1` - DNS configuration
- `Fix-ProxySettings.ps1` - Proxy repairs
- `Optimize-Bandwidth.ps1` - Bandwidth management

### Applications
- `Repair-Office365.ps1` - Office repairs
- `Fix-Outlook.ps1` - Outlook issues
- `Clear-TeamsCache.ps1` - Teams optimization
- `Repair-Chrome.ps1` - Browser fixes
- `Reset-Applications.ps1` - App resets

### System Health
- `Run-HealthCheck.ps1` - System health audit
- `Update-Drivers.ps1` - Driver updates
- `Clean-Registry.ps1` - Registry cleanup
- `Fix-WindowsUpdate.ps1` - Update repairs
- `Optimize-Startup.ps1` - Boot optimization

### Reporting
- `Generate-DashboardData.ps1` - Dashboard metrics
- `Export-UserExperience.ps1` - UX reports
- `Get-TrendAnalysis.ps1` - Trend reports
- `Create-ExecutiveReport.ps1` - Executive summaries
- `Export-Compliance.ps1` - Compliance reports

## 📈 Features

### Alert-Based Automation
```powershell
# Configure auto-remediation rules
New-RemediationRule -Trigger "DiskSpace < 5%" `
                   -Action "Clear-TempFiles" `
                   -Notify "it-team@company.com"
```

### Scheduled Tasks
```powershell
# Schedule daily health checks
Schedule-SysTrackTask -Script "HealthCheck.ps1" `
                     -Time "06:00" `
                     -Recurrence Daily
```

### Integration Examples
```powershell
# ServiceNow integration
Send-ToServiceNow -Alert $sysTrackAlert `
                 -Priority "High" `
                 -AssignmentGroup "Desktop Support"

# Email notifications
Send-RemediationReport -Recipients "managers@company.com" `
                      -IncludeMetrics
```

## 🔧 Configuration

### Settings File
```json
{
  "SysTrackServer": "systrack.company.com",
  "Database": "SysTrack_DB",
  "RemediationEnabled": true,
  "ThresholdCPU": 85,
  "ThresholdMemory": 90,
  "ThresholdDisk": 10,
  "AutoRebootAllowed": false,
  "NotificationEmail": "it-alerts@company.com"
}
```

### Custom Remediation
```powershell
# Define custom remediation
function Invoke-CustomFix {
    param($Computer, $Issue)

    switch ($Issue.Type) {
        "AppCrash" { Repair-Application $Issue.AppName }
        "SlowLogin" { Optimize-UserProfile $Issue.UserName }
        "NetworkDrop" { Reset-NetworkAdapter }
    }
}
```

## 📊 Monitoring Dashboard

Scripts include dashboard generators:
```powershell
# Generate HTML dashboard
New-SysTrackDashboard -OutputPath "C:\Dashboards" `
                     -RefreshInterval 300 `
                     -Metrics @("CPU","Memory","Disk","Network")
```

## 🔒 Security

- **Credential Management** - Secure storage
- **Audit Logging** - All actions logged
- **RBAC** - Role-based permissions
- **Encrypted Connections** - Secure communications
- **Change Control** - Approval workflows

## 🐛 Troubleshooting

| Issue | Solution |
|-------|----------|
| Connection failed | Check SysTrack server accessibility |
| No data returned | Verify database permissions |
| Script timeout | Increase timeout values |
| Remediation failed | Check error logs in Event Viewer |

## 📚 Documentation

- [SysTrack API Reference](docs/api-reference.md)
- [Remediation Guide](docs/remediation-guide.md)
- [Best Practices](docs/best-practices.md)
- [Troubleshooting](docs/troubleshooting.md)

## 🤝 Contributing

Share your SysTrack automation scripts!

## 📜 License

MIT License - Free for all use

---

<div align="center">

**Automate IT Operations with SysTrack**

[![Download](https://img.shields.io/badge/Download-Scripts-brightgreen?style=for-the-badge)](https://github.com/yourusername/systrack-automation/releases)

*Free • Open Source • Production Ready*

</div>