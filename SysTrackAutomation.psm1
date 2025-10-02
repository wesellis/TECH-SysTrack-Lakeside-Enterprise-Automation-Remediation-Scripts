#Requires -Version 5.1

<#
.SYNOPSIS
    SysTrack Enterprise Automation & Remediation Module

.DESCRIPTION
    PowerShell module for automating SysTrack/Lakeside Software operations.
    Provides remediation, monitoring, and endpoint management capabilities.

.NOTES
    Author: Wes Ellis
    Version: 1.0.0
    Date: October 2025
#>

# Module variables
$script:ModuleRoot = $PSScriptRoot
$script:SysTrackConnection = $null
$script:ConfigPath = Join-Path $ModuleRoot "config"
$script:ScriptsPath = Join-Path $ModuleRoot "scripts"

#region Connection Management

function Connect-SysTrack {
    <#
    .SYNOPSIS
        Connect to SysTrack server
    .DESCRIPTION
        Establishes connection to SysTrack/Lakeside Software server
    .PARAMETER Server
        SysTrack server URL
    .PARAMETER Credential
        Credentials for authentication
    .PARAMETER ConfigFile
        Path to configuration JSON file
    .EXAMPLE
        Connect-SysTrack -Server "systrack.company.com" -Credential (Get-Credential)
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [string]$Server,

        [Parameter(Mandatory = $false)]
        [PSCredential]$Credential,

        [Parameter(Mandatory = $false)]
        [string]$ConfigFile
    )

    try {
        # Load configuration
        if ($ConfigFile -and (Test-Path $ConfigFile)) {
            $config = Get-Content $ConfigFile | ConvertFrom-Json
            $Server = $Server ?? $config.systrack.api_url
        }

        if (-not $Server) {
            throw "Server parameter or configuration file required"
        }

        # Test connection
        $testUrl = "$Server/api/health"
        try {
            $response = Invoke-RestMethod -Uri $testUrl -Method Get -ErrorAction Stop
            Write-Host "✓ Connected to SysTrack server: $Server" -ForegroundColor Green
            $script:SysTrackConnection = @{
                Server = $Server
                Credential = $Credential
                Connected = $true
                ConnectedAt = Get-Date
            }
            return $true
        }
        catch {
            Write-Warning "Unable to connect to SysTrack server: $_"
            return $false
        }
    }
    catch {
        Write-Error "Connection failed: $_"
        return $false
    }
}

function Disconnect-SysTrack {
    <#
    .SYNOPSIS
        Disconnect from SysTrack server
    #>
    [CmdletBinding()]
    param()

    $script:SysTrackConnection = $null
    Write-Host "✓ Disconnected from SysTrack" -ForegroundColor Yellow
}

function Test-SysTrackConnection {
    <#
    .SYNOPSIS
        Test SysTrack server connection
    #>
    [CmdletBinding()]
    param()

    if ($script:SysTrackConnection -and $script:SysTrackConnection.Connected) {
        Write-Host "✓ Connected to: $($script:SysTrackConnection.Server)" -ForegroundColor Green
        return $true
    }
    else {
        Write-Warning "Not connected to SysTrack. Use Connect-SysTrack first."
        return $false
    }
}

#endregion

#region Initialization

function Initialize-SysTrackAutomation {
    <#
    .SYNOPSIS
        Initialize SysTrack automation environment
    .DESCRIPTION
        Sets up configuration, validates environment, and prepares automation
    .PARAMETER ConfigPath
        Path to configuration directory
    .PARAMETER CreateSampleConfig
        Create sample configuration files
    .EXAMPLE
        Initialize-SysTrackAutomation -CreateSampleConfig
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [string]$ConfigPath,

        [Parameter(Mandatory = $false)]
        [switch]$CreateSampleConfig
    )

    Write-Host "Initializing SysTrack Automation..." -ForegroundColor Cyan

    # Validate PowerShell version
    if ($PSVersionTable.PSVersion.Major -lt 5) {
        Write-Error "PowerShell 5.1 or higher required"
        return $false
    }

    # Check module paths
    $paths = @(
        $script:ModuleRoot
        $script:ConfigPath
        $script:ScriptsPath
    )

    foreach ($path in $paths) {
        if (Test-Path $path) {
            Write-Host "✓ Found: $path" -ForegroundColor Green
        }
        else {
            Write-Warning "Missing: $path"
        }
    }

    # Create sample config if requested
    if ($CreateSampleConfig) {
        $sampleConfigPath = Join-Path $script:ConfigPath "environments\sample.json"
        $templatePath = Join-Path $script:ConfigPath "templates\environment.template.json"

        if (Test-Path $templatePath) {
            Copy-Item $templatePath $sampleConfigPath -Force
            Write-Host "✓ Created sample config: $sampleConfigPath" -ForegroundColor Green
        }
    }

    Write-Host "✓ Initialization complete" -ForegroundColor Green
    return $true
}

#endregion

#region Helper Functions

function Get-ScriptPath {
    <#
    .SYNOPSIS
        Get full path to a remediation script
    #>
    param([string]$ScriptName)

    $completedPath = Join-Path $script:ScriptsPath "completed\$ScriptName"
    if (Test-Path $completedPath) {
        return $completedPath
    }

    $frameworkPath = Join-Path $script:ScriptsPath "framework\$ScriptName"
    if (Test-Path $frameworkPath) {
        return $frameworkPath
    }

    Write-Warning "Script not found: $ScriptName"
    return $null
}

function Invoke-RemediationScript {
    <#
    .SYNOPSIS
        Execute a remediation script with error handling
    #>
    param(
        [string]$ScriptPath,
        [hashtable]$Parameters = @{}
    )

    try {
        if (-not (Test-Path $ScriptPath)) {
            throw "Script not found: $ScriptPath"
        }

        Write-Host "Executing: $ScriptPath" -ForegroundColor Cyan
        & $ScriptPath @Parameters
        Write-Host "✓ Completed successfully" -ForegroundColor Green
        return $true
    }
    catch {
        Write-Error "Script execution failed: $_"
        return $false
    }
}

#endregion

#region Remediation Wrappers

function Fix-HighCPUUsage {
    <#
    .SYNOPSIS
        Fix high CPU usage issues
    .PARAMETER Threshold
        CPU percentage threshold (default: 90)
    #>
    [CmdletBinding()]
    param([int]$Threshold = 90)

    $scriptPath = Get-ScriptPath "Fix-HighCPUUsage.ps1"
    if ($scriptPath) {
        Invoke-RemediationScript -ScriptPath $scriptPath -Parameters @{ Threshold = $Threshold }
    }
}

function Fix-MemoryLeaks {
    <#
    .SYNOPSIS
        Detect and fix memory leaks
    #>
    [CmdletBinding()]
    param()

    $scriptPath = Get-ScriptPath "Fix-MemoryLeaks.ps1"
    if ($scriptPath) {
        Invoke-RemediationScript -ScriptPath $scriptPath
    }
}

function Fix-NetworkAdapters {
    <#
    .SYNOPSIS
        Repair network adapter issues
    #>
    [CmdletBinding()]
    param()

    $scriptPath = Get-ScriptPath "Fix-NetworkAdapters.ps1"
    if ($scriptPath) {
        Invoke-RemediationScript -ScriptPath $scriptPath
    }
}

#endregion

#region Aliases

New-Alias -Name 'Connect-ST' -Value 'Connect-SysTrack' -Force
New-Alias -Name 'Get-STHealth' -Value 'Test-SysTrackConnection' -Force

#endregion

#region Module Initialization

Write-Host "SysTrack Automation Module Loaded" -ForegroundColor Green
Write-Host "Version: 1.0.0" -ForegroundColor Gray
Write-Host "Use 'Initialize-SysTrackAutomation' to set up your environment" -ForegroundColor Yellow
Write-Host "Use 'Connect-SysTrack -Server <url>' to connect" -ForegroundColor Yellow

#endregion

# Export module members
Export-ModuleMember -Function * -Alias *
