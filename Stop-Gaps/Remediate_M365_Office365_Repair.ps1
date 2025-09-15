<#
.SCRIPT NAME
	Remediate_M365_Office365_Repair.ps1
    
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
	Performs Microsoft Office 365 repair. Executes Office Quick Repair or Online Repair based on issue severity and automation requirements.

.INPUTS
{Optional} commandline argument{s} to the .bat script that is followed by a value {string/int} for the Assign Commandline Args Parameters section in script below.  
    If arguments are not provided, then the script should typically assign a default value in the Parameter section.  The -Simulate argument is a SWITCH object, which means if it is included on the runtime commandline arguments, then the script $Simulate will automatically be set to $TRUE and if it is omitted from the arguments then it will be set to $FALSE.  The -Simulate should NOT have any value tied to it, i.e. -Simulate "Yes"... just standalone -Simulate.
        
    -RepairType "Quick"    (Valid values: "Quick" or "Online")
    -Simulate     (Do NOT include any argument 'value' string for the -Simulate because it is a type SWITCH)
  

.OUTPUTS
	When enabled, a log file will be created in the same folder the script has been copied to by the SysTrack Cloud
    i.e. "C:\Program Files (x86)\SysTrack\LsiAgent\CMD\...
    This script will perform the following: 
    
    1. Detect Office architecture (32-bit or 64-bit) and installation path
    2. Close all running Office applications gracefully, then forcefully if needed
    3. Execute Office repair using OfficeC2RClient.exe with appropriate repair type
    4. Monitor repair process and capture exit codes
    5. Log repair results and duration
    6. Output remediation results for SysTrack automation


.NOTES
	Version:      1.0
	Company:      CompuCom
    Author:       SysTrack Automation Team
    Contact:      Stan.Turner@compucom.com
	Requirements: This script assumed to be run by the SysTrack agent which will either use the Local System or User account depending on how the Automation Profile is configured in SysTrack console.
	Changes:      2025/07/01 v1.0 SysTrack Automation Team 
                  - Initial Release - Automation: M365_Office365_Repair

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
    [ValidateSet("Quick", "Online")]
    [string]$RepairType = "Quick",
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

    function Invoke-M365OfficeRepair {
        param(
            [string]$RepairType = "Quick"
        )
        
        $repairResult = @{
            Success = $false
            RepairType = $RepairType
            Message = ""
            StartTime = Get-Date
            EndTime = $null
        }
        
        try {
            LogWrite "Starting Office $RepairType Repair..."
            
            # Detect Office architecture and path
            $officeRoot = $null
            $office32 = "$env:ProgramFiles(x86)\Microsoft Office\root\Office16"
            $office64 = "$env:ProgramFiles\Microsoft Office\root\Office16"
            
            if (Test-Path $office64) {
                $officeRoot = $office64
                LogWrite "Detected 64-bit Office installation"
            } elseif (Test-Path $office32) {
                $officeRoot = $office32
                LogWrite "Detected 32-bit Office installation"
            } else {
                throw "Office installation not found"
            }
            
            # Close Office applications with user notification
            LogWrite "Closing Office applications..."
            $officeProcesses = @("WINWORD", "EXCEL", "POWERPNT", "OUTLOOK", "MSPUB", "VISIO", "MSACCESS", "LYNC", "TEAMS")
            
            foreach ($processName in $officeProcesses) {
                $processes = Get-Process $processName -ErrorAction SilentlyContinue
                if ($processes) {
                    LogWrite "Closing $processName processes..."
                    $processes | Stop-Process -Force
                }
            }
            
            Start-Sleep -Seconds 10
            
            # Verify processes are closed
            $remainingProcesses = Get-Process | Where-Object {$_.ProcessName -in $officeProcesses}
            if ($remainingProcesses) {
                LogWrite "Force closing remaining Office processes..."
                $remainingProcesses | Stop-Process -Force
                Start-Sleep -Seconds 5
            }
            
            # Run Office repair
            $repairExecutable = "$env:ProgramFiles\Common Files\Microsoft Shared\ClickToRun\OfficeC2RClient.exe"
            
            if (-not (Test-Path $repairExecutable)) {
                throw "Office repair executable not found at: $repairExecutable"
            }
            
            if ($RepairType -eq "Quick") {
                $repairArgs = "/configure", "culture=en-us", "scenariosubtype=QuickRepair"
                LogWrite "Executing Quick Repair..."
            } else {
                $repairArgs = "/configure", "culture=en-us", "scenariosubtype=Repair"
                LogWrite "Executing Online Repair..."
            }
            
            # Start repair process
            LogWrite "Starting repair process with executable: $repairExecutable"
            LogWrite "Repair arguments: $($repairArgs -join ' ')"
            
            $process = Start-Process -FilePath $repairExecutable -ArgumentList $repairArgs -Wait -PassThru -NoNewWindow
            
            if ($process.ExitCode -eq 0) {
                $repairResult.Success = $true
                $repairResult.Message = "Office $RepairType repair completed successfully"
                LogWrite $repairResult.Message
            } else {
                throw "Office repair failed with exit code: $($process.ExitCode)"
            }
            
        } catch {
            $repairResult.Success = $false
            $repairResult.Message = "Office repair failed: $($_.Exception.Message)"
            LogWrite "Error: $($repairResult.Message)"
        } finally {
            $repairResult.EndTime = Get-Date
            $duration = ($repairResult.EndTime - $repairResult.StartTime).TotalMinutes
            LogWrite "Repair process duration: $([math]::Round($duration, 2)) minutes"
        }
        
        return $repairResult
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
LogWrite "Runtime value for -RepairType: $RepairType"
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
        LogWrite "SIMULATION MODE: Would execute Office $RepairType repair"
        LogWrite "SIMULATION MODE: Would close Office applications"
        LogWrite "SIMULATION MODE: Would run repair executable with appropriate arguments"
        LogWrite "SIMULATION MODE: Would monitor repair process and log results"
        
        # Simulate successful repair
        $result = @{
            Success = $true
            RepairType = $RepairType
            Message = "SIMULATION: Office $RepairType repair would complete successfully"
        }
        
        $returnCode = 0
        
    } else {
        # Execute repair
        $result = Invoke-M365OfficeRepair -RepairType $RepairType
        
        # Log to Event Log
        try {
            $eventMessage = "M365_Office365_Repair - $($result.RepairType) repair $(if($result.Success){'completed successfully'}else{'failed'}): $($result.Message)"
            Write-EventLog -LogName Application -Source "SysTrack Automation" -EventId 2001 -EntryType $(if($result.Success){'Information'}else{'Error'}) -Message $eventMessage -ErrorAction SilentlyContinue
        } catch {
            LogWrite "Warning: Could not write to Event Log"
        }
        
        # Output for SysTrack
        Write-Output "REPAIR_SUCCESS: $($result.Success)"
        Write-Output "REPAIR_TYPE: $($result.RepairType)"
        Write-Output "REPAIR_MESSAGE: $($result.Message)"
        
        # Set return code based on results
        if ($result.Success) {
            $returnCode = 0
            LogWrite "Office repair completed successfully"
        } else {
            $returnCode = 1
            LogWrite "Office repair failed"
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