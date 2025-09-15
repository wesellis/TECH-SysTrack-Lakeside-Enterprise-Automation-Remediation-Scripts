# Quick Start Guide

## Prerequisites

### System Requirements
- Windows 10/11 or Windows Server 2016+
- PowerShell 5.1 or PowerShell Core 7+
- SysTrack Lakeside Enterprise access
- Administrator privileges on target systems

### Required Modules
```powershell
# Install required PowerShell modules
Install-Module -Name Az -Force
Install-Module -Name Microsoft.Graph -Force
Install-Module -Name ActiveDirectory -Force
```

### API Access Required
- SysTrack Lakeside Enterprise API credentials
- Azure AD application registration (for Azure AD automation)
- SCCM access (for software deployment)

## Initial Setup

### 1. Clone Repository
```bash
git clone [repository-url]
cd TECH-SysTrack-Lakeside-Enterprise-Automation-Remediation-Scripts
```

### 2. Configure Environment
```powershell
# Copy configuration template
Copy-Item "config\templates\environment.template.json" "config\environments\production.json"

# Edit configuration file
notepad "config\environments\production.json"
```

### 3. Test Connectivity
```powershell
# Test SysTrack API connection
.\tools\test-systrack-connection.ps1

# Test Azure AD connection
.\tools\test-azuread-connection.ps1
```

## First Automation: SysTrack Agent Monitoring

### Why Start Here?
- **Foundation Requirement:** Other automations depend on SysTrack data
- **Low Risk:** Monitoring-focused, minimal system changes
- **High Value:** Prevents automation blind spots

### Quick Implementation
```powershell
# 1. Configure SysTrack agent monitoring
.\automation-engine\setup-agent-monitoring.ps1

# 2. Test agent health check
.\remediation-scripts\monitoring\test-agent-health.ps1

# 3. Enable automated restart
.\workflows\enable-agent-auto-restart.ps1
```

### Validation
```powershell
# Check monitoring status
.\tools\validate-automation-health.ps1 -Component "SysTrackAgent"
```

## Second Automation: CPU Interrupt Remediation

### High-Impact Quick Win
```powershell
# 1. Set up interrupt monitoring
.\automation-engine\setup-interrupt-monitoring.ps1

# 2. Configure thresholds (starts conservative)
.\config\set-interrupt-thresholds.ps1 -InterruptThreshold 15 -DurationMinutes 5

# 3. Enable automated response
.\workflows\enable-interrupt-remediation.ps1
```

## Monitoring Your Automation

### Real-Time Dashboard
```powershell
# Launch monitoring dashboard
.\reporting\launch-dashboard.ps1
```

### Daily Health Check
```powershell
# Generate daily automation report
.\reporting\generate-daily-report.ps1
```

### Success Metrics
- **Agent Uptime:** Target >99%
- **Issue Resolution Rate:** Target >80%
- **Mean Time to Resolution:** Target <5 minutes

## Getting Help

### Documentation
- [Full Setup Guide](setup/complete-setup.md)
- [Troubleshooting Guide](operations/troubleshooting.md)
- [Adding New Scripts](development/adding-scripts.md)

### Support Contacts
- **Technical Issues:** IT Automation Team
- **Security Questions:** Security Team
- **Business Impact:** Operations Team

### Emergency Procedures
- **Disable All Automation:** `.\tools\emergency-disable.ps1`
- **Rollback Last Change:** `.\tools\rollback-automation.ps1`
- **Emergency Escalation:** [Contact Information]

## Next Steps After Quick Start

1. **Week 1:** Monitor SysTrack Agent automation performance
2. **Week 2:** Add CPU Interrupt remediation
3. **Week 3:** Implement Cisco AnyConnect automation
4. **Month 1:** Add remaining high-priority automations

---

**Quick Start Checklist:**
- [ ] Prerequisites installed
- [ ] API connections tested
- [ ] SysTrack Agent monitoring enabled
- [ ] Dashboard accessible
- [ ] Emergency procedures understood
- [ ] Team notifications configured

**Estimated Setup Time:** 2-4 hours
**Support Available:** [Contact Information]
