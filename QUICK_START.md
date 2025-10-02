# 🚀 Quick Start Guide - SysTrack Enterprise Automation

Get SysTrack automation scripts running in under 10 minutes.

## Prerequisites

- **PowerShell 5.1+** (Windows) or **PowerShell 7+** (Cross-platform)
- **SysTrack/Lakeside Software** server access
- **Administrator privileges** on target machines
- **Git** for cloning the repository

## Option 1: Quick Start (Standalone Scripts)

Perfect for testing individual remediation scripts without full setup.

### 1. Clone Repository

```powershell
# Clone repository
git clone https://github.com/wesellis/TECH-SysTrack-Lakeside-Enterprise-Automation-Remediation-Scripts.git
cd TECH-SysTrack-Lakeside-Enterprise-Automation-Remediation-Scripts
```

### 2. Run Individual Scripts

```powershell
# Fix high CPU usage
.\scripts\completed\Fix-HighCPUUsage.ps1 -Threshold 90

# Clear browser cache
.\scripts\completed\Fix-BrowserIssues.ps1

# Repair network adapters
.\scripts\completed\Fix-NetworkAdapters.ps1

# Fix memory leaks
.\scripts\completed\Fix-MemoryLeaks.ps1

# Repair Office applications
.\scripts\completed\Fix-OfficeApplications.ps1
```

### 3. View Available Scripts

```powershell
# List all completed remediation scripts
Get-ChildItem .\scripts\completed\*.ps1

# List framework/automation scripts
Get-ChildItem .\scripts\framework\*.ps1
```

---

## Option 2: Full Module Setup (Recommended)

For integrated automation with SysTrack server and scheduled tasks.

### 1. Import PowerShell Module

```powershell
# Import the module
Import-Module .\SysTrackAutomation.psd1

# Verify module loaded
Get-Module SysTrackAutomation

# See available commands
Get-Command -Module SysTrackAutomation
```

### 2. Initialize Environment

```powershell
# Initialize automation environment
Initialize-SysTrackAutomation -CreateSampleConfig

# This creates:
# - Sample configuration files
# - Directory structure validation
# - Environment setup
```

### 3. Configure Connection

**Option A - Direct connection:**

```powershell
# Connect to SysTrack server
Connect-SysTrack -Server "https://systrack.company.com"

# Test connection
Test-SysTrackConnection
```

**Option B - Using configuration file:**

```powershell
# Edit configuration file
notepad .\config\environments\sample.json

# Update these values:
{
  "systrack": {
    "api_url": "https://your-systrack-server/api",
    "api_key": "YOUR_API_KEY_HERE"
  }
}

# Connect using config
Connect-SysTrack -ConfigFile ".\config\environments\sample.json"
```

### 4. Run Automation

```powershell
# Fix high CPU issues
Fix-HighCPUUsage -Threshold 85

# Repair network adapters
Fix-NetworkAdapters

# Fix memory leaks
Fix-MemoryLeaks

# Clear browser issues
Fix-BrowserIssues

# Repair Office apps
Fix-OfficeApplications
```

---

## Option 3: Scheduled Automation

Set up automated monitoring and remediation.

### 1. Create Remediation Rules

```powershell
# Auto-fix high CPU when detected
New-RemediationRule -Trigger "CPU > 90%" `
                   -Action "Fix-HighCPUUsage" `
                   -Notify "it-alerts@company.com"

# Auto-clear disk space when low
New-RemediationRule -Trigger "DiskSpace < 5%" `
                   -Action "Clear-TempFiles" `
                   -Notify "it-team@company.com"
```

### 2. Schedule Daily Health Checks

```powershell
# Schedule daily health check at 6 AM
Schedule-SysTrackTask -Script "HealthCheck.ps1" `
                     -Time "06:00" `
                     -Recurrence Daily

# Schedule weekly cleanup
Schedule-SysTrackTask -Script "WeeklyMaintenance.ps1" `
                     -DayOfWeek Monday `
                     -Time "02:00"
```

### 3. Monitor Alerts

```powershell
# Watch for SysTrack alerts and auto-remediate
Watch-SysTrackAlerts -Type "ServiceDown" -Action {
    Restart-Service $_.ServiceName -Force
    Send-EmailAlert -Message "Service restarted: $($_.ServiceName)"
}
```

---

## Configuration

### Environment Configuration

Edit `config/templates/environment.template.json`:

```json
{
  "environment": "production",
  "systrack": {
    "api_url": "https://systrack.company.com/api",
    "api_key": "YOUR_API_KEY_HERE",
    "polling_interval_seconds": 300
  },
  "azure_ad": {
    "tenant_id": "YOUR_TENANT_ID",
    "client_id": "YOUR_CLIENT_ID",
    "client_secret": "YOUR_CLIENT_SECRET"
  },
  "automation": {
    "enable_automatic_remediation": false,
    "max_concurrent_jobs": 5,
    "default_timeout_minutes": 30
  },
  "notifications": {
    "email_enabled": true,
    "teams_webhook": "YOUR_TEAMS_WEBHOOK_URL",
    "smtp_server": "smtp.company.com"
  },
  "thresholds": {
    "cpu_interrupt_warning": 10,
    "cpu_interrupt_critical": 15,
    "memory_leak_mb": 500,
    "response_time_seconds": 300
  }
}
```

### Threshold Configuration

Customize remediation thresholds:

| Setting | Default | Description |
|---------|---------|-------------|
| CPU Threshold | 90% | Trigger CPU remediation |
| Memory Threshold | 90% | Trigger memory cleanup |
| Disk Space | 5% | Trigger disk cleanup |
| Response Time | 300s | Max script timeout |

---

## Common Use Cases

### 1. Daily System Health Checks

```powershell
# Check all systems
Get-SystemHealth | Where-Object { $_.Status -ne "Healthy" }

# Get user experience scores
Get-UserExperienceScore -Department "Finance" |
    Where-Object { $_.Score -lt 70 }

# Export metrics
Get-SysTrackMetrics -Days 7 | Export-Csv "metrics.csv"
```

### 2. Mass Remediation

```powershell
# Get all systems needing remediation
$systems = Get-SystemHealth | Where-Object { $_.NeedsRemediation }

# Apply fixes to all
foreach ($system in $systems) {
    Invoke-RemediationScript -Computer $system.ComputerName -Type $system.IssueType
}
```

### 3. Integration with ServiceNow

```powershell
# Send alert to ServiceNow when issue detected
Watch-SysTrackAlerts -Action {
    Send-ToServiceNow -Alert $_ `
                     -Priority "High" `
                     -AssignmentGroup "Desktop Support"
}
```

### 4. Teams Notifications

```powershell
# Configure Teams webhook
$teamsWebhook = "https://outlook.office.com/webhook/..."

# Send notifications
Send-TeamsNotification -Webhook $teamsWebhook `
                      -Title "Remediation Complete" `
                      -Message "Fixed 15 systems with high CPU"
```

---

## Available Scripts

### Performance Remediation
- `Fix-HighCPUUsage.ps1` - Resolve high CPU issues
- `Fix-MemoryLeaks.ps1` - Detect and fix memory leaks
- `Fix-DiskPerformance.ps1` - Optimize disk performance
- `Fix-SlowBootup.ps1` - Speed up system boot
- `Fix-CPUInterrupts.ps1` - Fix interrupt storm issues

### Network Remediation
- `Fix-NetworkAdapters.ps1` - Repair network adapters
- `Fix-DNSResolution.ps1` - Fix DNS issues
- `Repair-AnyConnectAdapter.ps1` - Repair Cisco AnyConnect
- `Reset-NetworkStack.ps1` - Reset TCP/IP stack

### Application Remediation
- `Fix-OfficeApplications.ps1` - Repair Microsoft Office
- `Fix-BrowserIssues.ps1` - Fix browser problems
- `Clear-TeamsCache.ps1` - Clear Teams cache
- `Fix-Outlook.ps1` - Repair Outlook issues

### System Remediation
- `Fix-WindowsUpdate.ps1` - Repair Windows Update
- `Fix-AudioDevices.ps1` - Fix audio issues
- `Fix-PrinterIssues.ps1` - Repair printer problems
- `Fix-RegistryIssues.ps1` - Clean registry issues
- `Fix-AzureADPasswordExpiration.ps1` - Fix Azure AD auth

### Framework Scripts
- `Generate-TriggerScripts.ps1` - Auto-generate triggers
- `Generate-HighImpactTriggers.ps1` - Priority automation
- `Complete-Remaining-Critical-Triggers.ps1` - Finish setup

---

## Troubleshooting

### PowerShell Execution Policy

```powershell
# Check current policy
Get-ExecutionPolicy

# Set to allow scripts (run as Administrator)
Set-ExecutionPolicy RemoteSigned -Scope CurrentUser

# Or bypass for single session
powershell -ExecutionPolicy Bypass
```

### Module Import Errors

```powershell
# Remove and re-import module
Remove-Module SysTrackAutomation -ErrorAction SilentlyContinue
Import-Module .\SysTrackAutomation.psd1 -Force

# Check for errors
Import-Module .\SysTrackAutomation.psd1 -Verbose
```

### Connection Issues

```powershell
# Test server connectivity
Test-NetConnection systrack.company.com -Port 443

# Verify API endpoint
Invoke-RestMethod -Uri "https://systrack.company.com/api/health" -Method Get

# Check credentials
Test-SysTrackConnection
```

### Script Execution Fails

```powershell
# Run with elevated privileges
Start-Process powershell -Verb RunAs

# Enable verbose logging
$VerbosePreference = "Continue"
Fix-HighCPUUsage -Verbose

# Check error logs
Get-Content .\logs\error.log -Tail 50
```

---

## Security Best Practices

1. **Never commit credentials** - Use environment variables or secure vaults
2. **Test in non-production** - Always test scripts before production deployment
3. **Use RBAC** - Implement role-based access control
4. **Audit logging** - Enable logging for all automation actions
5. **Change control** - Follow your organization's change management process
6. **Secure webhooks** - Use HTTPS for all integrations
7. **Limit permissions** - Use minimum required privileges

---

## What's Next?

1. **Explore Scripts** - Browse `scripts/completed/` for all remediations
2. **Read Docs** - Check `docs/` for detailed guides
3. **Customize Config** - Tailor settings to your environment
4. **Schedule Tasks** - Set up automated maintenance
5. **Integrate Tools** - Connect ServiceNow, Teams, email alerts
6. **Monitor Results** - Track automation effectiveness

---

## Getting Help

- 📖 **Full Documentation** - See [README.md](README.md)
- 📧 **Email Support** - wes@wesellis.com
- 🐛 **Issues** - [GitHub Issues](https://github.com/wesellis/TECH-SysTrack-Lakeside-Enterprise-Automation-Remediation-Scripts/issues)
- 📚 **Analysis Docs** - Check `docs/` directory for detailed analysis

---

## Quick Reference

```powershell
# Import module
Import-Module .\SysTrackAutomation.psd1

# Initialize
Initialize-SysTrackAutomation -CreateSampleConfig

# Connect
Connect-SysTrack -Server "https://systrack.company.com"

# Run remediation
Fix-HighCPUUsage -Threshold 90
Fix-MemoryLeaks
Fix-NetworkAdapters

# Schedule automation
Schedule-SysTrackTask -Script "DailyHealthCheck.ps1" -Time "06:00" -Recurrence Daily

# Disconnect
Disconnect-SysTrack
```

---

**Pro Tip:** Start with Option 1 (standalone scripts) to test individual remediations, then move to Option 2 (full module) for integrated automation!
