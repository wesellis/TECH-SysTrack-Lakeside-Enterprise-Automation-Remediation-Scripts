<#
.SCRIPT NAME
	Detect_M365_Office365_Issues.ps1
    
.SCRIPT TEMPLATE Version: 8
2025/02/18 v5 - StanTurner: Updated the script to add global variable $returnCode = [int]0
                            Updated the function ExitScript() to correct the Exist($ExitCode) with Exit($code).
                            Updated final statement to correct call to ExitScript() from parameter of '-code 0' to '-code $returnCode'.
                            Changed global $retain from $false to $true.  The initialize log file will overwrite if larger than 1MB.
                            Updated function Get-CurrentUserProfilePath() to newer code.
2025/03/25 v6 - StanTurner: Updated to add initialization information about the OS Name, Version, Build and Caption Version to the logging.
2025/03/28 v7 - StanTurner: Merged both automation templates into one.  
                            Moved common functions to new CC_PsFunctions.psm1 module file.
                            Added new variables and initialization for the CC_PsFunctions.psm1 module file.
                            Updated the LogWrite to support logfile or console output based on $script:log setting to $true or $false.
                            Added [string] and [int] types to the ExitScript parameters.
2025/03/28 v8 - StanTurner: Added a runtime duration to the Exit logging. 
                            Changed the -Simulate commandline parameter from a type STRING to a type SWITCH.  See below .INPUTS section for usage.
                            Removed the Conditional Logic that was setting the boolean values for -Simulate and renamed $SimulateBool to $Simulate.
                            Added the new CC_PsFunctions.psm1 v1.1 to align/support ps1 template script v8.


.DESCRIPTION 
	Detects Microsoft Office 365 installation issues requiring repair. Checks for common Office 365 problems that would benefit from repair including crashes, startup failures, activation issues.

.INPUTS
{Optional} commandline argument{s} to the .bat script that is followed by a value {string/int} for the Assign Commandline Args Parameters section in script below.  
    If arguments are not provided, then the script should typically assign a default value in the Parameter section.  The -Simulate argument is a SWITCH object, which means if it is included on the runtime commandline arguments, then the script $Simulate will automatically be set to $TRUE and if it is omitted from the arguments then it will be set to $FALSE.  The -Simulate should NOT have any value tied to it, i.e. -Simulate "Yes"... just standalone -Simulate.
        
    -Simulate     (Do NOT include any argument 'value' string for the -Simulate because it is a type SWITCH)
  

.OUTPUTS
	When enabled, a log file will be created in the same folder the script has been copied to by the SysTrack Cloud
    i.e. "C:\Program Files (x86)\SysTrack\LsiAgent\CMD\...
    This script will perform the following: 
    
    1. Check Office installation registry entries
    2. Scan for Office crash logs in the last 7 days
    3. Monitor Office process status for hanging applications
    4. Verify Office activation/licensing status
    5. Validate critical Office executable files exist
    6. Review Windows Event Log for Office errors
    7. Output detection results for SysTrack automation triggers


.NOTES
	Version:      1.0
	Company:      CompuCom
    Author:       SysTrack Automation Team
    Contact:      Stan.Turner@compucom.com
	Requirements: This script assumed to be run by the SysTrack agent which will either use the Local System or User account depending on how the Automation Profile is configured in SysTrack console.
	Changes:      2025/07/01 v1.0 SysTrack Automation Team 
                  - Initial Release - Detection triggers: Office crashes, startup failures, activation issues

.KEY VARIABLES
    $ErrorActionPreference = "Stop"
	         NOTE: $ErrorActionPreference is a built-in (automatic) PowerShell preference variable that will change how the script responds to non-terminating runtime errors.
			       The below values can be set at anytime throughout the script to change behavor as needed in the current code context.
             | Value              | Behavior                                                             |
             | ------------------ | -------------------------------------------------------------------- |
             | `Continue`         | (Default) Displays the error and continues executing the script.     |
             | `Stop`             | Stops execution immediately on an error, treating it as terminating. |
             | `SilentlyContinue` | Ignores the error (no message, continues script execution).          |
             | `Inquire`          | Prompts the user for input on how to proceed.                        |
             | `Ignore`           | Ignores the error completely (it won't even be added to `$Error`).   |
    $retain = $false # new log on each run

Copyright CompuCom 2024
#>

####################################
# Assign Commandline Args to Variables
####################################

param(
    [switch]$Simulate
)

####################################


####################################
# Begin Global Variables
####################################

    ####################################
    # Begin Template Global Variables
    ####################################
    
    $ScriptVersion = "1.0"

    $script:log = $true # set to $false if no logging to file should occur and logging will go to Console.
    $ScriptStartTime = Get-Date
    $ErrorActionPreference = "Stop"  # Stop on errors to ensure script fails fast and logs issues, see .KEY VARIABLES section above for more info.
    $retain = $true # new log on each run $false, append $true
    $ScriptName = & { $myInvocation.ScriptName }
    $ScriptPath = Split-Path -parent $ScriptName
    $ScriptName = Split-Path $ScriptName -Leaf
    $ScriptNameBase = $ScriptName.Replace(".ps1","")
    $ModuleFileName = "CC_PsFunctions.psm1"
    $ModuleFilePath = Join-Path -Path $ScriptPath -ChildPath $ModuleFileName
    $Logfile = "$ScriptPath\$ScriptNameBase" + "_ps1.log"
    $returnCode = [int]0

    ### Globals for CC_PsFunctions.psm1 Module
    $global:OSInfo = $null
    $global:MajorVersion = $null
    $global:CaptionVersion = $null
    $global:WhoAmI = $null
    $global:Is64Bit = $null
    $global:currentProfilePath = $null
    $global:initialFreeDiskSpace = $null


    ####################################
    # End Template Global Variables
    ####################################


    ####################################
    # Begin Script Global Variables
    ####################################	
    

 
    ####################################
    # End Script Global Variables
    ####################################	


####################################
# End Global Variables
####################################


####################################
# Begin Functions
####################################

    ####################################
    # Begin Template Functions
    ####################################

    ### Function: LogWrite (Logging)
    function LogWrite([string]$info)
    {       
        if($script:log -eq $true)
        {   
            # Write to logfile date - message
            "$(get-date -format "yyyy-MM-dd HH:mm:ss") -  $info" >> $Logfile
            # Any logged Start or Exit statements also write to host
            If ( ($info.contains("Starting Script")) -or ($info.contains("Exiting Script")) ) {
            	Write-Host $info
            }
            # Any logged Warning or Error statements also write to host
            If ( ($info.contains("Error:")) -or ($info.contains("Warning"))) {
            	Write-Host "  " $info  "(See Log For Details)"
            }
        }
        else  {
            Write-Host $info
        }
    }              


    ### Function: ExitScript
    function ExitScript([string]$msg, [int]$code) {
      
        LogWrite "$msg ($code)"
        $ScriptEndTime = Get-Date
        $ScriptRunTime = $ScriptEndTime - $ScriptStartTime
     
        # Get hours, minutes, seconds, and milliseconds separately
        $hours = $ScriptRunTime.Hours
        $minutes = $ScriptRunTime.Minutes
        $seconds = $ScriptRunTime.Seconds
    
        # Round the milliseconds and convert to 3-digit format
        $milliseconds = [math]::Round($ScriptRunTime.Milliseconds * 10 / 100).ToString().PadLeft(3, '0')
    
        # Format the time difference
        $formattedRunTime = "{0:D2}:{1:D2}:{2:D2}:{3}" -f $hours, $minutes, $seconds, $milliseconds
    
        LogWrite "####################################################################################################"
        LogWrite "#####################################       Exiting Script:  [$ScriptNameBase] Return Code: [$code]"
        LogWrite "#####################################       End Time:        [$ScriptEndTime]"
        LogWrite "#####################################       Script Run Time: [$formattedRunTime]"
        LogWrite "####################################################################################################"
        LogWrite "."
        LogWrite "."
        Exit($code)
    }   

    ####################################
    # End Template Functions
    ####################################

    ####################################
    # Begin Script Functions
    ####################################

    function Test-OfficeHealth {
        $issues = @()
        $severity = "Low"
        
        try {
            LogWrite "Starting Office health check..."
            
            # Check Office installation
            $officeInstall = Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Office\ClickToRun\Configuration" -ErrorAction SilentlyContinue
            if (-not $officeInstall) {
                $issues += "Office installation not found in registry"
                $severity = "Critical"
                LogWrite "Warning: Office installation not found in registry"
            } else {
                LogWrite "Office installation registry found"
            }
            
            # Check for Office crash logs (last 7 days)
            $crashPath = "$env:LOCALAPPDATA\Microsoft\Office\16.0\OfficeErrorReports"
            if (Test-Path $crashPath) {
                $recentCrashes = Get-ChildItem $crashPath | Where-Object {$_.LastWriteTime -gt (Get-Date).AddDays(-7)}
                if ($recentCrashes -and $recentCrashes.Count -gt 3) {
                    $issues += "Multiple recent Office crashes detected ($($recentCrashes.Count) in last 7 days)"
                    $severity = "High"
                    LogWrite "Warning: Multiple Office crashes detected - $($recentCrashes.Count) in last 7 days"
                } else {
                    LogWrite "No significant Office crash history found"
                }
            }
            
            # Check Office processes status
            $officeProcesses = Get-Process | Where-Object {$_.ProcessName -match "WINWORD|EXCEL|POWERPNT|OUTLOOK"}
            $hangingProcesses = $officeProcesses | Where-Object {$_.Responding -eq $false}
            if ($hangingProcesses) {
                $issues += "Non-responsive Office processes: $($hangingProcesses.ProcessName -join ', ')"
                $severity = "High"
                LogWrite "Warning: Non-responsive Office processes detected: $($hangingProcesses.ProcessName -join ', ')"
            } else {
                LogWrite "All Office processes are responding normally"
            }
            
            # Check activation status
            $osppPath = "$env:ProgramFiles\Microsoft Office\Office16\ospp.vbs"
            if (Test-Path $osppPath) {
                try {
                    $licenseStatus = & cscript.exe $osppPath /dstatus 2>$null | Out-String
                    if ($licenseStatus -match "UNLICENSED|GRACE|NOTIFICATION") {
                        $issues += "Office licensing issues detected"
                        $severity = "High"
                        LogWrite "Warning: Office licensing issues detected"
                    } else {
                        LogWrite "Office license status appears normal"
                    }
                } catch {
                    $issues += "Cannot verify Office license status"
                    if ($severity -eq "Low") { $severity = "Medium" }
                    LogWrite "Warning: Cannot verify Office license status"
                }
            }
            
            # Check for corrupted Office files
            $officeRoot = "$env:ProgramFiles\Microsoft Office\root\Office16"
            $criticalFiles = @("WINWORD.EXE", "EXCEL.EXE", "POWERPNT.EXE", "OUTLOOK.EXE")
            foreach ($file in $criticalFiles) {
                if (-not (Test-Path (Join-Path $officeRoot $file))) {
                    $issues += "Missing critical Office file: $file"
                    $severity = "Critical"
                    LogWrite "Error: Missing critical Office file: $file"
                } else {
                    LogWrite "Critical Office file verified: $file"
                }
            }
            
            # Check Windows Event Log for Office errors (last 24 hours)
            $yesterday = (Get-Date).AddDays(-1)
            $officeErrors = Get-WinEvent -FilterHashtable @{LogName='Application'; StartTime=$yesterday; Level=2} -ErrorAction SilentlyContinue | 
                           Where-Object {$_.ProviderName -match "Microsoft Office|Word|Excel|PowerPoint|Outlook"}
            if ($officeErrors -and $officeErrors.Count -gt 5) {
                $issues += "Multiple Office errors in Windows Event Log ($($officeErrors.Count) errors)"
                if ($severity -eq "Low") { $severity = "Medium" }
                LogWrite "Warning: Multiple Office errors in Windows Event Log - $($officeErrors.Count) errors"
            } else {
                LogWrite "No significant Office errors in Windows Event Log"
            }
            
        } catch {
            $issues += "Error during Office health check: $($_.Exception.Message)"
            $severity = "Medium"
            LogWrite "Error: Error during Office health check: $($_.Exception.Message)"
        }
        
        # Output results
        $result = @{
            IssuesFound = $issues.Count -gt 0
            IssueCount = $issues.Count
            Issues = $issues
            Severity = $severity
            Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
            RequiresRepair = $issues.Count -gt 0
        }
        
        LogWrite "Office health check completed - Issues: $($result.IssueCount), Severity: $($result.Severity)"
        
        return $result
    }

    ####################################
    # End Script Functions
    ####################################

####################################
# End Functions
####################################
	
    
####################################
# Begin Template Intialize
####################################

### Setup Log file and Initialize Logging
#Delete existing log files > 1mb
If (test-path $Logfile) {
	If ($retain -eq $true) {
		If ((Get-Item $Logfile).length -gt 1mb) {
			Remove-Item $Logfile
		}
	}
	Else {
		Remove-Item $Logfile
	}
}


# Initialize Variables and Logging
LogWrite "####################################################################################################"
LogWrite "#####################################      Starting Script: [$ScriptNameBase] Version: [$ScriptVersion]"
LogWrite "#####################################      Start Time:     [$ScriptStartTime]"
LogWrite "####################################################################################################"
# Import the Function Module
try {
    if (test-path $ModuleFilePath) {
        Import-Module $ModuleFilePath -Force
        LogWrite "Module Import:    [Successful]"
    }
    else {
        LogWrite "Module Import:    [Warning] Module file not found [$($ModuleFilePath)] - continuing without module"
    }
}
catch {
    LogWrite "Module Import:    [Warning] Module [$($ModuleFilePath)] failed due to load error.  Continuing without module. ErrorMsg: $_"
}

# Log all the Environment Information (if module available)
try {
    Get-Environment_Info
} catch {
    LogWrite "Environment Info: [Warning] Could not retrieve environment info - continuing"
}

# Log input from commandline arguments
LogWrite "Runtime value for -Simulate: $Simulate"

# Log the runtime mode
LogWrite "######################################################"
if ($Simulate) {
    LogWrite "### [ALERT: Script is running in Simulation Mode]  ###"
}
else {
    LogWrite "### [ALERT: Script is running in Live-Change Mode] ###"
}
LogWrite "######################################################"


####################################
# End Template Initialize
####################################
	
	
####################################
# Begin Main Script
####################################

try {
    # Execute the health check
    $healthCheck = Test-OfficeHealth
    
    if ($Simulate) {
        LogWrite "SIMULATION MODE: Would output Office health status"
        LogWrite "SIMULATION MODE: Issues found: $($healthCheck.IssuesFound)"
        LogWrite "SIMULATION MODE: Issue count: $($healthCheck.IssueCount)"
        LogWrite "SIMULATION MODE: Severity: $($healthCheck.Severity)"
    } else {
        # Output for SysTrack
        Write-Output "OFFICE_HEALTH_STATUS: $($healthCheck.RequiresRepair)"
        Write-Output "ISSUE_COUNT: $($healthCheck.IssueCount)"
        Write-Output "SEVERITY: $($healthCheck.Severity)"
        
        if ($healthCheck.IssuesFound) {
            Write-Output "ISSUES_DETECTED:"
            foreach ($issue in $healthCheck.Issues) {
                Write-Output "  - $issue"
            }
        }
        
        # Log to Event Log
        try {
            $logEntry = "Office Health Check - Issues: $($healthCheck.IssueCount), Severity: $($healthCheck.Severity)"
            Write-EventLog -LogName Application -Source "SysTrack Automation" -EventId 1001 -EntryType Information -Message $logEntry -ErrorAction SilentlyContinue
        } catch {
            LogWrite "Warning: Could not write to Event Log"
        }
    }
    
    # Set return code based on results
    if ($healthCheck.RequiresRepair) {
        $returnCode = 1  # Issues found
        LogWrite "Office issues detected - repair required"
    } else {
        $returnCode = 0  # No issues
        LogWrite "Office health check passed - no issues detected"
    }
    
} catch {
    LogWrite "Error: Unexpected error in main script: $($_.Exception.Message)"
    $returnCode = -1
}

####################################
# End Main Script
####################################


####################################
# Exit Script
####################################

ExitScript -msg "Script Completed" -code $returnCode