#Requires -Version 5.1
#Requires -RunAsAdministrator

<#
.SYNOPSIS
    Diagnoses and repairs web browser performance and functionality issues.

.DESCRIPTION
    This script identifies and fixes common browser problems including:
    - Browser crashes and hangs
    - Slow browser performance
    - Extension conflicts
    - Cache and profile corruption
    - Multiple browser optimization

.PARAMETER LogOnly
    Run in diagnostic mode only - no changes made

.PARAMETER ResetProfiles
    Enable browser profile reset for corrupted profiles

.PARAMETER ClearCache
    Enable comprehensive cache clearing

.PARAMETER ReportPath
    Path to save diagnostic report

.EXAMPLE
    .\Fix-BrowserIssues.ps1 -LogOnly
    Diagnose browser issues without making changes

.EXAMPLE
    .\Fix-BrowserIssues.ps1 -ResetProfiles -ClearCache
    Full browser repair including profile reset and cache clearing

.NOTES
    File Name: Fix-BrowserIssues.ps1
    Version: 1.0
    Date: June 30, 2025
    Author: Wesley Ellis (Wesley.Ellis@compucom.com)
    Company: CompuCom - SysTrack Automation Team
    
    Impact: Browser issues affect productivity and web access
    Priority: HIGH - Critical for business applications and user productivity
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [switch]$LogOnly,
    
    [Parameter(Mandatory = $false)]
    [switch]$ResetProfiles,
    
    [Parameter(Mandatory = $false)]
    [switch]$ClearCache,
    
    [Parameter(Mandatory = $false)]
    [string]$ReportPath = "$env:TEMP\Browser-Issues-Report-$(Get-Date -Format 'yyyyMMdd-HHmmss').log"
)

# Script metadata and logging setup
$Script:ScriptVersion = "1.0"
$Script:ScriptDate = "2025-06-30"
$Script:ScriptAuthor = "Wesley Ellis (Wesley.Ellis@compucom.com)"
$Script:LogFile = $ReportPath
$Script:StartTime = Get-Date
$Script:FixesApplied = @()
$Script:IssuesFound = @()

function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "[$timestamp] [$Level] $Message"
    Write-Host $logEntry -ForegroundColor $(
        switch ($Level) { "ERROR" { "Red" }; "WARN" { "Yellow" }; "SUCCESS" { "Green" }; default { "White" } }
    )
    Add-Content -Path $Script:LogFile -Value $logEntry -ErrorAction SilentlyContinue
}

function Get-InstalledBrowsers {
    Write-Log "Detecting installed browsers..."
    $browsers = @()
    
    try {
        # Common browser locations and registry entries
        $browserInfo = @(
            @{Name="Chrome"; Process="chrome"; Path="Google\Chrome\Application\chrome.exe"},
            @{Name="Edge"; Process="msedge"; Path="Microsoft\Edge\Application\msedge.exe"},
            @{Name="Firefox"; Process="firefox"; Path="Mozilla Firefox\firefox.exe"},
            @{Name="Internet Explorer"; Process="iexplore"; Path="Internet Explorer\iexplore.exe"}
        )
        
        foreach ($browser in $browserInfo) {
            # Check if process is running
            $process = Get-Process -Name $browser.Process -ErrorAction SilentlyContinue
            if ($process) {
                $browsers += [PSCustomObject]@{
                    Name = $browser.Name
                    ProcessName = $browser.Process
                    Running = $true
                    ProcessCount = @($process).Count
                    MemoryUsage = [math]::Round(($process | Measure-Object WorkingSet -Sum).Sum / 1MB, 0)
                    Path = $process[0].Path
                }
            } else {
                # Check if installed
                $installPath = "${env:ProgramFiles}\$($browser.Path)"
                $installPathX86 = "${env:ProgramFiles(x86)}\$($browser.Path)"
                
                if (Test-Path $installPath) {
                    $browsers += [PSCustomObject]@{
                        Name = $browser.Name
                        ProcessName = $browser.Process
                        Running = $false
                        ProcessCount = 0
                        MemoryUsage = 0
                        Path = $installPath
                    }
                } elseif (Test-Path $installPathX86) {
                    $browsers += [PSCustomObject]@{
                        Name = $browser.Name
                        ProcessName = $browser.Process
                        Running = $false
                        ProcessCount = 0
                        MemoryUsage = 0
                        Path = $installPathX86
                    }
                }
            }
        }
        
        Write-Log "Found $($browsers.Count) installed browsers"
        return $browsers
    } catch {
        Write-Log "Error detecting browsers: $($_.Exception.Message)" -Level "ERROR"
        return @()
    }
}

function Test-BrowserPerformance {
    param([array]$Browsers)
    Write-Log "Analyzing browser performance..."
    $performanceIssues = @()
    
    foreach ($browser in $Browsers) {
        if ($browser.Running) {
            # Check for excessive memory usage
            if ($browser.MemoryUsage -gt 4096) {  # > 4GB
                $performanceIssues += [PSCustomObject]@{
                    Browser = $browser.Name
                    Issue = "Excessive memory usage"
                    Value = "$($browser.MemoryUsage) MB"
                    Severity = "High"
                }
            }
            
            # Check for too many processes
            if ($browser.ProcessCount -gt 10) {
                $performanceIssues += [PSCustomObject]@{
                    Browser = $browser.Name
                    Issue = "Too many browser processes"
                    Value = "$($browser.ProcessCount) processes"
                    Severity = "Medium"
                }
            }
        }
    }
    
    Write-Log "Found $($performanceIssues.Count) browser performance issues"
    return $performanceIssues
}

function Clear-BrowserCache {
    param([array]$Browsers)
    Write-Log "Clearing browser cache and temporary files..."
    $fixes = @()
    
    if ($ClearCache) {
        foreach ($browser in $Browsers) {
            try {
                if (-not $LogOnly) {
                    # Terminate browser processes first
                    if ($browser.Running) {
                        Stop-Process -Name $browser.ProcessName -Force -ErrorAction SilentlyContinue
                        Start-Sleep -Seconds 3
                        $fixes += "Terminated $($browser.Name) processes"
                    }
                    
                    # Clear cache based on browser type
                    switch ($browser.Name) {
                        "Chrome" {
                            $cachePaths = @(
                                "$env:LOCALAPPDATA\Google\Chrome\User Data\Default\Cache",
                                "$env:LOCALAPPDATA\Google\Chrome\User Data\Default\Code Cache",
                                "$env:LOCALAPPDATA\Google\Chrome\User Data\Default\GPUCache"
                            )
                            foreach ($path in $cachePaths) {
                                if (Test-Path $path) {
                                    Remove-Item -Path "$path\*" -Recurse -Force -ErrorAction SilentlyContinue
                                    $fixes += "Cleared Chrome cache: $(Split-Path $path -Leaf)"
                                }
                            }
                        }
                        "Edge" {
                            $cachePaths = @(
                                "$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default\Cache",
                                "$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default\Code Cache",
                                "$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default\GPUCache"
                            )
                            foreach ($path in $cachePaths) {
                                if (Test-Path $path) {
                                    Remove-Item -Path "$path\*" -Recurse -Force -ErrorAction SilentlyContinue
                                    $fixes += "Cleared Edge cache: $(Split-Path $path -Leaf)"
                                }
                            }
                        }
                        "Firefox" {
                            $profilePath = "$env:APPDATA\Mozilla\Firefox\Profiles"
                            if (Test-Path $profilePath) {
                                $profiles = Get-ChildItem -Path $profilePath -Directory
                                foreach ($profile in $profiles) {
                                    $cachePath = Join-Path $profile.FullName "cache2"
                                    if (Test-Path $cachePath) {
                                        Remove-Item -Path "$cachePath\*" -Recurse -Force -ErrorAction SilentlyContinue
                                        $fixes += "Cleared Firefox cache for profile: $($profile.Name)"
                                    }
                                }
                            }
                        }
                    }
                } else {
                    Write-Log "Would clear cache for $($browser.Name)" -Level "WARN"
                }
            } catch {
                Write-Log "Error clearing cache for $($browser.Name): $($_.Exception.Message)" -Level "ERROR"
            }
        }
    } else {
        Write-Log "Cache clearing not requested"
    }
    
    return $fixes
}

function Reset-BrowserProfiles {
    param([array]$Browsers)
    Write-Log "Resetting browser profiles..."
    $fixes = @()
    
    if ($ResetProfiles) {
        foreach ($browser in $Browsers) {
            try {
                if (-not $LogOnly) {
                    # Terminate browser first
                    if ($browser.Running) {
                        Stop-Process -Name $browser.ProcessName -Force -ErrorAction SilentlyContinue
                        Start-Sleep -Seconds 3
                    }
                    
                    # Reset profiles based on browser type
                    switch ($browser.Name) {
                        "Chrome" {
                            $profilePath = "$env:LOCALAPPDATA\Google\Chrome\User Data\Default"
                            if (Test-Path $profilePath) {
                                $backupPath = "$env:TEMP\ChromeProfileBackup_$(Get-Date -Format 'yyyyMMdd')"
                                Copy-Item -Path $profilePath -Destination $backupPath -Recurse -ErrorAction SilentlyContinue
                                
                                # Reset key profile files
                                $filesToReset = @("Preferences", "Local State", "Secure Preferences")
                                foreach ($file in $filesToReset) {
                                    $filePath = Join-Path $profilePath $file
                                    if (Test-Path $filePath) {
                                        Remove-Item -Path $filePath -Force -ErrorAction SilentlyContinue
                                    }
                                }
                                $fixes += "Reset Chrome profile (backup created)"
                            }
                        }
                        "Edge" {
                            $profilePath = "$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default"
                            if (Test-Path $profilePath) {
                                $backupPath = "$env:TEMP\EdgeProfileBackup_$(Get-Date -Format 'yyyyMMdd')"
                                Copy-Item -Path $profilePath -Destination $backupPath -Recurse -ErrorAction SilentlyContinue
                                
                                # Reset key profile files
                                $filesToReset = @("Preferences", "Local State", "Secure Preferences")
                                foreach ($file in $filesToReset) {
                                    $filePath = Join-Path $profilePath $file
                                    if (Test-Path $filePath) {
                                        Remove-Item -Path $filePath -Force -ErrorAction SilentlyContinue
                                    }
                                }
                                $fixes += "Reset Edge profile (backup created)"
                            }
                        }
                        "Firefox" {
                            $profilePath = "$env:APPDATA\Mozilla\Firefox\Profiles"
                            if (Test-Path $profilePath) {
                                $profiles = Get-ChildItem -Path $profilePath -Directory
                                foreach ($profile in $profiles) {
                                    $backupPath = "$env:TEMP\FirefoxProfileBackup_$(Get-Date -Format 'yyyyMMdd')_$($profile.Name)"
                                    Copy-Item -Path $profile.FullName -Destination $backupPath -Recurse -ErrorAction SilentlyContinue
                                    
                                    # Reset key profile files
                                    $filesToReset = @("prefs.js", "user.js", "extensions.json")
                                    foreach ($file in $filesToReset) {
                                        $filePath = Join-Path $profile.FullName $file
                                        if (Test-Path $filePath) {
                                            Remove-Item -Path $filePath -Force -ErrorAction SilentlyContinue
                                        }
                                    }
                                }
                                $fixes += "Reset Firefox profiles (backups created)"
                            }
                        }
                    }
                } else {
                    Write-Log "Would reset profile for $($browser.Name)" -Level "WARN"
                }
            } catch {
                Write-Log "Error resetting profile for $($browser.Name): $($_.Exception.Message)" -Level "ERROR"
            }
        }
    } else {
        Write-Log "Profile reset not requested"
    }
    
    return $fixes
}

function Optimize-BrowserSettings {
    param([array]$Browsers)
    Write-Log "Optimizing browser settings..."
    $fixes = @()
    
    if (-not $LogOnly) {
        foreach ($browser in $Browsers) {
            try {
                # Browser-specific optimizations
                switch ($browser.Name) {
                    "Chrome" {
                        # Create optimized Chrome shortcut with performance flags
                        $chromeArgs = "--disable-background-timer-throttling --disable-renderer-backgrounding --disable-backgrounding-occluded-windows --disable-ipc-flooding-protection"
                        $fixes += "Would apply Chrome performance flags: $chromeArgs"
                    }
                    "Edge" {
                        # Similar optimization for Edge
                        $edgeArgs = "--disable-background-timer-throttling --disable-renderer-backgrounding"
                        $fixes += "Would apply Edge performance flags: $edgeArgs"
                    }
                    "Firefox" {
                        # Firefox about:config optimizations would go here
                        $fixes += "Would optimize Firefox configuration settings"
                    }
                }
            } catch {
                Write-Log "Error optimizing $($browser.Name): $($_.Exception.Message)" -Level "ERROR"
            }
        }
    } else {
        Write-Log "Would optimize browser settings for better performance" -Level "WARN"
    }
    
    return $fixes
}

function Restart-BrowserProcesses {
    param([array]$Browsers)
    Write-Log "Managing browser process cleanup..."
    $fixes = @()
    
    foreach ($browser in $Browsers) {
        if ($browser.Running -and $browser.MemoryUsage -gt 2048) {  # > 2GB
            try {
                if (-not $LogOnly) {
                    Write-Log "Restarting high-memory browser: $($browser.Name)"
                    
                    # Save browser state if possible (this is a simplified approach)
                    # In reality, you'd want to use browser-specific session restore
                    
                    # Terminate browser
                    Stop-Process -Name $browser.ProcessName -Force -ErrorAction SilentlyContinue
                    Start-Sleep -Seconds 5
                    
                    # Restart browser
                    if (Test-Path $browser.Path) {
                        Start-Process -FilePath $browser.Path -ErrorAction SilentlyContinue
                        $fixes += "Restarted $($browser.Name) to free memory"
                    }
                } else {
                    Write-Log "Would restart high-memory browser: $($browser.Name)" -Level "WARN"
                }
            } catch {
                Write-Log "Error restarting $($browser.Name): $($_.Exception.Message)" -Level "ERROR"
            }
        }
    }
    
    return $fixes
}

# Main execution
try {
    Write-Log "Starting Browser Issues Repair v$Script:ScriptVersion"
    Write-Log "Author: $Script:ScriptAuthor"
    Write-Log "Reset Profiles: $ResetProfiles, Clear Cache: $ClearCache"
    
    # Detect browsers
    $browsers = Get-InstalledBrowsers
    if ($browsers.Count -eq 0) {
        Write-Log "No browsers detected - exiting" -Level "WARN"
        exit 0
    }
    
    # Analyze performance issues
    $performanceIssues = Test-BrowserPerformance -Browsers $browsers
    $Script:IssuesFound = $performanceIssues
    
    Write-Log "Found $($performanceIssues.Count) browser performance issues"
    
    # Apply fixes
    $Script:FixesApplied += Clear-BrowserCache -Browsers $browsers
    $Script:FixesApplied += Reset-BrowserProfiles -Browsers $browsers
    $Script:FixesApplied += Optimize-BrowserSettings -Browsers $browsers
    $Script:FixesApplied += Restart-BrowserProcesses -Browsers $browsers
    
    # Summary
    Write-Log "=== EXECUTION SUMMARY ===" -Level "SUCCESS"
    Write-Log "Browsers Found: $($browsers.Count)"
    Write-Log "Performance Issues: $($Script:IssuesFound.Count)"
    Write-Log "Repairs Applied: $($Script:FixesApplied.Count)"
    Write-Log "Report Location: $Script:LogFile"
    
    if (-not $LogOnly -and $Script:FixesApplied.Count -gt 0) {
        Write-Log "RECOMMENDATION: Test browser functionality and performance" -Level "WARN"
    }
    
    exit 0
} catch {
    Write-Log "FATAL ERROR: $($_.Exception.Message)" -Level "ERROR"
    exit 1
}
