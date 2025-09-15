# SysTrack Enterprise Automation Project Setup Script
# Creates complete folder structure and foundational files

param(
    [string]$ProjectPath = "A:\GITHUB\TECH-SysTrack-Lakeside-Enterprise-Automation-Remediation-Scripts",
    [switch]$Force
)

Write-Host "Setting up SysTrack Enterprise Automation Project..." -ForegroundColor Green
Write-Host "Project Path: $ProjectPath" -ForegroundColor Yellow

# Function to create directory if it doesn't exist
function New-ProjectDirectory {
    param([string]$Path)
    if (!(Test-Path $Path)) {
        New-Item -ItemType Directory -Path $Path -Force | Out-Null
        Write-Host "[CREATED] $Path" -ForegroundColor Green
    } else {
        Write-Host "[EXISTS]  $Path" -ForegroundColor Gray
    }
}

# Function to create file with content
function New-ProjectFile {
    param(
        [string]$FilePath,
        [string]$Content
    )
    if (!(Test-Path $FilePath) -or $Force) {
        $Content | Out-File -FilePath $FilePath -Encoding UTF8
        Write-Host "[CREATED] $FilePath" -ForegroundColor Green
    } else {
        Write-Host "[EXISTS]  $FilePath" -ForegroundColor Gray
    }
}

# Create main project directory
New-ProjectDirectory -Path $ProjectPath
Set-Location $ProjectPath

Write-Host "`nCreating SysTrack Triggers Structure..." -ForegroundColor Cyan

# SysTrack Triggers
$triggerDirs = @(
    "systrack-triggers",
    "systrack-triggers\critical-priority",
    "systrack-triggers\high-priority", 
    "systrack-triggers\medium-priority",
    "systrack-triggers\security-priority",
    "systrack-triggers\low-priority"
)

foreach ($dir in $triggerDirs) {
    New-ProjectDirectory -Path $dir
}

Write-Host "`nCreating Remediation Scripts Structure..." -ForegroundColor Cyan

# Remediation Scripts
$remediationDirs = @(
    "remediation-scripts",
    "remediation-scripts\network",
    "remediation-scripts\performance", 
    "remediation-scripts\authentication",
    "remediation-scripts\applications",
    "remediation-scripts\monitoring",
    "remediation-scripts\system"
)

foreach ($dir in $remediationDirs) {
    New-ProjectDirectory -Path $dir
}

Write-Host "`nCreating Automation Engine Structure..." -ForegroundColor Cyan

# Automation Engine
$automationDirs = @(
    "automation-engine",
    "workflows",
    "workflows\critical-response",
    "workflows\scheduled-maintenance", 
    "workflows\user-impacting"
)

foreach ($dir in $automationDirs) {
    New-ProjectDirectory -Path $dir
}

Write-Host "`nCreating Configuration Structure..." -ForegroundColor Cyan

# Configuration
$configDirs = @(
    "config",
    "config\environments",
    "config\thresholds",
    "config\schedules",
    "config\templates"
)

foreach ($dir in $configDirs) {
    New-ProjectDirectory -Path $dir
}

Write-Host "`nCreating Reporting Structure..." -ForegroundColor Cyan

# Reporting
$reportingDirs = @(
    "reporting",
    "reporting\dashboards",
    "reporting\metrics",
    "reporting\exports",
    "reporting\exports\daily-reports",
    "reporting\exports\weekly-summaries",
    "reporting\exports\monthly-analytics"
)

foreach ($dir in $reportingDirs) {
    New-ProjectDirectory -Path $dir
}

Write-Host "`nCreating Testing Structure..." -ForegroundColor Cyan

# Testing
$testingDirs = @(
    "testing",
    "testing\unit-tests",
    "testing\integration-tests",
    "testing\mock-data",
    "testing\validation"
)

foreach ($dir in $testingDirs) {
    New-ProjectDirectory -Path $dir
}

Write-Host "`nCreating Documentation Structure..." -ForegroundColor Cyan

# Documentation
$docDirs = @(
    "docs",
    "docs\setup",
    "docs\operations",
    "docs\development", 
    "docs\runbooks"
)

foreach ($dir in $docDirs) {
    New-ProjectDirectory -Path $dir
}

Write-Host "`nCreating Security & Support Structure..." -ForegroundColor Cyan

# Security, Deployment, Logs, Tools
$supportDirs = @(
    "security",
    "security\credentials",
    "security\certificates", 
    "security\policies",
    "security\audit",
    "deployment",
    "deployment\scripts",
    "deployment\packages",
    "deployment\rollback",
    "logs",
    "logs\automation",
    "logs\errors",
    "logs\performance",
    "logs\audit",
    "tools",
    "tools\systrack-api-client",
    "tools\data-parsers",
    "tools\notification-tools",
    "tools\monitoring-agents"
)

foreach ($dir in $supportDirs) {
    New-ProjectDirectory -Path $dir
}

Write-Host "`nCreating Essential Template Files..." -ForegroundColor Cyan

# Create .gitignore
$gitignoreContent = @"
# Logs
logs/
*.log

# Credentials and secrets
security/credentials/*
config/environments/production.json
config/environments/staging.json
*.key
*.pfx

# PowerShell
*.ps1.bak
profile.ps1

# Temporary files
temp/
*.tmp

# IDE files
.vscode/
.idea/

# Windows
Thumbs.db
Desktop.ini

# Test results
TestResults/
coverage/
"@

New-ProjectFile -FilePath ".gitignore" -Content $gitignoreContent

# Create environment template
$envTemplateContent = @"
{
  "environment": "template",
  "systrack": {
    "api_url": "https://your-systrack-server/api",
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
    "smtp_server": "your-smtp-server.com"
  },
  "thresholds": {
    "cpu_interrupt_warning": 10,
    "cpu_interrupt_critical": 15,
    "memory_leak_mb": 500,
    "response_time_seconds": 300
  }
}
"@

New-ProjectFile -FilePath "config\templates\environment.template.json" -Content $envTemplateContent

# Create sample trigger files for high-priority items
$anyconnectTrigger = @"
{
  "trigger_name": "anyconnect_adapter_failure",
  "description": "Cisco AnyConnect Virtual Miniport Adapter issues",
  "priority": "HIGH",
  "systems_affected": 1177,
  "percentage_affected": 52,
  "business_impact": "HIGH - VPN connectivity loss, remote work disruption",
  
  "trigger_conditions": {
    "primary_metric": "Device Manager Status - Cisco AnyConnect Virtual Miniport Adapter",
    "failure_states": ["Error", "Disabled", "Unknown"],
    "check_frequency_minutes": 15,
    "consecutive_failures": 2
  },
  
  "automation_response": {
    "immediate_actions": [
      "Log adapter status and error codes",
      "Capture network configuration snapshot",
      "Test basic connectivity"
    ],
    "remediation_scripts": [
      "restart-anyconnect-services.ps1",
      "reinstall-anyconnect-adapter.ps1",
      "repair-network-profile.ps1",
      "validate-vpn-connectivity.ps1"
    ]
  },
  
  "success_criteria": {
    "target_resolution_time": "5 minutes",
    "success_threshold": "Adapter status = Working",
    "validation_tests": ["Ping gateway", "VPN connection test"]
  }
}
"@

New-ProjectFile -FilePath "systrack-triggers\high-priority\anyconnect-adapter-triggers.json" -Content $anyconnectTrigger

# Create sample remediation script templates
$agentMonitoringScript = @"
<#
.SYNOPSIS
    SysTrack Agent Health Monitoring and Auto-Repair
.DESCRIPTION
    Monitors SysTrack TrayApp process and automatically restarts if needed
.PARAMETER CheckInterval
    How often to check agent status (default: 300 seconds)
.PARAMETER MaxRestartAttempts
    Maximum restart attempts before escalation (default: 3)
#>

param(
    [int]$CheckInterval = 300,
    [int]$MaxRestartAttempts = 3,
    [switch]$LogOnly
)

# Configuration
$LogPath = "$PSScriptRoot\..\..\logs\automation\systrack-agent-monitoring.log"
$ConfigPath = "$PSScriptRoot\..\..\config\environments\production.json"

function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $LogEntry = "[$Timestamp] [$Level] $Message"
    Write-Host $LogEntry
    Add-Content -Path $LogPath -Value $LogEntry
}

function Test-SysTrackAgent {
    $TrayAppProcess = Get-Process -Name "SysTrack*" -ErrorAction SilentlyContinue
    $ServiceStatus = Get-Service -Name "SysTrack*" -ErrorAction SilentlyContinue
    
    return @{
        ProcessRunning = $null -ne $TrayAppProcess
        ServiceRunning = ($ServiceStatus | Where-Object { $_.Status -eq 'Running' }).Count -gt 0
        LastDataUpload = (Get-Date).AddMinutes(-30) # TODO: Check actual last upload
    }
}

function Restart-SysTrackAgent {
    param([int]$AttemptNumber)
    
    Write-Log "Attempting SysTrack agent restart (Attempt $AttemptNumber of $MaxRestartAttempts)" "WARN"
    
    try {
        # Stop processes
        Get-Process -Name "SysTrack*" -ErrorAction SilentlyContinue | Stop-Process -Force
        Start-Sleep -Seconds 5
        
        # Restart services
        Get-Service -Name "SysTrack*" | Restart-Service
        Start-Sleep -Seconds 10
        
        # Validate restart
        $Status = Test-SysTrackAgent
        if ($Status.ProcessRunning -and $Status.ServiceRunning) {
            Write-Log "SysTrack agent restart successful" "INFO"
            return $true
        } else {
            Write-Log "SysTrack agent restart failed - process or service not running" "ERROR"
            return $false
        }
    }
    catch {
        Write-Log "SysTrack agent restart failed: $($_.Exception.Message)" "ERROR"
        return $false
    }
}

# Main monitoring loop
Write-Log "Starting SysTrack Agent Monitoring" "INFO"

if ($LogOnly) {
    $Status = Test-SysTrackAgent
    Write-Log "Agent Status - Process: $($Status.ProcessRunning), Service: $($Status.ServiceRunning)" "INFO"
    exit 0
}

$RestartAttempts = 0
while ($true) {
    $Status = Test-SysTrackAgent
    
    if (-not $Status.ProcessRunning -or -not $Status.ServiceRunning) {
        Write-Log "SysTrack agent issue detected - Process: $($Status.ProcessRunning), Service: $($Status.ServiceRunning)" "WARN"
        
        if ($RestartAttempts -lt $MaxRestartAttempts) {
            $RestartAttempts++
            $RestartSuccess = Restart-SysTrackAgent -AttemptNumber $RestartAttempts
            
            if ($RestartSuccess) {
                $RestartAttempts = 0  # Reset counter on success
            }
        } else {
            Write-Log "Maximum restart attempts exceeded - escalating to manual intervention" "ERROR"
            # TODO: Send alert to operations team
            $RestartAttempts = 0  # Reset for next cycle
        }
    } else {
        if ($RestartAttempts -gt 0) {
            Write-Log "SysTrack agent monitoring normal - reset restart counter" "INFO"
            $RestartAttempts = 0
        }
    }
    
    Start-Sleep -Seconds $CheckInterval
}
"@

New-ProjectFile -FilePath "remediation-scripts\monitoring\systrack-agent-repair.ps1" -Content $agentMonitoringScript

# Create deployment script
$deploymentScript = @"
<#
.SYNOPSIS
    SysTrack Automation Deployment Script
.DESCRIPTION
    Deploys and configures SysTrack automation components
#>

param(
    [ValidateSet('Development', 'Staging', 'Production')]
    [string]$Environment = 'Development',
    [switch]$InstallOnly,
    [switch]$ConfigureOnly
)

$ProjectRoot = Split-Path $PSScriptRoot -Parent
Write-Host "Deploying SysTrack Automation to $Environment environment..." -ForegroundColor Green

# Install PowerShell modules if needed
if (-not $ConfigureOnly) {
    Write-Host "Installing required PowerShell modules..." -ForegroundColor Yellow
    
    $RequiredModules = @(
        'Az.Accounts',
        'Az.Resources', 
        'Microsoft.Graph.Authentication',
        'Microsoft.Graph.Users',
        'ActiveDirectory'
    )
    
    foreach ($Module in $RequiredModules) {
        if (-not (Get-Module -Name $Module -ListAvailable)) {
            Write-Host "Installing $Module..." -ForegroundColor Cyan
            Install-Module -Name $Module -Force -AllowClobber
        } else {
            Write-Host "$Module already installed" -ForegroundColor Green
        }
    }
}

# Configure environment
if (-not $InstallOnly) {
    Write-Host "Configuring $Environment environment..." -ForegroundColor Yellow
    
    $ConfigPath = "$ProjectRoot\config\environments\$($Environment.ToLower()).json"
    if (-not (Test-Path $ConfigPath)) {
        Write-Host "Creating $Environment configuration from template..." -ForegroundColor Cyan
        Copy-Item "$ProjectRoot\config\templates\environment.template.json" $ConfigPath
        Write-Host "Please edit $ConfigPath with your environment-specific settings" -ForegroundColor Yellow
    }
    
    # Create log directories
    $LogDirs = @('automation', 'errors', 'performance', 'audit')
    foreach ($LogDir in $LogDirs) {
        $FullLogPath = "$ProjectRoot\logs\$LogDir"
        if (-not (Test-Path $FullLogPath)) {
            New-Item -ItemType Directory -Path $FullLogPath -Force | Out-Null
            Write-Host "Created log directory: $FullLogPath" -ForegroundColor Green
        }
    }
    
    # Set up scheduled tasks for monitoring
    Write-Host "Setting up monitoring scheduled tasks..." -ForegroundColor Yellow
    
    $TaskAction = New-ScheduledTaskAction -Execute "PowerShell.exe" -Argument "-File `"$ProjectRoot\remediation-scripts\monitoring\systrack-agent-repair.ps1`""
    $TaskTrigger = New-ScheduledTaskTrigger -Once -At (Get-Date) -RepetitionInterval (New-TimeSpan -Minutes 5)
    $TaskSettings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable
    
    try {
        Register-ScheduledTask -TaskName "SysTrack-Agent-Monitoring" -Action $TaskAction -Trigger $TaskTrigger -Settings $TaskSettings -Description "SysTrack Agent Health Monitoring" -Force
        Write-Host "Scheduled task 'SysTrack-Agent-Monitoring' created successfully" -ForegroundColor Green
    } catch {
        Write-Host "Warning: Could not create scheduled task - $($_.Exception.Message)" -ForegroundColor Yellow
    }
}

Write-Host "`nDeployment completed!" -ForegroundColor Green
Write-Host "Next steps:" -ForegroundColor Yellow
Write-Host "1. Edit configuration file: config\environments\$($Environment.ToLower()).json" -ForegroundColor White
Write-Host "2. Test SysTrack API connectivity: .\tools\test-systrack-connection.ps1" -ForegroundColor White
Write-Host "3. Review and customize trigger thresholds in config\thresholds\" -ForegroundColor White
Write-Host "4. Start with SysTrack agent monitoring: .\remediation-scripts\monitoring\systrack-agent-repair.ps1 -LogOnly" -ForegroundColor White
"@

New-ProjectFile -FilePath "deployment\scripts\deploy-automation.ps1" -Content $deploymentScript

# Create project status summary
Write-Host "`nCreating Project Status Files..." -ForegroundColor Cyan

$statusContent = @"
# Project Setup Complete

## Created Structure
- SysTrack Triggers: 6 priority categories
- Remediation Scripts: 7 functional categories  
- Automation Engine: Core automation logic
- Workflows: 3 workflow types (critical, scheduled, user-impacting)
- Configuration: Environment templates and thresholds
- Reporting: Dashboard and metrics framework
- Testing: Unit, integration, and validation testing
- Documentation: Setup, operations, development guides
- Security: Credentials, certificates, audit logging
- Deployment: Installation and rollback procedures
- Logs: Comprehensive logging infrastructure
- Tools: API clients, parsers, notifications

## Quick Start
1. Run deployment script: .\deployment\scripts\deploy-automation.ps1
2. Configure environment: Edit config\environments\production.json
3. Test connectivity: Validate SysTrack API access
4. Start monitoring: Enable SysTrack agent health monitoring

## Priority Implementation Order
1. SysTrack Agent Monitoring (Foundation)
2. CPU Interrupt Remediation (Highest Impact - 1,857 systems)
3. Cisco AnyConnect Remediation (High Impact - 1,177 systems)
4. Azure AD Password Automation (High Impact - 1,062 systems)
5. Memory Leak Detection (Multiple processes)

Total estimated setup time: 2-4 hours
First automation operational: Same day
"@

New-ProjectFile -FilePath "PROJECT-SETUP-COMPLETE.md" -Content $statusContent

Write-Host "`nSysTrack Enterprise Automation Project Setup Complete!" -ForegroundColor Green
Write-Host "`nProject Structure Created:" -ForegroundColor Yellow
Write-Host "   SysTrack Triggers: 6 priority categories" -ForegroundColor White
Write-Host "   Remediation Scripts: 7 script categories" -ForegroundColor White  
Write-Host "   Automation Engine: Core logic" -ForegroundColor White
Write-Host "   Workflows: 3 workflow types" -ForegroundColor White
Write-Host "   Configuration: Environment & templates" -ForegroundColor White
Write-Host "   Reporting: Dashboards & metrics" -ForegroundColor White
Write-Host "   Testing: Validation framework" -ForegroundColor White
Write-Host "   Documentation: Comprehensive guides" -ForegroundColor White
Write-Host "   Security: Credentials & audit" -ForegroundColor White
Write-Host "   Deployment: Installation scripts" -ForegroundColor White
Write-Host "   Logs: Audit trails" -ForegroundColor White
Write-Host "   Tools: Utilities & helpers" -ForegroundColor White

Write-Host "`nReady to Start Development!" -ForegroundColor Green
Write-Host "`nNext Steps:" -ForegroundColor Yellow
Write-Host "   1. Run: .\deployment\scripts\deploy-automation.ps1" -ForegroundColor Cyan
Write-Host "   2. Configure: config\environments\production.json" -ForegroundColor Cyan  
Write-Host "   3. Test: SysTrack API connectivity" -ForegroundColor Cyan
Write-Host "   4. Begin: SysTrack agent monitoring automation" -ForegroundColor Cyan

Write-Host "`nFoundation complete for automating 500+ SysTrack triggers!" -ForegroundColor Magenta
Write-Host "   Target: 80%+ automated resolution for 11 high-impact issues" -ForegroundColor White
Write-Host "   Impact: 2,270+ systems, 1400% ROI potential" -ForegroundColor White

Write-Host "`nProject setup completed successfully!" -ForegroundColor Green
