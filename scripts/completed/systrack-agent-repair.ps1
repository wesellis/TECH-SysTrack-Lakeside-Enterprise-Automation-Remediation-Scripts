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
    
    # Create log directory if it doesn't exist
    $LogDir = Split-Path $LogPath -Parent
    if (!(Test-Path $LogDir)) {
        New-Item -ItemType Directory -Path $LogDir -Force | Out-Null
    }
    
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
