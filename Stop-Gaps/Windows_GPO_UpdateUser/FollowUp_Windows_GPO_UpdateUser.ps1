<#
.SCRIPT NAME
		FollowUp_Windows_GPO_UpdateUser.ps1
    
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
		Windows Group Policy update and refresh operations. Post-remediation validation and verification.

.INPUTS
{Optional | Required} commandline argument{s} to the .bat script that is followed by a value {string/int} for the Assign Commandline Args Parameters section in script below.  
    If arguments are not provided, then the script should typically assign a default value in the Parameter section.  The -Simulate argument is a SWITCH object, which means if it is included on the runtime commandline arguments, then the script $Simulate will automatically be set to $TRUE and if it is omitted from the arguments then it will be set to $FALSE.  The -Simulate should NOT have any value tied to it, i.e. -Simulate "Yes"... just standalone -Simulate.
    ALERT: the -Arg1 is a SAMPLE and should be renamed to required variable name or deleted if not being used.
        
    -Arg1 10
    -Simulate     (Do NOT include any argument 'value' string for the -Simulate because it is a type SWITCH)
  

.OUTPUTS
	When enabled, a log file will be created in the same folder the script has been copied to by the SysTrack Cloud
    i.e. "C:\Program Files (x86)\SysTrack\LsiAgent\CMD\...
    This script will perform the following: 
    
    Provide psuedo code description of how the script works


.NOTES
	Version:      1.x (BE SURE TO CHANGE VERSION FOR VARIABLE BELOW e.g. $ScriptVersion = "1.3")
	Company:      CompuCom
    Author:       
    Contact:      Stan.Turner@compucom.com
	Requirements: This script assumed to be run by the SysTrack agent which will either use the Local System or User account depending on how the Automation Profile is configured in SysTrack console.
	Changes:      2025/07/08 v1.0 SysTrack Automation Team 
                  - Initial Release - Post-remediation validation and verification

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
### ALERT: This section must be modified to match the commandline named args or it will use below default values.
###        If the commandline args are not being used, then this will assign below and can be ignored (not used in main code).

param(
    
    [Parameter(Mandatory = $false,
    [switch]$Simulate,
    [int]$TempArg = 60   ### DELETE THIS IF NOT BEING USED ###
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
        LogWrite "#####################################       Exiting Script:  [$ScriptBaseName] Return Code: [$code]"
        LogWrite "#####################################       End Time:        [$ScriptEndTime]"
        LogWrite "#####################################       Script Run Time: [$formattedRunTime]"
        LogWrite "####################################################################################################"
        LogWrite "."
        LogWrite "."
        Exit($code)
    }   


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
    }
    else {
        ExitScript -msg "Module Import:    [Error] Load failure - File Missing [$($ModuleFilePath)]." -code -1
    }
    LogWrite "Module Import:    [Successful]"
}
catch {
    LogWrite "Module Import:    [Error] Module [$($ModuleFilePath)] failed due to load error.  Please review ErrorMsg to fix the module problem. ErrorMsg: $_"
    ExitScript -msg "Function Module File [$ModuleFilePath] Load Failure, exiting script now." -code -1
}

# Log all the Environment Information
Get-Environment_Info

###############################################
### ALERT: REMOVE THE BELOW COMMENT START '<#' AND COMMENT END '#>' 
###        LINES WHEN USING COMMANDLINE ARGUMENT FEATURES
###############################################

#<#
# Log input from commandline arguments.  Remove $TempArg line if this is not being used or rename to usage name.
LogWrite "Runtime value for -TempArg:  $TempArg"
LogWrite "Runtime value for -Simulate: $Simulate"

# Log the .bat commandline arguments for TempArg and runtime Simulate.
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










####################################


try {
    if ($Simulate) {
        LogWrite "SIMULATION MODE: Would execute post-remediation validation and verification"
        LogWrite "SIMULATION MODE: Script would perform: windows group policy update and refresh operations"
        $returnCode = 0
    } else {
        # Original script logic preserved below
        LogWrite "Starting windows group policy update and refresh operations"
        
]
    [switch]$HealthClinicIntegration,
    
    [Parameter(Mandatory = $false)]
    [switch]$ScheduleRecheck,
    
    [Parameter(Mandatory = $false)]
    [int]$RecheckIntervalHours = 24,
    
    [Parameter(Mandatory = $false)]
    [string]$LogSource = "SysTrack-GPO-UserFollowUp",
    
    [Parameter(Mandatory = $false)]
    [string]$HealthClinicEndpoint = "http://localhost:8080/health-clinic",
    
    [Parameter(Mandatory = $false)]
    [switch]$VerboseOutput
)

# Initialize logging
$LogName = "Application"

try {
    if (-not [System.Diagnostics.EventLog]::SourceExists($LogSource)) {
        [System.Diagnostics.EventLog]::CreateEventSource($LogSource, $LogName)
    }
} catch {
    Write-Warning "Unable to create event log source. Running with limited logging."
}

# Initialize follow-up results
$FollowUpResults = @{
    ValidationPassed = $false
    UserPolicyHealth = @{}
    PerformanceImpact = @{}
    ImprovementMetrics = @{}
    HealthScore = 0
    PreviousHealthScore = 0
    HealthImprovement = 0
    Issues = @()
    Recommendations = @()
    NextCheckScheduled = $false
    HealthClinicReported = $false
    Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    ValidationDetails = @{}
}

function Write-LogEntry {
    param(
        [string]$Message,
        [string]$Level = "Information",
        [int]$EventId = 3000
    )
    
    $LogLevel = switch ($Level) {
        "Error" { "Error"; $EventId = 3001 }
        "Warning" { "Warning"; $EventId = 3002 }
        "Information" { "Information"; $EventId = 3000 }
        default { "Information"; $EventId = 3000 }
    }
    
    try {
        Write-EventLog -LogName $LogName -Source $LogSource -EntryType $LogLevel -EventId $EventId -Message $Message -ErrorAction SilentlyContinue
    } catch {
        # Fallback to console output if event logging fails
    }
    
    if ($VerboseOutput) {
        Write-Host "[$Level] $Message" -ForegroundColor $(
            switch ($Level) {
                "Error" { "Red" }
                "Warning" { "Yellow" }
                default { "Cyan" }
            }
        )
    }
}

function Get-BaselineHealthScore {
    try {
        Write-LogEntry "Retrieving baseline health score from detection results"
        
        $BaselineFile = "$env:TEMP\SysTrack_GPO_UserDetection_Results.json"
        if (Test-Path $BaselineFile) {
            $BaselineData = Get-Content $BaselineFile -Raw | ConvertFrom-Json -ErrorAction SilentlyContinue
            if ($BaselineData -and $BaselineData.HealthScore) {
                $FollowUpResults.PreviousHealthScore = $BaselineData.HealthScore
                Write-LogEntry "Previous health score retrieved: $($BaselineData.HealthScore)%"
                return $BaselineData.HealthScore
            }
        }
        
        Write-LogEntry "No baseline health score available" "Warning"
        return 0
        
    } catch {
        Write-LogEntry "Failed to retrieve baseline health score: $(<#
.SCRIPT NAME
		FollowUp_Windows_GPO_UpdateUser.ps1
    
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
		Windows Group Policy update and refresh operations. Post-remediation validation and verification.

.INPUTS
{Optional | Required} commandline argument{s} to the .bat script that is followed by a value {string/int} for the Assign Commandline Args Parameters section in script below.  
    If arguments are not provided, then the script should typically assign a default value in the Parameter section.  The -Simulate argument is a SWITCH object, which means if it is included on the runtime commandline arguments, then the script $Simulate will automatically be set to $TRUE and if it is omitted from the arguments then it will be set to $FALSE.  The -Simulate should NOT have any value tied to it, i.e. -Simulate "Yes"... just standalone -Simulate.
    ALERT: the -Arg1 is a SAMPLE and should be renamed to required variable name or deleted if not being used.
        
    -Arg1 10
    -Simulate     (Do NOT include any argument 'value' string for the -Simulate because it is a type SWITCH)
  

.OUTPUTS
	When enabled, a log file will be created in the same folder the script has been copied to by the SysTrack Cloud
    i.e. "C:\Program Files (x86)\SysTrack\LsiAgent\CMD\...
    This script will perform the following: 
    
    Provide psuedo code description of how the script works


.NOTES
	Version:      1.x (BE SURE TO CHANGE VERSION FOR VARIABLE BELOW e.g. $ScriptVersion = "1.3")
	Company:      CompuCom
    Author:       
    Contact:      Stan.Turner@compucom.com
	Requirements: This script assumed to be run by the SysTrack agent which will either use the Local System or User account depending on how the Automation Profile is configured in SysTrack console.
	Changes:      2025/07/08 v1.0 SysTrack Automation Team 
                  - Initial Release - Post-remediation validation and verification

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
### ALERT: This section must be modified to match the commandline named args or it will use below default values.
###        If the commandline args are not being used, then this will assign below and can be ignored (not used in main code).

param(
    
    [Parameter(Mandatory = $false,
    [switch]$Simulate,
    [int]$TempArg = 60   ### DELETE THIS IF NOT BEING USED ###
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
        LogWrite "#####################################       Exiting Script:  [$ScriptBaseName] Return Code: [$code]"
        LogWrite "#####################################       End Time:        [$ScriptEndTime]"
        LogWrite "#####################################       Script Run Time: [$formattedRunTime]"
        LogWrite "####################################################################################################"
        LogWrite "."
        LogWrite "."
        Exit($code)
    }   


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
    }
    else {
        ExitScript -msg "Module Import:    [Error] Load failure - File Missing [$($ModuleFilePath)]." -code -1
    }
    LogWrite "Module Import:    [Successful]"
}
catch {
    LogWrite "Module Import:    [Error] Module [$($ModuleFilePath)] failed due to load error.  Please review ErrorMsg to fix the module problem. ErrorMsg: $_"
    ExitScript -msg "Function Module File [$ModuleFilePath] Load Failure, exiting script now." -code -1
}

# Log all the Environment Information
Get-Environment_Info

###############################################
### ALERT: REMOVE THE BELOW COMMENT START '<#' AND COMMENT END '#>' 
###        LINES WHEN USING COMMANDLINE ARGUMENT FEATURES
###############################################

#<#
# Log input from commandline arguments.  Remove $TempArg line if this is not being used or rename to usage name.
LogWrite "Runtime value for -TempArg:  $TempArg"
LogWrite "Runtime value for -Simulate: $Simulate"

# Log the .bat commandline arguments for TempArg and runtime Simulate.
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










####################################
# End Main Script
####################################


####################################
# Exit Script
####################################

#NOTE: You MUST assign a value to $returnCode prior to the next statement based on script resutls.
ExitScript -msg "Script Completed" -code $returnCode.Exception.Message)" "Warning"
        return 0
    }
}

function Test-UserPolicyApplication {
    try {
        Write-LogEntry "Validating user Group Policy application and effectiveness"
        
        $PolicyValidation = @{
            PolicyAppliedRecently = $false
            PolicyAge = 0
            UserRegistryConsistent = $false
            PolicyProcessingSuccessful = $false
            EffectivePoliciesCount = 0
            LastApplicationTime = $null
            ProcessingErrors = @()
        }
        
        # Check recent policy application
        try {
            $PolicyHistoryPath = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Group Policy\History"
            if (Test-Path $PolicyHistoryPath) {
                $PolicyEntries = Get-ChildItem $PolicyHistoryPath -ErrorAction SilentlyContinue
                if ($PolicyEntries) {
                    $LatestPolicy = $PolicyEntries | Sort-Object LastWriteTime -Descending | Select-Object -First 1
                    $PolicyValidation.LastApplicationTime = $LatestPolicy.LastWriteTime
                    $PolicyValidation.PolicyAge = ((Get-Date) - $LatestPolicy.LastWriteTime).TotalMinutes
                    $PolicyValidation.PolicyAppliedRecently = ($PolicyValidation.PolicyAge -lt 60)  # Within last hour
                    
                    Write-LogEntry "Last user policy application: $($LatestPolicy.LastWriteTime) ($([math]::Round($PolicyValidation.PolicyAge, 1)) minutes ago)"
                }
            }
        } catch {
            Write-LogEntry "Unable to verify policy application time" "Warning"
        }
        
        # Validate user registry consistency
        try {
            $UserPolicyPaths = @(
                "HKCU:\SOFTWARE\Policies\Microsoft\Windows",
                "HKCU:\SOFTWARE\Policies\Microsoft\Office",
                "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies"
            )
            
            $ConsistentPaths = 0
            foreach ($Path in $UserPolicyPaths) {
                if (Test-Path $Path) {
                    $PathKey = Get-Item $Path -ErrorAction SilentlyContinue
                    if ($PathKey -and $PathKey.LastWriteTime -gt (Get-Date).AddHours(-2)) {
                        $ConsistentPaths++
                    }
                }
            }
            
            $PolicyValidation.UserRegistryConsistent = ($ConsistentPaths -gt 0)
            Write-LogEntry "User policy registry consistency check: $ConsistentPaths paths updated recently"
            
        } catch {
            Write-LogEntry "User registry consistency check failed" "Warning"
        }
        
        # Check for policy processing success
        try {
            $PolicyEvents = Get-WinEvent -FilterHashtable @{
                LogName = 'System'
                Id = 1000, 1001, 1085, 1125, 1127
                StartTime = (Get-Date).AddHours(-2)
            } -ErrorAction SilentlyContinue | Where-Object { <#
.SCRIPT NAME
		FollowUp_Windows_GPO_UpdateUser.ps1
    
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
		Windows Group Policy update and refresh operations. Post-remediation validation and verification.

.INPUTS
{Optional | Required} commandline argument{s} to the .bat script that is followed by a value {string/int} for the Assign Commandline Args Parameters section in script below.  
    If arguments are not provided, then the script should typically assign a default value in the Parameter section.  The -Simulate argument is a SWITCH object, which means if it is included on the runtime commandline arguments, then the script $Simulate will automatically be set to $TRUE and if it is omitted from the arguments then it will be set to $FALSE.  The -Simulate should NOT have any value tied to it, i.e. -Simulate "Yes"... just standalone -Simulate.
    ALERT: the -Arg1 is a SAMPLE and should be renamed to required variable name or deleted if not being used.
        
    -Arg1 10
    -Simulate     (Do NOT include any argument 'value' string for the -Simulate because it is a type SWITCH)
  

.OUTPUTS
	When enabled, a log file will be created in the same folder the script has been copied to by the SysTrack Cloud
    i.e. "C:\Program Files (x86)\SysTrack\LsiAgent\CMD\...
    This script will perform the following: 
    
    Provide psuedo code description of how the script works


.NOTES
	Version:      1.x (BE SURE TO CHANGE VERSION FOR VARIABLE BELOW e.g. $ScriptVersion = "1.3")
	Company:      CompuCom
    Author:       
    Contact:      Stan.Turner@compucom.com
	Requirements: This script assumed to be run by the SysTrack agent which will either use the Local System or User account depending on how the Automation Profile is configured in SysTrack console.
	Changes:      2025/07/08 v1.0 SysTrack Automation Team 
                  - Initial Release - Post-remediation validation and verification

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
### ALERT: This section must be modified to match the commandline named args or it will use below default values.
###        If the commandline args are not being used, then this will assign below and can be ignored (not used in main code).

param(
    
    [Parameter(Mandatory = $false,
    [switch]$Simulate,
    [int]$TempArg = 60   ### DELETE THIS IF NOT BEING USED ###
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
        LogWrite "#####################################       Exiting Script:  [$ScriptBaseName] Return Code: [$code]"
        LogWrite "#####################################       End Time:        [$ScriptEndTime]"
        LogWrite "#####################################       Script Run Time: [$formattedRunTime]"
        LogWrite "####################################################################################################"
        LogWrite "."
        LogWrite "."
        Exit($code)
    }   


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
    }
    else {
        ExitScript -msg "Module Import:    [Error] Load failure - File Missing [$($ModuleFilePath)]." -code -1
    }
    LogWrite "Module Import:    [Successful]"
}
catch {
    LogWrite "Module Import:    [Error] Module [$($ModuleFilePath)] failed due to load error.  Please review ErrorMsg to fix the module problem. ErrorMsg: $_"
    ExitScript -msg "Function Module File [$ModuleFilePath] Load Failure, exiting script now." -code -1
}

# Log all the Environment Information
Get-Environment_Info

###############################################
### ALERT: REMOVE THE BELOW COMMENT START '<#' AND COMMENT END '#>' 
###        LINES WHEN USING COMMANDLINE ARGUMENT FEATURES
###############################################

#<#
# Log input from commandline arguments.  Remove $TempArg line if this is not being used or rename to usage name.
LogWrite "Runtime value for -TempArg:  $TempArg"
LogWrite "Runtime value for -Simulate: $Simulate"

# Log the .bat commandline arguments for TempArg and runtime Simulate.
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










####################################
# End Main Script
####################################


####################################
# Exit Script
####################################

#NOTE: You MUST assign a value to $returnCode prior to the next statement based on script resutls.
ExitScript -msg "Script Completed" -code $returnCode.Message -match "user" -and <#
.SCRIPT NAME
		FollowUp_Windows_GPO_UpdateUser.ps1
    
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
		Windows Group Policy update and refresh operations. Post-remediation validation and verification.

.INPUTS
{Optional | Required} commandline argument{s} to the .bat script that is followed by a value {string/int} for the Assign Commandline Args Parameters section in script below.  
    If arguments are not provided, then the script should typically assign a default value in the Parameter section.  The -Simulate argument is a SWITCH object, which means if it is included on the runtime commandline arguments, then the script $Simulate will automatically be set to $TRUE and if it is omitted from the arguments then it will be set to $FALSE.  The -Simulate should NOT have any value tied to it, i.e. -Simulate "Yes"... just standalone -Simulate.
    ALERT: the -Arg1 is a SAMPLE and should be renamed to required variable name or deleted if not being used.
        
    -Arg1 10
    -Simulate     (Do NOT include any argument 'value' string for the -Simulate because it is a type SWITCH)
  

.OUTPUTS
	When enabled, a log file will be created in the same folder the script has been copied to by the SysTrack Cloud
    i.e. "C:\Program Files (x86)\SysTrack\LsiAgent\CMD\...
    This script will perform the following: 
    
    Provide psuedo code description of how the script works


.NOTES
	Version:      1.x (BE SURE TO CHANGE VERSION FOR VARIABLE BELOW e.g. $ScriptVersion = "1.3")
	Company:      CompuCom
    Author:       
    Contact:      Stan.Turner@compucom.com
	Requirements: This script assumed to be run by the SysTrack agent which will either use the Local System or User account depending on how the Automation Profile is configured in SysTrack console.
	Changes:      2025/07/08 v1.0 SysTrack Automation Team 
                  - Initial Release - Post-remediation validation and verification

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
### ALERT: This section must be modified to match the commandline named args or it will use below default values.
###        If the commandline args are not being used, then this will assign below and can be ignored (not used in main code).

param(
    
    [Parameter(Mandatory = $false,
    [switch]$Simulate,
    [int]$TempArg = 60   ### DELETE THIS IF NOT BEING USED ###
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
        LogWrite "#####################################       Exiting Script:  [$ScriptBaseName] Return Code: [$code]"
        LogWrite "#####################################       End Time:        [$ScriptEndTime]"
        LogWrite "#####################################       Script Run Time: [$formattedRunTime]"
        LogWrite "####################################################################################################"
        LogWrite "."
        LogWrite "."
        Exit($code)
    }   


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
    }
    else {
        ExitScript -msg "Module Import:    [Error] Load failure - File Missing [$($ModuleFilePath)]." -code -1
    }
    LogWrite "Module Import:    [Successful]"
}
catch {
    LogWrite "Module Import:    [Error] Module [$($ModuleFilePath)] failed due to load error.  Please review ErrorMsg to fix the module problem. ErrorMsg: $_"
    ExitScript -msg "Function Module File [$ModuleFilePath] Load Failure, exiting script now." -code -1
}

# Log all the Environment Information
Get-Environment_Info

###############################################
### ALERT: REMOVE THE BELOW COMMENT START '<#' AND COMMENT END '#>' 
###        LINES WHEN USING COMMANDLINE ARGUMENT FEATURES
###############################################

#<#
# Log input from commandline arguments.  Remove $TempArg line if this is not being used or rename to usage name.
LogWrite "Runtime value for -TempArg:  $TempArg"
LogWrite "Runtime value for -Simulate: $Simulate"

# Log the .bat commandline arguments for TempArg and runtime Simulate.
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










####################################
# End Main Script
####################################


####################################
# Exit Script
####################################

#NOTE: You MUST assign a value to $returnCode prior to the next statement based on script resutls.
ExitScript -msg "Script Completed" -code $returnCode.Message -match "policy" }
            
            $SuccessEvents = $PolicyEvents | Where-Object { <#
.SCRIPT NAME
		FollowUp_Windows_GPO_UpdateUser.ps1
    
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
		Windows Group Policy update and refresh operations. Post-remediation validation and verification.

.INPUTS
{Optional | Required} commandline argument{s} to the .bat script that is followed by a value {string/int} for the Assign Commandline Args Parameters section in script below.  
    If arguments are not provided, then the script should typically assign a default value in the Parameter section.  The -Simulate argument is a SWITCH object, which means if it is included on the runtime commandline arguments, then the script $Simulate will automatically be set to $TRUE and if it is omitted from the arguments then it will be set to $FALSE.  The -Simulate should NOT have any value tied to it, i.e. -Simulate "Yes"... just standalone -Simulate.
    ALERT: the -Arg1 is a SAMPLE and should be renamed to required variable name or deleted if not being used.
        
    -Arg1 10
    -Simulate     (Do NOT include any argument 'value' string for the -Simulate because it is a type SWITCH)
  

.OUTPUTS
	When enabled, a log file will be created in the same folder the script has been copied to by the SysTrack Cloud
    i.e. "C:\Program Files (x86)\SysTrack\LsiAgent\CMD\...
    This script will perform the following: 
    
    Provide psuedo code description of how the script works


.NOTES
	Version:      1.x (BE SURE TO CHANGE VERSION FOR VARIABLE BELOW e.g. $ScriptVersion = "1.3")
	Company:      CompuCom
    Author:       
    Contact:      Stan.Turner@compucom.com
	Requirements: This script assumed to be run by the SysTrack agent which will either use the Local System or User account depending on how the Automation Profile is configured in SysTrack console.
	Changes:      2025/07/08 v1.0 SysTrack Automation Team 
                  - Initial Release - Post-remediation validation and verification

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
### ALERT: This section must be modified to match the commandline named args or it will use below default values.
###        If the commandline args are not being used, then this will assign below and can be ignored (not used in main code).

param(
    
    [Parameter(Mandatory = $false,
    [switch]$Simulate,
    [int]$TempArg = 60   ### DELETE THIS IF NOT BEING USED ###
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
        LogWrite "#####################################       Exiting Script:  [$ScriptBaseName] Return Code: [$code]"
        LogWrite "#####################################       End Time:        [$ScriptEndTime]"
        LogWrite "#####################################       Script Run Time: [$formattedRunTime]"
        LogWrite "####################################################################################################"
        LogWrite "."
        LogWrite "."
        Exit($code)
    }   


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
    }
    else {
        ExitScript -msg "Module Import:    [Error] Load failure - File Missing [$($ModuleFilePath)]." -code -1
    }
    LogWrite "Module Import:    [Successful]"
}
catch {
    LogWrite "Module Import:    [Error] Module [$($ModuleFilePath)] failed due to load error.  Please review ErrorMsg to fix the module problem. ErrorMsg: $_"
    ExitScript -msg "Function Module File [$ModuleFilePath] Load Failure, exiting script now." -code -1
}

# Log all the Environment Information
Get-Environment_Info

###############################################
### ALERT: REMOVE THE BELOW COMMENT START '<#' AND COMMENT END '#>' 
###        LINES WHEN USING COMMANDLINE ARGUMENT FEATURES
###############################################

#<#
# Log input from commandline arguments.  Remove $TempArg line if this is not being used or rename to usage name.
LogWrite "Runtime value for -TempArg:  $TempArg"
LogWrite "Runtime value for -Simulate: $Simulate"

# Log the .bat commandline arguments for TempArg and runtime Simulate.
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










####################################
# End Main Script
####################################


####################################
# Exit Script
####################################

#NOTE: You MUST assign a value to $returnCode prior to the next statement based on script resutls.
ExitScript -msg "Script Completed" -code $returnCode.Id -eq 1000 }
            $ErrorEvents = $PolicyEvents | Where-Object { <#
.SCRIPT NAME
		FollowUp_Windows_GPO_UpdateUser.ps1
    
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
		Windows Group Policy update and refresh operations. Post-remediation validation and verification.

.INPUTS
{Optional | Required} commandline argument{s} to the .bat script that is followed by a value {string/int} for the Assign Commandline Args Parameters section in script below.  
    If arguments are not provided, then the script should typically assign a default value in the Parameter section.  The -Simulate argument is a SWITCH object, which means if it is included on the runtime commandline arguments, then the script $Simulate will automatically be set to $TRUE and if it is omitted from the arguments then it will be set to $FALSE.  The -Simulate should NOT have any value tied to it, i.e. -Simulate "Yes"... just standalone -Simulate.
    ALERT: the -Arg1 is a SAMPLE and should be renamed to required variable name or deleted if not being used.
        
    -Arg1 10
    -Simulate     (Do NOT include any argument 'value' string for the -Simulate because it is a type SWITCH)
  

.OUTPUTS
	When enabled, a log file will be created in the same folder the script has been copied to by the SysTrack Cloud
    i.e. "C:\Program Files (x86)\SysTrack\LsiAgent\CMD\...
    This script will perform the following: 
    
    Provide psuedo code description of how the script works


.NOTES
	Version:      1.x (BE SURE TO CHANGE VERSION FOR VARIABLE BELOW e.g. $ScriptVersion = "1.3")
	Company:      CompuCom
    Author:       
    Contact:      Stan.Turner@compucom.com
	Requirements: This script assumed to be run by the SysTrack agent which will either use the Local System or User account depending on how the Automation Profile is configured in SysTrack console.
	Changes:      2025/07/08 v1.0 SysTrack Automation Team 
                  - Initial Release - Post-remediation validation and verification

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
### ALERT: This section must be modified to match the commandline named args or it will use below default values.
###        If the commandline args are not being used, then this will assign below and can be ignored (not used in main code).

param(
    
    [Parameter(Mandatory = $false,
    [switch]$Simulate,
    [int]$TempArg = 60   ### DELETE THIS IF NOT BEING USED ###
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
        LogWrite "#####################################       Exiting Script:  [$ScriptBaseName] Return Code: [$code]"
        LogWrite "#####################################       End Time:        [$ScriptEndTime]"
        LogWrite "#####################################       Script Run Time: [$formattedRunTime]"
        LogWrite "####################################################################################################"
        LogWrite "."
        LogWrite "."
        Exit($code)
    }   


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
    }
    else {
        ExitScript -msg "Module Import:    [Error] Load failure - File Missing [$($ModuleFilePath)]." -code -1
    }
    LogWrite "Module Import:    [Successful]"
}
catch {
    LogWrite "Module Import:    [Error] Module [$($ModuleFilePath)] failed due to load error.  Please review ErrorMsg to fix the module problem. ErrorMsg: $_"
    ExitScript -msg "Function Module File [$ModuleFilePath] Load Failure, exiting script now." -code -1
}

# Log all the Environment Information
Get-Environment_Info

###############################################
### ALERT: REMOVE THE BELOW COMMENT START '<#' AND COMMENT END '#>' 
###        LINES WHEN USING COMMANDLINE ARGUMENT FEATURES
###############################################

#<#
# Log input from commandline arguments.  Remove $TempArg line if this is not being used or rename to usage name.
LogWrite "Runtime value for -TempArg:  $TempArg"
LogWrite "Runtime value for -Simulate: $Simulate"

# Log the .bat commandline arguments for TempArg and runtime Simulate.
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










####################################
# End Main Script
####################################


####################################
# Exit Script
####################################

#NOTE: You MUST assign a value to $returnCode prior to the next statement based on script resutls.
ExitScript -msg "Script Completed" -code $returnCode.Id -in @(1001, 1085) }
            
            $PolicyValidation.PolicyProcessingSuccessful = ($SuccessEvents.Count -gt 0 -and $ErrorEvents.Count -eq 0)
            
            foreach ($ErrorEvent in $ErrorEvents) {
                $PolicyValidation.ProcessingErrors += "Event ID $($ErrorEvent.Id): $($ErrorEvent.Message.Substring(0, 100))..."
            }
            
        } catch {
            Write-LogEntry "Unable to analyze policy processing events" "Warning"
        }
        
        # Count effective policies
        try {
            $EffectivePolicyPaths = @(
                "HKCU:\SOFTWARE\Policies\Microsoft\Windows",
                "HKCU:\SOFTWARE\Policies\Microsoft\Office",
                "HKCU:\SOFTWARE\Policies\Microsoft\Internet Explorer"
            )
            
            foreach ($Path in $EffectivePolicyPaths) {
                if (Test-Path $Path) {
                    $SubKeys = Get-ChildItem $Path -Recurse -ErrorAction SilentlyContinue
                    $PolicyValidation.EffectivePoliciesCount += $SubKeys.Count
                }
            }
            
            Write-LogEntry "Effective user policies detected: $($PolicyValidation.EffectivePoliciesCount)"
            
        } catch {
            Write-LogEntry "Unable to count effective policies" "Warning"
        }
        
        $FollowUpResults.UserPolicyHealth = $PolicyValidation
        
        # Overall policy application validation
        $ValidationPassed = (
            $PolicyValidation.PolicyAppliedRecently -and
            $PolicyValidation.UserRegistryConsistent -and
            $PolicyValidation.PolicyProcessingSuccessful -and
            $PolicyValidation.EffectivePoliciesCount -gt 0
        )
        
        if (-not $ValidationPassed) {
            if (-not $PolicyValidation.PolicyAppliedRecently) {
                $FollowUpResults.Issues += "User Group Policy not applied recently (age: $([math]::Round($PolicyValidation.PolicyAge, 1)) minutes)"
            }
            if (-not $PolicyValidation.UserRegistryConsistent) {
                $FollowUpResults.Issues += "User policy registry inconsistencies detected"
            }
            if (-not $PolicyValidation.PolicyProcessingSuccessful) {
                $FollowUpResults.Issues += "User policy processing errors: $($PolicyValidation.ProcessingErrors.Count)"
            }
            if ($PolicyValidation.EffectivePoliciesCount -eq 0) {
                $FollowUpResults.Issues += "No effective user policies detected in registry"
            }
        }
        
        return $ValidationPassed
        
    } catch {
        $ErrorMessage = "User policy application validation failed: $(<#
.SCRIPT NAME
		FollowUp_Windows_GPO_UpdateUser.ps1
    
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
		Windows Group Policy update and refresh operations. Post-remediation validation and verification.

.INPUTS
{Optional | Required} commandline argument{s} to the .bat script that is followed by a value {string/int} for the Assign Commandline Args Parameters section in script below.  
    If arguments are not provided, then the script should typically assign a default value in the Parameter section.  The -Simulate argument is a SWITCH object, which means if it is included on the runtime commandline arguments, then the script $Simulate will automatically be set to $TRUE and if it is omitted from the arguments then it will be set to $FALSE.  The -Simulate should NOT have any value tied to it, i.e. -Simulate "Yes"... just standalone -Simulate.
    ALERT: the -Arg1 is a SAMPLE and should be renamed to required variable name or deleted if not being used.
        
    -Arg1 10
    -Simulate     (Do NOT include any argument 'value' string for the -Simulate because it is a type SWITCH)
  

.OUTPUTS
	When enabled, a log file will be created in the same folder the script has been copied to by the SysTrack Cloud
    i.e. "C:\Program Files (x86)\SysTrack\LsiAgent\CMD\...
    This script will perform the following: 
    
    Provide psuedo code description of how the script works


.NOTES
	Version:      1.x (BE SURE TO CHANGE VERSION FOR VARIABLE BELOW e.g. $ScriptVersion = "1.3")
	Company:      CompuCom
    Author:       
    Contact:      Stan.Turner@compucom.com
	Requirements: This script assumed to be run by the SysTrack agent which will either use the Local System or User account depending on how the Automation Profile is configured in SysTrack console.
	Changes:      2025/07/08 v1.0 SysTrack Automation Team 
                  - Initial Release - Post-remediation validation and verification

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
### ALERT: This section must be modified to match the commandline named args or it will use below default values.
###        If the commandline args are not being used, then this will assign below and can be ignored (not used in main code).

param(
    
    [Parameter(Mandatory = $false,
    [switch]$Simulate,
    [int]$TempArg = 60   ### DELETE THIS IF NOT BEING USED ###
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
        LogWrite "#####################################       Exiting Script:  [$ScriptBaseName] Return Code: [$code]"
        LogWrite "#####################################       End Time:        [$ScriptEndTime]"
        LogWrite "#####################################       Script Run Time: [$formattedRunTime]"
        LogWrite "####################################################################################################"
        LogWrite "."
        LogWrite "."
        Exit($code)
    }   


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
    }
    else {
        ExitScript -msg "Module Import:    [Error] Load failure - File Missing [$($ModuleFilePath)]." -code -1
    }
    LogWrite "Module Import:    [Successful]"
}
catch {
    LogWrite "Module Import:    [Error] Module [$($ModuleFilePath)] failed due to load error.  Please review ErrorMsg to fix the module problem. ErrorMsg: $_"
    ExitScript -msg "Function Module File [$ModuleFilePath] Load Failure, exiting script now." -code -1
}

# Log all the Environment Information
Get-Environment_Info

###############################################
### ALERT: REMOVE THE BELOW COMMENT START '<#' AND COMMENT END '#>' 
###        LINES WHEN USING COMMANDLINE ARGUMENT FEATURES
###############################################

#<#
# Log input from commandline arguments.  Remove $TempArg line if this is not being used or rename to usage name.
LogWrite "Runtime value for -TempArg:  $TempArg"
LogWrite "Runtime value for -Simulate: $Simulate"

# Log the .bat commandline arguments for TempArg and runtime Simulate.
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










####################################
# End Main Script
####################################


####################################
# Exit Script
####################################

#NOTE: You MUST assign a value to $returnCode prior to the next statement based on script resutls.
ExitScript -msg "Script Completed" -code $returnCode.Exception.Message)"
        Write-LogEntry $ErrorMessage "Error"
        $FollowUpResults.Issues += $ErrorMessage
        return $false
    }
}

function Test-UserSystemHealth {
    try {
        Write-LogEntry "Assessing user system health post-policy refresh"
        
        $SystemHealth = @{
            UserProfileHealthy = $false
            RegistryHealthScore = 0
            ServicesDependenciesHealthy = $false
            SessionStable = $false
            PerformanceImpact = $false
            HealthFactors = @{}
        }
        
        # User profile health
        try {
            if (Test-Path $env:USERPROFILE) {
                $ProfileTest = Join-Path $env:USERPROFILE "SysTrack_HealthTest.tmp"
                $null = New-Item -Path $ProfileTest -ItemType File -Force -ErrorAction Stop
                $FileWriteTime = (Get-Item $ProfileTest).CreationTime
                Remove-Item -Path $ProfileTest -Force -ErrorAction SilentlyContinue
                
                $SystemHealth.UserProfileHealthy = $true
                Write-LogEntry "User profile health check passed"
            }
        } catch {
            $FollowUpResults.Issues += "User profile accessibility issues detected"
        }
        
        # Registry health assessment
        try {
            $RegistryTestKeys = @(
                "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Group Policy",
                "HKCU:\SOFTWARE\Policies",
                "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies"
            )
            
            $HealthyKeys = 0
            foreach ($Key in $RegistryTestKeys) {
                if (Test-Path $Key) {
                    try {
                        $TestValue = "SysTrack_Test_$(Get-Random)"
                        Set-ItemProperty -Path $Key -Name "SysTrack_HealthTest" -Value $TestValue -ErrorAction Stop
                        $RetrievedValue = Get-ItemProperty -Path $Key -Name "SysTrack_HealthTest" -ErrorAction Stop
                        Remove-ItemProperty -Path $Key -Name "SysTrack_HealthTest" -ErrorAction SilentlyContinue
                        
                        if ($RetrievedValue.SysTrack_HealthTest -eq $TestValue) {
                            $HealthyKeys++
                        }
                    } catch {
                        Write-LogEntry "Registry health test failed for key: $Key" "Warning"
                    }
                }
            }
            
            $SystemHealth.RegistryHealthScore = [math]::Round(($HealthyKeys / $RegistryTestKeys.Count) * 100)
            Write-LogEntry "User registry health score: $($SystemHealth.RegistryHealthScore)%"
            
        } catch {
            Write-LogEntry "Registry health assessment failed" "Warning"
        }
        
        # Service dependencies health
        try {
            $CriticalServices = @("gpsvc", "Winmgmt", "EventLog")
            $HealthyServices = 0
            
            foreach ($ServiceName in $CriticalServices) {
                $Service = Get-Service -Name $ServiceName -ErrorAction SilentlyContinue
                if ($Service -and $Service.Status -eq "Running") {
                    $HealthyServices++
                }
            }
            
            $SystemHealth.ServicesDependenciesHealthy = ($HealthyServices -eq $CriticalServices.Count)
            Write-LogEntry "Critical services health: $HealthyServices of $($CriticalServices.Count) running"
            
        } catch {
            Write-LogEntry "Service dependencies health check failed" "Warning"
        }
        
        # Session stability check
        try {
            $SystemHealth.SessionStable = $true  # Assume stable if we can execute this script
            $UserSession = query user 2>$null
            if ($UserSession -and $UserSession -match "Active") {
                Write-LogEntry "User session stability verified"
            }
        } catch {
            Write-LogEntry "Session stability check warning" "Warning"
        }
        
        $FollowUpResults.ValidationDetails.SystemHealth = $SystemHealth
        
        return ($SystemHealth.UserProfileHealthy -and 
                $SystemHealth.RegistryHealthScore -gt 66 -and 
                $SystemHealth.ServicesDependenciesHealthy -and 
                $SystemHealth.SessionStable)
        
    } catch {
        $ErrorMessage = "User system health assessment failed: $(<#
.SCRIPT NAME
		FollowUp_Windows_GPO_UpdateUser.ps1
    
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
		Windows Group Policy update and refresh operations. Post-remediation validation and verification.

.INPUTS
{Optional | Required} commandline argument{s} to the .bat script that is followed by a value {string/int} for the Assign Commandline Args Parameters section in script below.  
    If arguments are not provided, then the script should typically assign a default value in the Parameter section.  The -Simulate argument is a SWITCH object, which means if it is included on the runtime commandline arguments, then the script $Simulate will automatically be set to $TRUE and if it is omitted from the arguments then it will be set to $FALSE.  The -Simulate should NOT have any value tied to it, i.e. -Simulate "Yes"... just standalone -Simulate.
    ALERT: the -Arg1 is a SAMPLE and should be renamed to required variable name or deleted if not being used.
        
    -Arg1 10
    -Simulate     (Do NOT include any argument 'value' string for the -Simulate because it is a type SWITCH)
  

.OUTPUTS
	When enabled, a log file will be created in the same folder the script has been copied to by the SysTrack Cloud
    i.e. "C:\Program Files (x86)\SysTrack\LsiAgent\CMD\...
    This script will perform the following: 
    
    Provide psuedo code description of how the script works


.NOTES
	Version:      1.x (BE SURE TO CHANGE VERSION FOR VARIABLE BELOW e.g. $ScriptVersion = "1.3")
	Company:      CompuCom
    Author:       
    Contact:      Stan.Turner@compucom.com
	Requirements: This script assumed to be run by the SysTrack agent which will either use the Local System or User account depending on how the Automation Profile is configured in SysTrack console.
	Changes:      2025/07/08 v1.0 SysTrack Automation Team 
                  - Initial Release - Post-remediation validation and verification

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
### ALERT: This section must be modified to match the commandline named args or it will use below default values.
###        If the commandline args are not being used, then this will assign below and can be ignored (not used in main code).

param(
    
    [Parameter(Mandatory = $false,
    [switch]$Simulate,
    [int]$TempArg = 60   ### DELETE THIS IF NOT BEING USED ###
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
        LogWrite "#####################################       Exiting Script:  [$ScriptBaseName] Return Code: [$code]"
        LogWrite "#####################################       End Time:        [$ScriptEndTime]"
        LogWrite "#####################################       Script Run Time: [$formattedRunTime]"
        LogWrite "####################################################################################################"
        LogWrite "."
        LogWrite "."
        Exit($code)
    }   


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
    }
    else {
        ExitScript -msg "Module Import:    [Error] Load failure - File Missing [$($ModuleFilePath)]." -code -1
    }
    LogWrite "Module Import:    [Successful]"
}
catch {
    LogWrite "Module Import:    [Error] Module [$($ModuleFilePath)] failed due to load error.  Please review ErrorMsg to fix the module problem. ErrorMsg: $_"
    ExitScript -msg "Function Module File [$ModuleFilePath] Load Failure, exiting script now." -code -1
}

# Log all the Environment Information
Get-Environment_Info

###############################################
### ALERT: REMOVE THE BELOW COMMENT START '<#' AND COMMENT END '#>' 
###        LINES WHEN USING COMMANDLINE ARGUMENT FEATURES
###############################################

#<#
# Log input from commandline arguments.  Remove $TempArg line if this is not being used or rename to usage name.
LogWrite "Runtime value for -TempArg:  $TempArg"
LogWrite "Runtime value for -Simulate: $Simulate"

# Log the .bat commandline arguments for TempArg and runtime Simulate.
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










####################################
# End Main Script
####################################


####################################
# Exit Script
####################################

#NOTE: You MUST assign a value to $returnCode prior to the next statement based on script resutls.
ExitScript -msg "Script Completed" -code $returnCode.Exception.Message)"
        Write-LogEntry $ErrorMessage "Error"
        $FollowUpResults.Issues += $ErrorMessage
        return $false
    }
}

function Measure-PerformanceImpact {
    try {
        Write-LogEntry "Measuring performance impact of user Group Policy refresh"
        
        $PerformanceMetrics = @{
            PolicyProcessingTime = 0
            UserLoginImpact = "None"
            RegistryOperationsTime = 0
            OverallImpactLevel = "Low"
            PerformanceScore = 100
            Recommendations = @()
        }
        
        # Analyze recent remediation results for timing data
        try {
            $RemediationFile = "$env:TEMP\SysTrack_GPO_UserRemediation_Results.json"
            if (Test-Path $RemediationFile) {
                $RemediationData = Get-Content $RemediationFile -Raw | ConvertFrom-Json -ErrorAction SilentlyContinue
                if ($RemediationData -and $RemediationData.PerformanceMetrics) {
                    $PerformanceMetrics.PolicyProcessingTime = $RemediationData.PerformanceMetrics.PolicyRefreshDuration
                    Write-LogEntry "Policy refresh duration: $($PerformanceMetrics.PolicyProcessingTime) seconds"
                }
            }
        } catch {
            Write-LogEntry "Unable to retrieve remediation performance data" "Warning"
        }
        
        # Measure current registry operation performance
        try {
            $RegistryStartTime = Get-Date
            $TestKey = "HKCU:\SOFTWARE\SysTrack_Performance_Test"
            $null = New-Item -Path $TestKey -Force -ErrorAction Stop
            Set-ItemProperty -Path $TestKey -Name "TestValue" -Value "PerformanceTest" -ErrorAction Stop
            $null = Get-ItemProperty -Path $TestKey -Name "TestValue" -ErrorAction Stop
            Remove-Item -Path $TestKey -Force -ErrorAction SilentlyContinue
            
            $PerformanceMetrics.RegistryOperationsTime = ((Get-Date) - $RegistryStartTime).TotalMilliseconds
            Write-LogEntry "Registry operations time: $([math]::Round($PerformanceMetrics.RegistryOperationsTime, 2)) ms"
            
        } catch {
            Write-LogEntry "Registry performance measurement failed" "Warning"
        }
        
        # Determine overall impact level
        if ($PerformanceMetrics.PolicyProcessingTime -gt 120) {
            $PerformanceMetrics.OverallImpactLevel = "High"
            $PerformanceMetrics.PerformanceScore = 60
            $PerformanceMetrics.Recommendations += "Consider policy optimization to reduce processing time"
            $FollowUpResults.Issues += "High policy processing time detected: $($PerformanceMetrics.PolicyProcessingTime) seconds"
        } elseif ($PerformanceMetrics.PolicyProcessingTime -gt 60) {
            $PerformanceMetrics.OverallImpactLevel = "Medium"
            $PerformanceMetrics.PerformanceScore = 80
            $PerformanceMetrics.Recommendations += "Monitor policy processing times for optimization opportunities"
        } else {
            $PerformanceMetrics.OverallImpactLevel = "Low"
            $PerformanceMetrics.PerformanceScore = 100
        }
        
        if ($PerformanceMetrics.RegistryOperationsTime -gt 1000) {
            $PerformanceMetrics.Recommendations += "Registry performance may be degraded - consider registry maintenance"
            $PerformanceMetrics.PerformanceScore -= 10
        }
        
        $FollowUpResults.PerformanceImpact = $PerformanceMetrics
        
        Write-LogEntry "Performance impact assessment completed - Impact Level: $($PerformanceMetrics.OverallImpactLevel), Score: $($PerformanceMetrics.PerformanceScore)"
        return ($PerformanceMetrics.OverallImpactLevel -ne "High")
        
    } catch {
        $ErrorMessage = "Performance impact measurement failed: $(<#
.SCRIPT NAME
		FollowUp_Windows_GPO_UpdateUser.ps1
    
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
		Windows Group Policy update and refresh operations. Post-remediation validation and verification.

.INPUTS
{Optional | Required} commandline argument{s} to the .bat script that is followed by a value {string/int} for the Assign Commandline Args Parameters section in script below.  
    If arguments are not provided, then the script should typically assign a default value in the Parameter section.  The -Simulate argument is a SWITCH object, which means if it is included on the runtime commandline arguments, then the script $Simulate will automatically be set to $TRUE and if it is omitted from the arguments then it will be set to $FALSE.  The -Simulate should NOT have any value tied to it, i.e. -Simulate "Yes"... just standalone -Simulate.
    ALERT: the -Arg1 is a SAMPLE and should be renamed to required variable name or deleted if not being used.
        
    -Arg1 10
    -Simulate     (Do NOT include any argument 'value' string for the -Simulate because it is a type SWITCH)
  

.OUTPUTS
	When enabled, a log file will be created in the same folder the script has been copied to by the SysTrack Cloud
    i.e. "C:\Program Files (x86)\SysTrack\LsiAgent\CMD\...
    This script will perform the following: 
    
    Provide psuedo code description of how the script works


.NOTES
	Version:      1.x (BE SURE TO CHANGE VERSION FOR VARIABLE BELOW e.g. $ScriptVersion = "1.3")
	Company:      CompuCom
    Author:       
    Contact:      Stan.Turner@compucom.com
	Requirements: This script assumed to be run by the SysTrack agent which will either use the Local System or User account depending on how the Automation Profile is configured in SysTrack console.
	Changes:      2025/07/08 v1.0 SysTrack Automation Team 
                  - Initial Release - Post-remediation validation and verification

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
### ALERT: This section must be modified to match the commandline named args or it will use below default values.
###        If the commandline args are not being used, then this will assign below and can be ignored (not used in main code).

param(
    
    [Parameter(Mandatory = $false,
    [switch]$Simulate,
    [int]$TempArg = 60   ### DELETE THIS IF NOT BEING USED ###
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
        LogWrite "#####################################       Exiting Script:  [$ScriptBaseName] Return Code: [$code]"
        LogWrite "#####################################       End Time:        [$ScriptEndTime]"
        LogWrite "#####################################       Script Run Time: [$formattedRunTime]"
        LogWrite "####################################################################################################"
        LogWrite "."
        LogWrite "."
        Exit($code)
    }   


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
    }
    else {
        ExitScript -msg "Module Import:    [Error] Load failure - File Missing [$($ModuleFilePath)]." -code -1
    }
    LogWrite "Module Import:    [Successful]"
}
catch {
    LogWrite "Module Import:    [Error] Module [$($ModuleFilePath)] failed due to load error.  Please review ErrorMsg to fix the module problem. ErrorMsg: $_"
    ExitScript -msg "Function Module File [$ModuleFilePath] Load Failure, exiting script now." -code -1
}

# Log all the Environment Information
Get-Environment_Info

###############################################
### ALERT: REMOVE THE BELOW COMMENT START '<#' AND COMMENT END '#>' 
###        LINES WHEN USING COMMANDLINE ARGUMENT FEATURES
###############################################

#<#
# Log input from commandline arguments.  Remove $TempArg line if this is not being used or rename to usage name.
LogWrite "Runtime value for -TempArg:  $TempArg"
LogWrite "Runtime value for -Simulate: $Simulate"

# Log the .bat commandline arguments for TempArg and runtime Simulate.
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










####################################
# End Main Script
####################################


####################################
# Exit Script
####################################

#NOTE: You MUST assign a value to $returnCode prior to the next statement based on script resutls.
ExitScript -msg "Script Completed" -code $returnCode.Exception.Message)"
        Write-LogEntry $ErrorMessage "Error"
        $FollowUpResults.Issues += $ErrorMessage
        return $true  # Assume acceptable performance if measurement fails
    }
}

function Calculate-ImprovementMetrics {
    try {
        Write-LogEntry "Calculating user Group Policy health improvement metrics"
        
        $ImprovementData = @{
            HealthScoreImprovement = 0
            IssuesResolved = 0
            NewIssuesIntroduced = 0
            PolicyEffectivenessImproved = $false
            UserExperienceImproved = $false
            OverallImprovement = "Unknown"
        }
        
        # Calculate health score improvement
        if ($FollowUpResults.PreviousHealthScore -gt 0) {
            $ImprovementData.HealthScoreImprovement = $FollowUpResults.HealthScore - $FollowUpResults.PreviousHealthScore
            Write-LogEntry "Health score change: $($FollowUpResults.PreviousHealthScore)% -> $($FollowUpResults.HealthScore)% (Change: $($ImprovementData.HealthScoreImprovement)%)"
        }
        
        # Analyze issues resolution
        try {
            $DetectionFile = "$env:TEMP\SysTrack_GPO_UserDetection_Results.json"
            if (Test-Path $DetectionFile) {
                $DetectionData = Get-Content $DetectionFile -Raw | ConvertFrom-Json -ErrorAction SilentlyContinue
                if ($DetectionData -and $DetectionData.Issues) {
                    $PreviousIssues = $DetectionData.Issues.Count
                    $CurrentIssues = $FollowUpResults.Issues.Count
                    
                    $ImprovementData.IssuesResolved = [math]::Max(0, $PreviousIssues - $CurrentIssues)
                    $ImprovementData.NewIssuesIntroduced = [math]::Max(0, $CurrentIssues - $PreviousIssues)
                    
                    Write-LogEntry "Issues analysis: Previous: $PreviousIssues, Current: $CurrentIssues, Resolved: $($ImprovementData.IssuesResolved), New: $($ImprovementData.NewIssuesIntroduced)"
                }
            }
        } catch {
            Write-LogEntry "Unable to analyze issues resolution" "Warning"
        }
        
        # Assess policy effectiveness improvement
        if ($FollowUpResults.UserPolicyHealth.EffectivePoliciesCount -gt 0 -and 
            $FollowUpResults.UserPolicyHealth.PolicyProcessingSuccessful) {
            $ImprovementData.PolicyEffectivenessImproved = $true
        }
        
        # Assess user experience improvement
        if ($FollowUpResults.UserPolicyHealth.PolicyAppliedRecently -and 
            $FollowUpResults.ValidationDetails.SystemHealth.UserProfileHealthy) {
            $ImprovementData.UserExperienceImproved = $true
        }
        
        # Determine overall improvement level
        if ($ImprovementData.HealthScoreImprovement -gt 20 -and $ImprovementData.IssuesResolved -gt 0) {
            $ImprovementData.OverallImprovement = "Significant"
        } elseif ($ImprovementData.HealthScoreImprovement -gt 10 -or $ImprovementData.IssuesResolved -gt 0) {
            $ImprovementData.OverallImprovement = "Moderate"
        } elseif ($ImprovementData.HealthScoreImprovement -gt 0) {
            $ImprovementData.OverallImprovement = "Minor"
        } elseif ($ImprovementData.NewIssuesIntroduced -gt 0) {
            $ImprovementData.OverallImprovement = "Regression"
        } else {
            $ImprovementData.OverallImprovement = "Stable"
        }
        
        $FollowUpResults.ImprovementMetrics = $ImprovementData
        $FollowUpResults.HealthImprovement = $ImprovementData.HealthScoreImprovement
        
        Write-LogEntry "Improvement assessment: $($ImprovementData.OverallImprovement) - Health improvement: $($ImprovementData.HealthScoreImprovement)%"
        
        return ($ImprovementData.OverallImprovement -in @("Significant", "Moderate", "Minor", "Stable"))
        
    } catch {
        $ErrorMessage = "Improvement metrics calculation failed: $(<#
.SCRIPT NAME
		FollowUp_Windows_GPO_UpdateUser.ps1
    
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
		Windows Group Policy update and refresh operations. Post-remediation validation and verification.

.INPUTS
{Optional | Required} commandline argument{s} to the .bat script that is followed by a value {string/int} for the Assign Commandline Args Parameters section in script below.  
    If arguments are not provided, then the script should typically assign a default value in the Parameter section.  The -Simulate argument is a SWITCH object, which means if it is included on the runtime commandline arguments, then the script $Simulate will automatically be set to $TRUE and if it is omitted from the arguments then it will be set to $FALSE.  The -Simulate should NOT have any value tied to it, i.e. -Simulate "Yes"... just standalone -Simulate.
    ALERT: the -Arg1 is a SAMPLE and should be renamed to required variable name or deleted if not being used.
        
    -Arg1 10
    -Simulate     (Do NOT include any argument 'value' string for the -Simulate because it is a type SWITCH)
  

.OUTPUTS
	When enabled, a log file will be created in the same folder the script has been copied to by the SysTrack Cloud
    i.e. "C:\Program Files (x86)\SysTrack\LsiAgent\CMD\...
    This script will perform the following: 
    
    Provide psuedo code description of how the script works


.NOTES
	Version:      1.x (BE SURE TO CHANGE VERSION FOR VARIABLE BELOW e.g. $ScriptVersion = "1.3")
	Company:      CompuCom
    Author:       
    Contact:      Stan.Turner@compucom.com
	Requirements: This script assumed to be run by the SysTrack agent which will either use the Local System or User account depending on how the Automation Profile is configured in SysTrack console.
	Changes:      2025/07/08 v1.0 SysTrack Automation Team 
                  - Initial Release - Post-remediation validation and verification

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
### ALERT: This section must be modified to match the commandline named args or it will use below default values.
###        If the commandline args are not being used, then this will assign below and can be ignored (not used in main code).

param(
    
    [Parameter(Mandatory = $false,
    [switch]$Simulate,
    [int]$TempArg = 60   ### DELETE THIS IF NOT BEING USED ###
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
        LogWrite "#####################################       Exiting Script:  [$ScriptBaseName] Return Code: [$code]"
        LogWrite "#####################################       End Time:        [$ScriptEndTime]"
        LogWrite "#####################################       Script Run Time: [$formattedRunTime]"
        LogWrite "####################################################################################################"
        LogWrite "."
        LogWrite "."
        Exit($code)
    }   


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
    }
    else {
        ExitScript -msg "Module Import:    [Error] Load failure - File Missing [$($ModuleFilePath)]." -code -1
    }
    LogWrite "Module Import:    [Successful]"
}
catch {
    LogWrite "Module Import:    [Error] Module [$($ModuleFilePath)] failed due to load error.  Please review ErrorMsg to fix the module problem. ErrorMsg: $_"
    ExitScript -msg "Function Module File [$ModuleFilePath] Load Failure, exiting script now." -code -1
}

# Log all the Environment Information
Get-Environment_Info

###############################################
### ALERT: REMOVE THE BELOW COMMENT START '<#' AND COMMENT END '#>' 
###        LINES WHEN USING COMMANDLINE ARGUMENT FEATURES
###############################################

#<#
# Log input from commandline arguments.  Remove $TempArg line if this is not being used or rename to usage name.
LogWrite "Runtime value for -TempArg:  $TempArg"
LogWrite "Runtime value for -Simulate: $Simulate"

# Log the .bat commandline arguments for TempArg and runtime Simulate.
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










####################################
# End Main Script
####################################


####################################
# Exit Script
####################################

#NOTE: You MUST assign a value to $returnCode prior to the next statement based on script resutls.
ExitScript -msg "Script Completed" -code $returnCode.Exception.Message)"
        Write-LogEntry $ErrorMessage "Error"
        $FollowUpResults.Issues += $ErrorMessage
        return $false
    }
}

function Calculate-OverallHealthScore {
    try {
        Write-LogEntry "Calculating current overall user Group Policy health score"
        
        $HealthFactors = @{
            PolicyApplicationHealth = ($FollowUpResults.UserPolicyHealth.PolicyAppliedRecently -and $FollowUpResults.UserPolicyHealth.PolicyProcessingSuccessful)
            RegistryHealth = ($FollowUpResults.ValidationDetails.SystemHealth.RegistryHealthScore -gt 75)
            SystemHealth = ($FollowUpResults.ValidationDetails.SystemHealth.UserProfileHealthy -and $FollowUpResults.ValidationDetails.SystemHealth.ServicesDependenciesHealthy)
            PerformanceHealth = ($FollowUpResults.PerformanceImpact.OverallImpactLevel -ne "High")
            PolicyEffectiveness = ($FollowUpResults.UserPolicyHealth.EffectivePoliciesCount -gt 0)
            NoRecentErrors = ($FollowUpResults.UserPolicyHealth.ProcessingErrors.Count -eq 0)
        }
        
        $TotalFactors = $HealthFactors.Values.Count
        $HealthyFactors = ($HealthFactors.Values | Where-Object { <#
.SCRIPT NAME
		FollowUp_Windows_GPO_UpdateUser.ps1
    
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
		Windows Group Policy update and refresh operations. Post-remediation validation and verification.

.INPUTS
{Optional | Required} commandline argument{s} to the .bat script that is followed by a value {string/int} for the Assign Commandline Args Parameters section in script below.  
    If arguments are not provided, then the script should typically assign a default value in the Parameter section.  The -Simulate argument is a SWITCH object, which means if it is included on the runtime commandline arguments, then the script $Simulate will automatically be set to $TRUE and if it is omitted from the arguments then it will be set to $FALSE.  The -Simulate should NOT have any value tied to it, i.e. -Simulate "Yes"... just standalone -Simulate.
    ALERT: the -Arg1 is a SAMPLE and should be renamed to required variable name or deleted if not being used.
        
    -Arg1 10
    -Simulate     (Do NOT include any argument 'value' string for the -Simulate because it is a type SWITCH)
  

.OUTPUTS
	When enabled, a log file will be created in the same folder the script has been copied to by the SysTrack Cloud
    i.e. "C:\Program Files (x86)\SysTrack\LsiAgent\CMD\...
    This script will perform the following: 
    
    Provide psuedo code description of how the script works


.NOTES
	Version:      1.x (BE SURE TO CHANGE VERSION FOR VARIABLE BELOW e.g. $ScriptVersion = "1.3")
	Company:      CompuCom
    Author:       
    Contact:      Stan.Turner@compucom.com
	Requirements: This script assumed to be run by the SysTrack agent which will either use the Local System or User account depending on how the Automation Profile is configured in SysTrack console.
	Changes:      2025/07/08 v1.0 SysTrack Automation Team 
                  - Initial Release - Post-remediation validation and verification

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
### ALERT: This section must be modified to match the commandline named args or it will use below default values.
###        If the commandline args are not being used, then this will assign below and can be ignored (not used in main code).

param(
    
    [Parameter(Mandatory = $false,
    [switch]$Simulate,
    [int]$TempArg = 60   ### DELETE THIS IF NOT BEING USED ###
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
        LogWrite "#####################################       Exiting Script:  [$ScriptBaseName] Return Code: [$code]"
        LogWrite "#####################################       End Time:        [$ScriptEndTime]"
        LogWrite "#####################################       Script Run Time: [$formattedRunTime]"
        LogWrite "####################################################################################################"
        LogWrite "."
        LogWrite "."
        Exit($code)
    }   


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
    }
    else {
        ExitScript -msg "Module Import:    [Error] Load failure - File Missing [$($ModuleFilePath)]." -code -1
    }
    LogWrite "Module Import:    [Successful]"
}
catch {
    LogWrite "Module Import:    [Error] Module [$($ModuleFilePath)] failed due to load error.  Please review ErrorMsg to fix the module problem. ErrorMsg: $_"
    ExitScript -msg "Function Module File [$ModuleFilePath] Load Failure, exiting script now." -code -1
}

# Log all the Environment Information
Get-Environment_Info

###############################################
### ALERT: REMOVE THE BELOW COMMENT START '<#' AND COMMENT END '#>' 
###        LINES WHEN USING COMMANDLINE ARGUMENT FEATURES
###############################################

#<#
# Log input from commandline arguments.  Remove $TempArg line if this is not being used or rename to usage name.
LogWrite "Runtime value for -TempArg:  $TempArg"
LogWrite "Runtime value for -Simulate: $Simulate"

# Log the .bat commandline arguments for TempArg and runtime Simulate.
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










####################################
# End Main Script
####################################


####################################
# Exit Script
####################################

#NOTE: You MUST assign a value to $returnCode prior to the next statement based on script resutls.
ExitScript -msg "Script Completed" -code $returnCode }).Count
        $FollowUpResults.HealthScore = [math]::Round(($HealthyFactors / $TotalFactors) * 100)
        
        # Generate specific recommendations based on health factors
        if (-not $HealthFactors.PolicyApplicationHealth) {
            $FollowUpResults.Recommendations += "Schedule additional user Group Policy refresh - current application status suboptimal"
        }
        if (-not $HealthFactors.RegistryHealth) {
            $FollowUpResults.Recommendations += "Perform user registry maintenance to improve Group Policy processing"
        }
        if (-not $HealthFactors.SystemHealth) {
            $FollowUpResults.Recommendations += "Address user system health issues affecting Group Policy functionality"
        }
        if (-not $HealthFactors.PerformanceHealth) {
            $FollowUpResults.Recommendations += "Optimize Group Policy configuration to reduce processing overhead"
        }
        if (-not $HealthFactors.PolicyEffectiveness) {
            $FollowUpResults.Recommendations += "Verify user Group Policy configuration and domain connectivity"
        }
        if (-not $HealthFactors.NoRecentErrors) {
            $FollowUpResults.Recommendations += "Investigate and resolve user Group Policy processing errors"
        }
        
        Write-LogEntry "Current user Group Policy health score: $($FollowUpResults.HealthScore)% ($HealthyFactors/$TotalFactors factors healthy)"
        
        return $FollowUpResults.HealthScore
        
    } catch {
        $ErrorMessage = "Health score calculation failed: $(<#
.SCRIPT NAME
		FollowUp_Windows_GPO_UpdateUser.ps1
    
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
		Windows Group Policy update and refresh operations. Post-remediation validation and verification.

.INPUTS
{Optional | Required} commandline argument{s} to the .bat script that is followed by a value {string/int} for the Assign Commandline Args Parameters section in script below.  
    If arguments are not provided, then the script should typically assign a default value in the Parameter section.  The -Simulate argument is a SWITCH object, which means if it is included on the runtime commandline arguments, then the script $Simulate will automatically be set to $TRUE and if it is omitted from the arguments then it will be set to $FALSE.  The -Simulate should NOT have any value tied to it, i.e. -Simulate "Yes"... just standalone -Simulate.
    ALERT: the -Arg1 is a SAMPLE and should be renamed to required variable name or deleted if not being used.
        
    -Arg1 10
    -Simulate     (Do NOT include any argument 'value' string for the -Simulate because it is a type SWITCH)
  

.OUTPUTS
	When enabled, a log file will be created in the same folder the script has been copied to by the SysTrack Cloud
    i.e. "C:\Program Files (x86)\SysTrack\LsiAgent\CMD\...
    This script will perform the following: 
    
    Provide psuedo code description of how the script works


.NOTES
	Version:      1.x (BE SURE TO CHANGE VERSION FOR VARIABLE BELOW e.g. $ScriptVersion = "1.3")
	Company:      CompuCom
    Author:       
    Contact:      Stan.Turner@compucom.com
	Requirements: This script assumed to be run by the SysTrack agent which will either use the Local System or User account depending on how the Automation Profile is configured in SysTrack console.
	Changes:      2025/07/08 v1.0 SysTrack Automation Team 
                  - Initial Release - Post-remediation validation and verification

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
### ALERT: This section must be modified to match the commandline named args or it will use below default values.
###        If the commandline args are not being used, then this will assign below and can be ignored (not used in main code).

param(
    
    [Parameter(Mandatory = $false,
    [switch]$Simulate,
    [int]$TempArg = 60   ### DELETE THIS IF NOT BEING USED ###
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
        LogWrite "#####################################       Exiting Script:  [$ScriptBaseName] Return Code: [$code]"
        LogWrite "#####################################       End Time:        [$ScriptEndTime]"
        LogWrite "#####################################       Script Run Time: [$formattedRunTime]"
        LogWrite "####################################################################################################"
        LogWrite "."
        LogWrite "."
        Exit($code)
    }   


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
    }
    else {
        ExitScript -msg "Module Import:    [Error] Load failure - File Missing [$($ModuleFilePath)]." -code -1
    }
    LogWrite "Module Import:    [Successful]"
}
catch {
    LogWrite "Module Import:    [Error] Module [$($ModuleFilePath)] failed due to load error.  Please review ErrorMsg to fix the module problem. ErrorMsg: $_"
    ExitScript -msg "Function Module File [$ModuleFilePath] Load Failure, exiting script now." -code -1
}

# Log all the Environment Information
Get-Environment_Info

###############################################
### ALERT: REMOVE THE BELOW COMMENT START '<#' AND COMMENT END '#>' 
###        LINES WHEN USING COMMANDLINE ARGUMENT FEATURES
###############################################

#<#
# Log input from commandline arguments.  Remove $TempArg line if this is not being used or rename to usage name.
LogWrite "Runtime value for -TempArg:  $TempArg"
LogWrite "Runtime value for -Simulate: $Simulate"

# Log the .bat commandline arguments for TempArg and runtime Simulate.
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










####################################
# End Main Script
####################################


####################################
# Exit Script
####################################

#NOTE: You MUST assign a value to $returnCode prior to the next statement based on script resutls.
ExitScript -msg "Script Completed" -code $returnCode.Exception.Message)"
        Write-LogEntry $ErrorMessage "Error"
        $FollowUpResults.HealthScore = 0
        return 0
    }
}

function Send-HealthClinicUpdate {
    try {
        if (-not $HealthClinicIntegration) {
            Write-LogEntry "Health clinic integration not requested"
            return $true
        }
        
        Write-LogEntry "Sending user Group Policy health update to health clinic"
        
        $HealthUpdate = @{
            Timestamp = $FollowUpResults.Timestamp
            AutomationType = "Windows_GPO_UpdateUser"
            ComputerName = $env:COMPUTERNAME
            UserName = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
            HealthScore = $FollowUpResults.HealthScore
            PreviousHealthScore = $FollowUpResults.PreviousHealthScore
            HealthImprovement = $FollowUpResults.HealthImprovement
            ValidationPassed = $FollowUpResults.ValidationPassed
            IssuesCount = $FollowUpResults.Issues.Count
            PerformanceImpact = $FollowUpResults.PerformanceImpact.OverallImpactLevel
            PolicyEffectiveness = $FollowUpResults.UserPolicyHealth.EffectivePoliciesCount
            Recommendations = $FollowUpResults.Recommendations
            ImprovementLevel = $FollowUpResults.ImprovementMetrics.OverallImprovement
        }
        
        try {
            $JsonPayload = $HealthUpdate | ConvertTo-Json -Depth 10
            $Response = Invoke-RestMethod -Uri $HealthClinicEndpoint -Method POST -Body $JsonPayload -ContentType "application/json" -TimeoutSec 30 -ErrorAction Stop
            
            $FollowUpResults.HealthClinicReported = $true
            Write-LogEntry "Health clinic update sent successfully"
            
        } catch {
            # Fallback to file-based health clinic integration
            $HealthClinicFile = "$env:TEMP\SysTrack_HealthClinic_GPO_User_$(Get-Date -Format 'yyyyMMdd_HHmmss').json"
            $JsonPayload | Out-File -FilePath $HealthClinicFile -Encoding UTF8
            
            $FollowUpResults.HealthClinicReported = $true
            Write-LogEntry "Health clinic update saved to file: $HealthClinicFile"
        }
        
        return $true
        
    } catch {
        $ErrorMessage = "Health clinic integration failed: $(<#
.SCRIPT NAME
		FollowUp_Windows_GPO_UpdateUser.ps1
    
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
		Windows Group Policy update and refresh operations. Post-remediation validation and verification.

.INPUTS
{Optional | Required} commandline argument{s} to the .bat script that is followed by a value {string/int} for the Assign Commandline Args Parameters section in script below.  
    If arguments are not provided, then the script should typically assign a default value in the Parameter section.  The -Simulate argument is a SWITCH object, which means if it is included on the runtime commandline arguments, then the script $Simulate will automatically be set to $TRUE and if it is omitted from the arguments then it will be set to $FALSE.  The -Simulate should NOT have any value tied to it, i.e. -Simulate "Yes"... just standalone -Simulate.
    ALERT: the -Arg1 is a SAMPLE and should be renamed to required variable name or deleted if not being used.
        
    -Arg1 10
    -Simulate     (Do NOT include any argument 'value' string for the -Simulate because it is a type SWITCH)
  

.OUTPUTS
	When enabled, a log file will be created in the same folder the script has been copied to by the SysTrack Cloud
    i.e. "C:\Program Files (x86)\SysTrack\LsiAgent\CMD\...
    This script will perform the following: 
    
    Provide psuedo code description of how the script works


.NOTES
	Version:      1.x (BE SURE TO CHANGE VERSION FOR VARIABLE BELOW e.g. $ScriptVersion = "1.3")
	Company:      CompuCom
    Author:       
    Contact:      Stan.Turner@compucom.com
	Requirements: This script assumed to be run by the SysTrack agent which will either use the Local System or User account depending on how the Automation Profile is configured in SysTrack console.
	Changes:      2025/07/08 v1.0 SysTrack Automation Team 
                  - Initial Release - Post-remediation validation and verification

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
### ALERT: This section must be modified to match the commandline named args or it will use below default values.
###        If the commandline args are not being used, then this will assign below and can be ignored (not used in main code).

param(
    
    [Parameter(Mandatory = $false,
    [switch]$Simulate,
    [int]$TempArg = 60   ### DELETE THIS IF NOT BEING USED ###
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
        LogWrite "#####################################       Exiting Script:  [$ScriptBaseName] Return Code: [$code]"
        LogWrite "#####################################       End Time:        [$ScriptEndTime]"
        LogWrite "#####################################       Script Run Time: [$formattedRunTime]"
        LogWrite "####################################################################################################"
        LogWrite "."
        LogWrite "."
        Exit($code)
    }   


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
    }
    else {
        ExitScript -msg "Module Import:    [Error] Load failure - File Missing [$($ModuleFilePath)]." -code -1
    }
    LogWrite "Module Import:    [Successful]"
}
catch {
    LogWrite "Module Import:    [Error] Module [$($ModuleFilePath)] failed due to load error.  Please review ErrorMsg to fix the module problem. ErrorMsg: $_"
    ExitScript -msg "Function Module File [$ModuleFilePath] Load Failure, exiting script now." -code -1
}

# Log all the Environment Information
Get-Environment_Info

###############################################
### ALERT: REMOVE THE BELOW COMMENT START '<#' AND COMMENT END '#>' 
###        LINES WHEN USING COMMANDLINE ARGUMENT FEATURES
###############################################

#<#
# Log input from commandline arguments.  Remove $TempArg line if this is not being used or rename to usage name.
LogWrite "Runtime value for -TempArg:  $TempArg"
LogWrite "Runtime value for -Simulate: $Simulate"

# Log the .bat commandline arguments for TempArg and runtime Simulate.
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










####################################
# End Main Script
####################################


####################################
# Exit Script
####################################

#NOTE: You MUST assign a value to $returnCode prior to the next statement based on script resutls.
ExitScript -msg "Script Completed" -code $returnCode.Exception.Message)"
        Write-LogEntry $ErrorMessage "Warning"
        return $false
    }
}

function Schedule-NextCheck {
    try {
        if (-not $ScheduleRecheck) {
            Write-LogEntry "Automatic re-check scheduling not requested"
            return $true
        }
        
        Write-LogEntry "Scheduling next user Group Policy health check"
        
        $NextCheckTime = (Get-Date).AddHours($RecheckIntervalHours)
        $TaskName = "SysTrack_GPO_UserHealthCheck_$(Get-Date -Format 'yyyyMMdd')"
        
        # Create scheduled task for next health check
        $TaskAction = New-ScheduledTaskAction -Execute "PowerShell.exe" -Argument "-WindowStyle Hidden -ExecutionPolicy Bypass -File `"$PSScriptRoot\Detect_Windows_GPO_UpdateUser.ps1`""
        $TaskTrigger = New-ScheduledTaskTrigger -Once -At $NextCheckTime
        $TaskSettings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable
        $TaskPrincipal = New-ScheduledTaskPrincipal -UserId ([System.Security.Principal.WindowsIdentity]::GetCurrent().Name) -LogonType Interactive
        
        try {
            $Task = New-ScheduledTask -Action $TaskAction -Trigger $TaskTrigger -Settings $TaskSettings -Principal $TaskPrincipal
            Register-ScheduledTask -TaskName $TaskName -InputObject $Task -Force | Out-Null
            
            $FollowUpResults.NextCheckScheduled = $true
            Write-LogEntry "Next health check scheduled for: $($NextCheckTime.ToString('yyyy-MM-dd HH:mm:ss'))"
            
        } catch {
            # Fallback to creating a reminder file
            $ReminderFile = "$env:TEMP\SysTrack_GPO_UserRecheck_$(Get-Date -Format 'yyyyMMdd_HHmmss').reminder"
            @{
                NextCheckTime = $NextCheckTime
                AutomationType = "Windows_GPO_UpdateUser"
                RecheckCommand = "$PSScriptRoot\Detect_Windows_GPO_UpdateUser.ps1"
            } | ConvertTo-Json | Out-File -FilePath $ReminderFile -Encoding UTF8
            
            $FollowUpResults.NextCheckScheduled = $true
            Write-LogEntry "Health check reminder created: $ReminderFile"
        }
        
        return $true
        
    } catch {
        $ErrorMessage = "Next check scheduling failed: $(<#
.SCRIPT NAME
		FollowUp_Windows_GPO_UpdateUser.ps1
    
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
		Windows Group Policy update and refresh operations. Post-remediation validation and verification.

.INPUTS
{Optional | Required} commandline argument{s} to the .bat script that is followed by a value {string/int} for the Assign Commandline Args Parameters section in script below.  
    If arguments are not provided, then the script should typically assign a default value in the Parameter section.  The -Simulate argument is a SWITCH object, which means if it is included on the runtime commandline arguments, then the script $Simulate will automatically be set to $TRUE and if it is omitted from the arguments then it will be set to $FALSE.  The -Simulate should NOT have any value tied to it, i.e. -Simulate "Yes"... just standalone -Simulate.
    ALERT: the -Arg1 is a SAMPLE and should be renamed to required variable name or deleted if not being used.
        
    -Arg1 10
    -Simulate     (Do NOT include any argument 'value' string for the -Simulate because it is a type SWITCH)
  

.OUTPUTS
	When enabled, a log file will be created in the same folder the script has been copied to by the SysTrack Cloud
    i.e. "C:\Program Files (x86)\SysTrack\LsiAgent\CMD\...
    This script will perform the following: 
    
    Provide psuedo code description of how the script works


.NOTES
	Version:      1.x (BE SURE TO CHANGE VERSION FOR VARIABLE BELOW e.g. $ScriptVersion = "1.3")
	Company:      CompuCom
    Author:       
    Contact:      Stan.Turner@compucom.com
	Requirements: This script assumed to be run by the SysTrack agent which will either use the Local System or User account depending on how the Automation Profile is configured in SysTrack console.
	Changes:      2025/07/08 v1.0 SysTrack Automation Team 
                  - Initial Release - Post-remediation validation and verification

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
### ALERT: This section must be modified to match the commandline named args or it will use below default values.
###        If the commandline args are not being used, then this will assign below and can be ignored (not used in main code).

param(
    
    [Parameter(Mandatory = $false,
    [switch]$Simulate,
    [int]$TempArg = 60   ### DELETE THIS IF NOT BEING USED ###
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
        LogWrite "#####################################       Exiting Script:  [$ScriptBaseName] Return Code: [$code]"
        LogWrite "#####################################       End Time:        [$ScriptEndTime]"
        LogWrite "#####################################       Script Run Time: [$formattedRunTime]"
        LogWrite "####################################################################################################"
        LogWrite "."
        LogWrite "."
        Exit($code)
    }   


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
    }
    else {
        ExitScript -msg "Module Import:    [Error] Load failure - File Missing [$($ModuleFilePath)]." -code -1
    }
    LogWrite "Module Import:    [Successful]"
}
catch {
    LogWrite "Module Import:    [Error] Module [$($ModuleFilePath)] failed due to load error.  Please review ErrorMsg to fix the module problem. ErrorMsg: $_"
    ExitScript -msg "Function Module File [$ModuleFilePath] Load Failure, exiting script now." -code -1
}

# Log all the Environment Information
Get-Environment_Info

###############################################
### ALERT: REMOVE THE BELOW COMMENT START '<#' AND COMMENT END '#>' 
###        LINES WHEN USING COMMANDLINE ARGUMENT FEATURES
###############################################

#<#
# Log input from commandline arguments.  Remove $TempArg line if this is not being used or rename to usage name.
LogWrite "Runtime value for -TempArg:  $TempArg"
LogWrite "Runtime value for -Simulate: $Simulate"

# Log the .bat commandline arguments for TempArg and runtime Simulate.
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










####################################
# End Main Script
####################################


####################################
# Exit Script
####################################

#NOTE: You MUST assign a value to $returnCode prior to the next statement based on script resutls.
ExitScript -msg "Script Completed" -code $returnCode.Exception.Message)"
        Write-LogEntry $ErrorMessage "Warning"
        return $false
    }
}

# Main follow-up logic
try {
    Write-LogEntry "Starting Windows Group Policy User Update follow-up validation"
    
    $FollowUpStartTime = Get-Date
    
    # Step 1: Get baseline health score
    $BaselineScore = Get-BaselineHealthScore
    
    # Step 2: Validate user policy application
    $PolicyValidationPassed = Test-UserPolicyApplication
    
    # Step 3: Assess user system health
    $SystemHealthPassed = Test-UserSystemHealth
    
    # Step 4: Measure performance impact
    $PerformanceAcceptable = Measure-PerformanceImpact
    
    # Step 5: Calculate improvement metrics
    $ImprovementPositive = Calculate-ImprovementMetrics
    
    # Step 6: Calculate overall health score
    $CurrentHealthScore = Calculate-OverallHealthScore
    
    # Step 7: Determine overall validation result
    $FollowUpResults.ValidationPassed = (
        $PolicyValidationPassed -and
        $SystemHealthPassed -and
        $PerformanceAcceptable -and
        ($FollowUpResults.HealthScore -gt 60)
    )
    
    # Step 8: Health clinic integration
    $HealthClinicSuccess = Send-HealthClinicUpdate
    
    # Step 9: Schedule next check if needed
    $NextCheckSuccess = Schedule-NextCheck
    
    # Calculate total follow-up time
    $FollowUpDuration = ((Get-Date) - $FollowUpStartTime).TotalSeconds
    
    # Log final results
    if ($FollowUpResults.ValidationPassed) {
        $Message = "User Group Policy follow-up validation PASSED. Health Score: $($FollowUpResults.HealthScore)% (Improvement: $($FollowUpResults.HealthImprovement)%)"
        Write-LogEntry $Message "Information"
        
        Write-Output "VALIDATION_PASSED"
        Write-Output "HealthScore: $($FollowUpResults.HealthScore)"
        Write-Output "HealthImprovement: $($FollowUpResults.HealthImprovement)"
        Write-Output "ImprovementLevel: $($FollowUpResults.ImprovementMetrics.OverallImprovement)"
        Write-Output "PerformanceImpact: $($FollowUpResults.PerformanceImpact.OverallImpactLevel)"
        Write-Output "PolicyEffective: $($FollowUpResults.UserPolicyHealth.EffectivePoliciesCount -gt 0)"
        Write-Output "Duration: $([math]::Round($FollowUpDuration, 2)) seconds"
        Write-Output "NextCheckScheduled: $($FollowUpResults.NextCheckScheduled)"
        Write-Output "HealthClinicReported: $($FollowUpResults.HealthClinicReported)"
        
        exit 0
    } else {
        $Message = "User Group Policy follow-up validation FAILED. Health Score: $($FollowUpResults.HealthScore)%. Issues: $($FollowUpResults.Issues.Count)"
        Write-LogEntry $Message "Warning"
        
        Write-Output "VALIDATION_FAILED"
        Write-Output "HealthScore: $($FollowUpResults.HealthScore)"
        Write-Output "Issues: $($FollowUpResults.Issues.Count)"
        Write-Output "Recommendations: $($FollowUpResults.Recommendations.Count)"
        Write-Output "Duration: $([math]::Round($FollowUpDuration, 2)) seconds"
        
        # Output recommendations for further action
        if ($FollowUpResults.Recommendations.Count -gt 0) {
            Write-Output "RecommendedActions:"
            foreach ($Recommendation in $FollowUpResults.Recommendations) {
                Write-Output "  - $Recommendation"
            }
        }
        
        exit 1
    }
    
} catch {
    $ErrorMessage = "Critical error during user Group Policy follow-up validation: $(<#
.SCRIPT NAME
		FollowUp_Windows_GPO_UpdateUser.ps1
    
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
		Windows Group Policy update and refresh operations. Post-remediation validation and verification.

.INPUTS
{Optional | Required} commandline argument{s} to the .bat script that is followed by a value {string/int} for the Assign Commandline Args Parameters section in script below.  
    If arguments are not provided, then the script should typically assign a default value in the Parameter section.  The -Simulate argument is a SWITCH object, which means if it is included on the runtime commandline arguments, then the script $Simulate will automatically be set to $TRUE and if it is omitted from the arguments then it will be set to $FALSE.  The -Simulate should NOT have any value tied to it, i.e. -Simulate "Yes"... just standalone -Simulate.
    ALERT: the -Arg1 is a SAMPLE and should be renamed to required variable name or deleted if not being used.
        
    -Arg1 10
    -Simulate     (Do NOT include any argument 'value' string for the -Simulate because it is a type SWITCH)
  

.OUTPUTS
	When enabled, a log file will be created in the same folder the script has been copied to by the SysTrack Cloud
    i.e. "C:\Program Files (x86)\SysTrack\LsiAgent\CMD\...
    This script will perform the following: 
    
    Provide psuedo code description of how the script works


.NOTES
	Version:      1.x (BE SURE TO CHANGE VERSION FOR VARIABLE BELOW e.g. $ScriptVersion = "1.3")
	Company:      CompuCom
    Author:       
    Contact:      Stan.Turner@compucom.com
	Requirements: This script assumed to be run by the SysTrack agent which will either use the Local System or User account depending on how the Automation Profile is configured in SysTrack console.
	Changes:      2025/07/08 v1.0 SysTrack Automation Team 
                  - Initial Release - Post-remediation validation and verification

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
### ALERT: This section must be modified to match the commandline named args or it will use below default values.
###        If the commandline args are not being used, then this will assign below and can be ignored (not used in main code).

param(
    
    [Parameter(Mandatory = $false,
    [switch]$Simulate,
    [int]$TempArg = 60   ### DELETE THIS IF NOT BEING USED ###
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
        LogWrite "#####################################       Exiting Script:  [$ScriptBaseName] Return Code: [$code]"
        LogWrite "#####################################       End Time:        [$ScriptEndTime]"
        LogWrite "#####################################       Script Run Time: [$formattedRunTime]"
        LogWrite "####################################################################################################"
        LogWrite "."
        LogWrite "."
        Exit($code)
    }   


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
    }
    else {
        ExitScript -msg "Module Import:    [Error] Load failure - File Missing [$($ModuleFilePath)]." -code -1
    }
    LogWrite "Module Import:    [Successful]"
}
catch {
    LogWrite "Module Import:    [Error] Module [$($ModuleFilePath)] failed due to load error.  Please review ErrorMsg to fix the module problem. ErrorMsg: $_"
    ExitScript -msg "Function Module File [$ModuleFilePath] Load Failure, exiting script now." -code -1
}

# Log all the Environment Information
Get-Environment_Info

###############################################
### ALERT: REMOVE THE BELOW COMMENT START '<#' AND COMMENT END '#>' 
###        LINES WHEN USING COMMANDLINE ARGUMENT FEATURES
###############################################

#<#
# Log input from commandline arguments.  Remove $TempArg line if this is not being used or rename to usage name.
LogWrite "Runtime value for -TempArg:  $TempArg"
LogWrite "Runtime value for -Simulate: $Simulate"

# Log the .bat commandline arguments for TempArg and runtime Simulate.
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










####################################
# End Main Script
####################################


####################################
# Exit Script
####################################

#NOTE: You MUST assign a value to $returnCode prior to the next statement based on script resutls.
ExitScript -msg "Script Completed" -code $returnCode.Exception.Message)"
    Write-LogEntry $ErrorMessage "Error"
    $FollowUpResults.Issues += $ErrorMessage
    
    Write-Output "FOLLOWUP_ERROR"
    Write-Output "Error: $ErrorMessage"
    Write-Output "Duration: $((Get-Date) - $FollowUpStartTime).TotalSeconds seconds"
    
    exit 2
}

# Output structured results for SysTrack consumption
$FollowUpResults | ConvertTo-Json -Depth 10 | Out-File -FilePath "$env:TEMP\SysTrack_GPO_UserFollowUp_Results.json" -Encoding UTF8 -ErrorAction SilentlyContinue
        
        LogWrite "Completed windows group policy update and refresh operations"
        $returnCode = 0
    }
} catch {
    LogWrite "Error: Unexpected error in main script: $(<#
.SCRIPT NAME
		FollowUp_Windows_GPO_UpdateUser.ps1
    
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
		Windows Group Policy update and refresh operations. Post-remediation validation and verification.

.INPUTS
{Optional | Required} commandline argument{s} to the .bat script that is followed by a value {string/int} for the Assign Commandline Args Parameters section in script below.  
    If arguments are not provided, then the script should typically assign a default value in the Parameter section.  The -Simulate argument is a SWITCH object, which means if it is included on the runtime commandline arguments, then the script $Simulate will automatically be set to $TRUE and if it is omitted from the arguments then it will be set to $FALSE.  The -Simulate should NOT have any value tied to it, i.e. -Simulate "Yes"... just standalone -Simulate.
    ALERT: the -Arg1 is a SAMPLE and should be renamed to required variable name or deleted if not being used.
        
    -Arg1 10
    -Simulate     (Do NOT include any argument 'value' string for the -Simulate because it is a type SWITCH)
  

.OUTPUTS
	When enabled, a log file will be created in the same folder the script has been copied to by the SysTrack Cloud
    i.e. "C:\Program Files (x86)\SysTrack\LsiAgent\CMD\...
    This script will perform the following: 
    
    Provide psuedo code description of how the script works


.NOTES
	Version:      1.x (BE SURE TO CHANGE VERSION FOR VARIABLE BELOW e.g. $ScriptVersion = "1.3")
	Company:      CompuCom
    Author:       
    Contact:      Stan.Turner@compucom.com
	Requirements: This script assumed to be run by the SysTrack agent which will either use the Local System or User account depending on how the Automation Profile is configured in SysTrack console.
	Changes:      2025/07/08 v1.0 SysTrack Automation Team 
                  - Initial Release - Post-remediation validation and verification

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
### ALERT: This section must be modified to match the commandline named args or it will use below default values.
###        If the commandline args are not being used, then this will assign below and can be ignored (not used in main code).

param(
    
    [Parameter(Mandatory = $false,
    [switch]$Simulate,
    [int]$TempArg = 60   ### DELETE THIS IF NOT BEING USED ###
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
        LogWrite "#####################################       Exiting Script:  [$ScriptBaseName] Return Code: [$code]"
        LogWrite "#####################################       End Time:        [$ScriptEndTime]"
        LogWrite "#####################################       Script Run Time: [$formattedRunTime]"
        LogWrite "####################################################################################################"
        LogWrite "."
        LogWrite "."
        Exit($code)
    }   


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
    }
    else {
        ExitScript -msg "Module Import:    [Error] Load failure - File Missing [$($ModuleFilePath)]." -code -1
    }
    LogWrite "Module Import:    [Successful]"
}
catch {
    LogWrite "Module Import:    [Error] Module [$($ModuleFilePath)] failed due to load error.  Please review ErrorMsg to fix the module problem. ErrorMsg: $_"
    ExitScript -msg "Function Module File [$ModuleFilePath] Load Failure, exiting script now." -code -1
}

# Log all the Environment Information
Get-Environment_Info

###############################################
### ALERT: REMOVE THE BELOW COMMENT START '<#' AND COMMENT END '#>' 
###        LINES WHEN USING COMMANDLINE ARGUMENT FEATURES
###############################################

#<#
# Log input from commandline arguments.  Remove $TempArg line if this is not being used or rename to usage name.
LogWrite "Runtime value for -TempArg:  $TempArg"
LogWrite "Runtime value for -Simulate: $Simulate"

# Log the .bat commandline arguments for TempArg and runtime Simulate.
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










####################################
# End Main Script
####################################


####################################
# Exit Script
####################################

#NOTE: You MUST assign a value to $returnCode prior to the next statement based on script resutls.
ExitScript -msg "Script Completed" -code $returnCode.Exception.Message)"
    $returnCode = -1
}

####################################
# End Main Script
####################################


####################################
# Exit Script
####################################

#NOTE: You MUST assign a value to $returnCode prior to the next statement based on script resutls.
ExitScript -msg "Script Completed" -code $returnCode
