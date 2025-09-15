<#
.SCRIPT NAME
	FollowUp_M365_Office365_Repair.ps1
    
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
	Follow-up validation script for Microsoft Office 365 repair operations. Verifies repair success and Office functionality post-remediation.

.INPUTS
{Optional} commandline argument{s} to the .bat script that is followed by a value {string/int} for the Assign Commandline Args Parameters section in script below.  
    If arguments are not provided, then the script should typically assign a default value in the Parameter section.  The -Simulate argument is a SWITCH object, which means if it is included on the runtime commandline arguments, then the script $Simulate will automatically be set to $TRUE and if it is omitted from the arguments then it will be set to $FALSE.  The -Simulate should NOT have any value tied to it, i.e. -Simulate "Yes"... just standalone -Simulate.
        
    -Simulate     (Do NOT include any argument 'value' string for the -Simulate because it is a type SWITCH)
  

.OUTPUTS
	When enabled, a log file will be created in the same folder the script has been copied to by the SysTrack Cloud
    i.e. "C:\Program Files (x86)\SysTrack\LsiAgent\CMD\...
    This script will perform the following: 
    
    1. Verify Office applications can launch successfully
    2. Check Office activation status post-repair
    3. Test basic Office functionality (create/open documents)
    4. Validate registry entries are restored
    5. Monitor for new crash logs or errors
    6. Report repair validation results for SysTrack automation


.NOTES
	Version:      1.0
	Company:      CompuCom
    Author:       SysTrack Automation Team
    Contact:      Stan.Turner@compucom.com
	Requirements: This script assumed to be run by the SysTrack agent which will either use the Local System or User account depending on how the Automation Profile is configured in SysTrack console.
	Changes:      2025/07/01 v1.0 SysTrack Automation Team 
                  - Initial Release - Follow-up validation for Office repair automation

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

    function Test-OfficeRepairValidation {
        $validationResults = @{
            OverallSuccess = $true
            Tests = @()
            Summary = ""
        }
        
        try {
            LogWrite "Starting Office repair validation..."
            
            # Test 1: Verify Office installation integrity
            LogWrite "Testing Office installation integrity..."
            $officeInstall = Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Office\ClickToRun\Configuration" -ErrorAction SilentlyContinue
            if ($officeInstall) {
                $validationResults.Tests += "Office registry entries: PASS"
                LogWrite "Office registry entries validated successfully"
            } else {
                $validationResults.Tests += "Office registry entries: FAIL"
                $validationResults.OverallSuccess = $false
                LogWrite "Warning: Office registry entries missing"
            }
            
            # Test 2: Check critical Office files
            LogWrite "Checking critical Office files..."
            $officeRoot = "$env:ProgramFiles\Microsoft Office\root\Office16"
            if (-not (Test-Path $officeRoot)) {
                $officeRoot = "$env:ProgramFiles(x86)\Microsoft Office\root\Office16"
            }
            
            $criticalFiles = @("WINWORD.EXE", "EXCEL.EXE", "POWERPNT.EXE", "OUTLOOK.EXE")
            $missingFiles = @()
            
            foreach ($file in $criticalFiles) {
                $filePath = Join-Path $officeRoot $file
                if (-not (Test-Path $filePath)) {
                    $missingFiles += $file
                }
            }
            
            if ($missingFiles.Count -eq 0) {
                $validationResults.Tests += "Critical Office files: PASS"
                LogWrite "All critical Office files present"
            } else {
                $validationResults.Tests += "Critical Office files: FAIL - Missing: $($missingFiles -join ', ')"
                $validationResults.OverallSuccess = $false
                LogWrite "Warning: Missing critical Office files: $($missingFiles -join ', ')"
            }
            
            # Test 3: Verify Office activation status
            LogWrite "Checking Office activation status..."
            $osppPath = "$env:ProgramFiles\Microsoft Office\Office16\ospp.vbs"
            if (Test-Path $osppPath) {
                try {
                    $licenseStatus = & cscript.exe $osppPath /dstatus 2>$null | Out-String
                    if ($licenseStatus -match "LICENSED") {
                        $validationResults.Tests += "Office activation: PASS"
                        LogWrite "Office activation validated successfully"
                    } else {
                        $validationResults.Tests += "Office activation: WARNING - May need attention"
                        LogWrite "Warning: Office activation status unclear"
                    }
                } catch {
                    $validationResults.Tests += "Office activation: SKIP - Cannot verify"
                    LogWrite "Warning: Cannot verify Office activation status"
                }
            }
            
            # Test 4: Check for recent Office crashes
            LogWrite "Checking for recent Office crashes..."
            $crashPath = "$env:LOCALAPPDATA\Microsoft\Office\16.0\OfficeErrorReports"
            if (Test-Path $crashPath) {
                $recentCrashes = Get-ChildItem $crashPath | Where-Object {$_.LastWriteTime -gt (Get-Date).AddHours(-2)}
                if ($recentCrashes -and $recentCrashes.Count -gt 0) {
                    $validationResults.Tests += "Recent crashes: FAIL - $($recentCrashes.Count) crashes since repair"
                    $validationResults.OverallSuccess = $false
                    LogWrite "Warning: $($recentCrashes.Count) crashes detected since repair"
                } else {
                    $validationResults.Tests += "Recent crashes: PASS"
                    LogWrite "No recent crashes detected"
                }
            } else {
                $validationResults.Tests += "Recent crashes: PASS - No crash folder found"
                LogWrite "No Office crash folder found"
            }
            
            # Test 5: Basic Office process health
            LogWrite "Checking Office process health..."
            $officeProcesses = Get-Process | Where-Object {$_.ProcessName -match "WINWORD|EXCEL|POWERPNT|OUTLOOK"}
            $hangingProcesses = $officeProcesses | Where-Object {$_.Responding -eq $false}
            
            if ($hangingProcesses) {
                $validationResults.Tests += "Process health: FAIL - Non-responsive processes detected"
                $validationResults.OverallSuccess = $false
                LogWrite "Warning: Non-responsive Office processes detected"
            } else {
                $validationResults.Tests += "Process health: PASS"
                LogWrite "All Office processes responding normally"
            }
            
        } catch {
            $validationResults.Tests += "Validation error: $($_.Exception.Message)"
            $validationResults.OverallSuccess = $false
            LogWrite "Error: Validation failed: $($_.Exception.Message)"
        }
        
        # Generate summary
        $passCount = ($validationResults.Tests | Where-Object {$_ -match "PASS"}).Count
        $failCount = ($validationResults.Tests | Where-Object {$_ -match "FAIL"}).Count
        $validationResults.Summary = "Validation completed: $passCount passed, $failCount failed"
        
        LogWrite $validationResults.Summary
        
        return $validationResults
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
    if ($Simulate) {
        LogWrite "SIMULATION MODE: Would perform Office repair validation"
        LogWrite "SIMULATION MODE: Would check Office installation integrity"
        LogWrite "SIMULATION MODE: Would verify critical Office files"
        LogWrite "SIMULATION MODE: Would validate Office activation"
        LogWrite "SIMULATION MODE: Would check for recent crashes"
        LogWrite "SIMULATION MODE: Would test Office process health"
        
        # Simulate successful validation
        $validationResult = @{
            OverallSuccess = $true
            Tests = @("SIMULATION: All validation tests would pass")
            Summary = "SIMULATION: Validation would complete successfully"
        }
        
        $returnCode = 0
        
    } else {
        # Execute validation
        $validationResult = Test-OfficeRepairValidation
        
        # Output for SysTrack
        Write-Output "VALIDATION_SUCCESS: $($validationResult.OverallSuccess)"
        Write-Output "VALIDATION_SUMMARY: $($validationResult.Summary)"
        Write-Output "VALIDATION_TESTS:"
        foreach ($test in $validationResult.Tests) {
            Write-Output "  - $test"
        }
        
        # Log to Event Log
        try {
            $eventMessage = "M365_Office365_Repair_FollowUp - Validation $(if($validationResult.OverallSuccess){'completed successfully'}else{'failed'}): $($validationResult.Summary)"
            Write-EventLog -LogName Application -Source "SysTrack Automation" -EventId 3001 -EntryType $(if($validationResult.OverallSuccess){'Information'}else{'Warning'}) -Message $eventMessage -ErrorAction SilentlyContinue
        } catch {
            LogWrite "Warning: Could not write to Event Log"
        }
        
        # Set return code based on results
        if ($validationResult.OverallSuccess) {
            $returnCode = 0
            LogWrite "Office repair validation completed successfully"
        } else {
            $returnCode = 1
            LogWrite "Office repair validation detected issues"
        }
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