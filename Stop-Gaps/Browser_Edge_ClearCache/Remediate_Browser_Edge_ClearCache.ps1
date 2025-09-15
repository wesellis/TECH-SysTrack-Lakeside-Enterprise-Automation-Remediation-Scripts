<#
.SCRIPT NAME
		Remediate_Browser_Edge_ClearCache.ps1
    
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
		Microsoft Edge browser cache and data management. Remediation and repair operations.

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
                  - Initial Release - Remediation and repair operations

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
        LogWrite "SIMULATION MODE: Would execute remediation and repair operations"
        LogWrite "SIMULATION MODE: Script would perform: microsoft edge browser cache and data management"
        $returnCode = 0
    } else {
        # Original script logic preserved below
        LogWrite "Starting microsoft edge browser cache and data management"
        
]
    [switch]$BackupEnabled = $true,
    
    [Parameter(Mandatory = $false)]
    [switch]$ForceCleanup,
    
    [Parameter(Mandatory = $false)]
    [switch]$IncludeLegacyEdge,
    
    [Parameter(Mandatory = $false)]
    [switch]$CleanupAllProfiles,
    
    [Parameter(Mandatory = $false)]
    [switch]$PreservePasswords = $true
)

# Initialize logging
$LogName = "Application"
$Source = "SysTrack_Edge_Cache_Remediation"

# Register event source if it doesn't exist
try {
    if (-not [System.Diagnostics.EventLog]::SourceExists($Source)) {
        [System.Diagnostics.EventLog]::CreateEventSource($Source, $LogName)
    }
}
catch {
    Write-Warning "Unable to create event source: $(<#
.SCRIPT NAME
		Remediate_Browser_Edge_ClearCache.ps1
    
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
		Microsoft Edge browser cache and data management. Remediation and repair operations.

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
                  - Initial Release - Remediation and repair operations

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
}

# Remediation results object
$RemediationResult = [PSCustomObject]@{
    RemediationTime = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Success = $false
    ProfilesProcessed = @()
    CacheClearedMB = 0
    FilesRemoved = 0
    BackupCreated = $false
    BackupLocation = $null
    ProcessesTerminated = @()
    ProcessesRestored = @()
    ErrorsEncountered = @()
    WarningsEncountered = @()
    RecommendedFollowUp = @()
}

function Write-LogEntry {
    param(
        [string]$Message,
        [ValidateSet("Information", "Warning", "Error")]
        [string]$EntryType = "Information",
        [int]$EventID = 1001
    )
    
    try {
        Write-EventLog -LogName $LogName -Source $Source -EntryType $EntryType -EventId $EventID -Message $Message
        
        switch ($EntryType) {
            "Information" { Write-Host "INFO: $Message" -ForegroundColor Green }
            "Warning" { 
                Write-Host "WARN: $Message" -ForegroundColor Yellow
                $RemediationResult.WarningsEncountered += $Message
            }
            "Error" { 
                Write-Host "ERROR: $Message" -ForegroundColor Red
                $RemediationResult.ErrorsEncountered += $Message
            }
        }
    }
    catch {
        Write-Host "LOGGING ERROR: $Message" -ForegroundColor Magenta
    }
}

function Test-AdministratorPrivileges {
    try {
        $CurrentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
        $Principal = New-Object Security.Principal.WindowsPrincipal($CurrentUser)
        return $Principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    }
    catch {
        return $false
    }
}

function Stop-EdgeProcesses {
    param([bool]$ForceTermination = $false)
    
    Write-LogEntry "Checking for running Edge processes"
    
    $TerminatedProcesses = @()
    
    try {
        # Get all Edge processes
        $EdgeProcesses = @()
        $EdgeProcesses += Get-Process -Name "msedge" -ErrorAction SilentlyContinue
        $EdgeProcesses += Get-Process -Name "MicrosoftEdge*" -ErrorAction SilentlyContinue
        
        if ($EdgeProcesses.Count -eq 0) {
            Write-LogEntry "No Edge processes running"
            return $TerminatedProcesses
        }
        
        Write-LogEntry "Found $($EdgeProcesses.Count) Edge processes running"
        
        # Attempt graceful shutdown first
        foreach ($Process in $EdgeProcesses) {
            try {
                Write-LogEntry "Attempting graceful shutdown of process $($Process.ProcessName) (PID: $($Process.Id))"
                
                if (-not $Process.CloseMainWindow()) {
                    Write-LogEntry "Main window close failed for process $($Process.ProcessName)" -EntryType Warning
                }
                
                # Wait for graceful shutdown
                $Process.WaitForExit(10000)  # 10 second timeout
                
                if (-not $Process.HasExited) {
                    if ($ForceTermination) {
                        Write-LogEntry "Force terminating process $($Process.ProcessName)" -EntryType Warning
                        $Process.Kill()
                        $Process.WaitForExit(5000)  # 5 second timeout for kill
                    }
                    else {
                        Write-LogEntry "Process $($Process.ProcessName) did not terminate gracefully" -EntryType Warning
                        continue
                    }
                }
                
                $TerminatedProcesses += $Process.ProcessName
                Write-LogEntry "Successfully terminated process $($Process.ProcessName)"
            }
            catch {
                Write-LogEntry "Error terminating process $($Process.ProcessName): $(<#
.SCRIPT NAME
		Remediate_Browser_Edge_ClearCache.ps1
    
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
		Microsoft Edge browser cache and data management. Remediation and repair operations.

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
                  - Initial Release - Remediation and repair operations

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
ExitScript -msg "Script Completed" -code $returnCode.Exception.Message)" -EntryType Error
            }
        }
        
        # Final verification
        Start-Sleep -Seconds 2
        $RemainingProcesses = Get-Process -Name "msedge", "MicrosoftEdge*" -ErrorAction SilentlyContinue
        if ($RemainingProcesses.Count -gt 0) {
            Write-LogEntry "Warning: $($RemainingProcesses.Count) Edge processes still running" -EntryType Warning
        }
        
        return $TerminatedProcesses
    }
    catch {
        Write-LogEntry "Error during Edge process termination: $(<#
.SCRIPT NAME
		Remediate_Browser_Edge_ClearCache.ps1
    
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
		Microsoft Edge browser cache and data management. Remediation and repair operations.

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
                  - Initial Release - Remediation and repair operations

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
ExitScript -msg "Script Completed" -code $returnCode.Exception.Message)" -EntryType Error
        return $TerminatedProcesses
    }
}

function New-EdgeBackup {
    Write-LogEntry "Creating Edge data backup"
    
    try {
        $BackupRoot = Join-Path $env:TEMP "EdgeBackup_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
        New-Item -ItemType Directory -Path $BackupRoot -Force | Out-Null
        
        $EdgeDataPath = "$env:LOCALAPPDATA\Microsoft\Edge\User Data"
        
        if (Test-Path $EdgeDataPath) {
            # Backup critical files only
            $CriticalFiles = @(
                "Bookmarks", "Bookmarks.bak", "Preferences", "Secure Preferences",
                "Local State", "First Run", "History", "Favicons"
            )
            
            $ProfileDirs = Get-ChildItem $EdgeDataPath -Directory | Where-Object { <#
.SCRIPT NAME
		Remediate_Browser_Edge_ClearCache.ps1
    
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
		Microsoft Edge browser cache and data management. Remediation and repair operations.

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
                  - Initial Release - Remediation and repair operations

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
ExitScript -msg "Script Completed" -code $returnCode.Name -match "^(Default|Profile \d+)$" }
            
            foreach ($Profile in $ProfileDirs) {
                $ProfileBackupPath = Join-Path $BackupRoot $Profile.Name
                New-Item -ItemType Directory -Path $ProfileBackupPath -Force | Out-Null
                
                foreach ($File in $CriticalFiles) {
                    $SourceFile = Join-Path $Profile.FullName $File
                    if (Test-Path $SourceFile) {
                        Copy-Item $SourceFile $ProfileBackupPath -ErrorAction SilentlyContinue
                    }
                }
                
                # Backup password file if PreservePasswords is enabled
                if ($PreservePasswords) {
                    $PasswordFile = Join-Path $Profile.FullName "Login Data"
                    if (Test-Path $PasswordFile) {
                        Copy-Item $PasswordFile $ProfileBackupPath -ErrorAction SilentlyContinue
                    }
                }
            }
            
            # Backup Local State file
            $LocalStateFile = Join-Path $EdgeDataPath "Local State"
            if (Test-Path $LocalStateFile) {
                Copy-Item $LocalStateFile $BackupRoot -ErrorAction SilentlyContinue
            }
            
            $RemediationResult.BackupCreated = $true
            $RemediationResult.BackupLocation = $BackupRoot
            Write-LogEntry "Backup created successfully at: $BackupRoot"
            
            return $BackupRoot
        }
        else {
            Write-LogEntry "Edge data directory not found for backup" -EntryType Warning
            return $null
        }
    }
    catch {
        Write-LogEntry "Error creating backup: $(<#
.SCRIPT NAME
		Remediate_Browser_Edge_ClearCache.ps1
    
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
		Microsoft Edge browser cache and data management. Remediation and repair operations.

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
                  - Initial Release - Remediation and repair operations

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
ExitScript -msg "Script Completed" -code $returnCode.Exception.Message)" -EntryType Error
        return $null
    }
}

function Get-EdgeProfiles {
    Write-LogEntry "Identifying Edge profiles for cleanup"
    
    $Profiles = @()
    
    try {
        if ($CleanupAllProfiles -and (Test-AdministratorPrivileges)) {
            # Get all user profiles
            $UserProfiles = Get-ChildItem "$env:SystemDrive\Users" -Directory -ErrorAction SilentlyContinue
            
            foreach ($UserProfile in $UserProfiles) {
                # Chromium Edge
                $EdgeDataPath = Join-Path $UserProfile.FullName "AppData\Local\Microsoft\Edge\User Data"
                if (Test-Path $EdgeDataPath) {
                    $ProfileDirs = Get-ChildItem $EdgeDataPath -Directory | Where-Object { <#
.SCRIPT NAME
		Remediate_Browser_Edge_ClearCache.ps1
    
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
		Microsoft Edge browser cache and data management. Remediation and repair operations.

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
                  - Initial Release - Remediation and repair operations

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
ExitScript -msg "Script Completed" -code $returnCode.Name -match "^(Default|Profile \d+)$" }
                    foreach ($ProfileDir in $ProfileDirs) {
                        $Profiles += [PSCustomObject]@{
                            UserName = $UserProfile.Name
                            ProfileName = $ProfileDir.Name
                            ProfilePath = $ProfileDir.FullName
                            CachePath = Join-Path $ProfileDir.FullName "Cache"
                            EdgeType = "Chromium"
                        }
                    }
                }
                
                # Legacy Edge
                if ($IncludeLegacyEdge) {
                    $LegacyCachePath = Join-Path $UserProfile.FullName "AppData\Local\Packages\Microsoft.MicrosoftEdge_8wekyb3d8bbwe\AC\MicrosoftEdge\Cache"
                    if (Test-Path $LegacyCachePath) {
                        $Profiles += [PSCustomObject]@{
                            UserName = $UserProfile.Name
                            ProfileName = "Legacy"
                            ProfilePath = Split-Path $LegacyCachePath -Parent
                            CachePath = $LegacyCachePath
                            EdgeType = "Legacy"
                        }
                    }
                }
            }
        }
        else {
            # Current user only
            $EdgeDataPath = "$env:LOCALAPPDATA\Microsoft\Edge\User Data"
            if (Test-Path $EdgeDataPath) {
                $ProfileDirs = Get-ChildItem $EdgeDataPath -Directory | Where-Object { <#
.SCRIPT NAME
		Remediate_Browser_Edge_ClearCache.ps1
    
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
		Microsoft Edge browser cache and data management. Remediation and repair operations.

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
                  - Initial Release - Remediation and repair operations

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
ExitScript -msg "Script Completed" -code $returnCode.Name -match "^(Default|Profile \d+)$" }
                foreach ($ProfileDir in $ProfileDirs) {
                    $Profiles += [PSCustomObject]@{
                        UserName = $env:USERNAME
                        ProfileName = $ProfileDir.Name
                        ProfilePath = $ProfileDir.FullName
                        CachePath = Join-Path $ProfileDir.FullName "Cache"
                        EdgeType = "Chromium"
                    }
                }
            }
            
            # Legacy Edge for current user
            if ($IncludeLegacyEdge) {
                $LegacyCachePath = "$env:LOCALAPPDATA\Packages\Microsoft.MicrosoftEdge_8wekyb3d8bbwe\AC\MicrosoftEdge\Cache"
                if (Test-Path $LegacyCachePath) {
                    $Profiles += [PSCustomObject]@{
                        UserName = $env:USERNAME
                        ProfileName = "Legacy"
                        ProfilePath = Split-Path $LegacyCachePath -Parent
                        CachePath = $LegacyCachePath
                        EdgeType = "Legacy"
                    }
                }
            }
        }
        
        Write-LogEntry "Found $($Profiles.Count) Edge profiles for cleanup"
        return $Profiles
    }
    catch {
        Write-LogEntry "Error identifying Edge profiles: $(<#
.SCRIPT NAME
		Remediate_Browser_Edge_ClearCache.ps1
    
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
		Microsoft Edge browser cache and data management. Remediation and repair operations.

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
                  - Initial Release - Remediation and repair operations

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
ExitScript -msg "Script Completed" -code $returnCode.Exception.Message)" -EntryType Error
        return @()
    }
}

function Clear-EdgeCache {
    param([PSCustomObject]$Profile)
    
    Write-LogEntry "Clearing cache for profile: $($Profile.UserName)\$($Profile.ProfileName) ($($Profile.EdgeType))"
    
    $CleanupStats = @{
        SizeClearedMB = 0
        FilesRemoved = 0
        Success = $false
    }
    
    try {
        if (-not (Test-Path $Profile.CachePath)) {
            Write-LogEntry "Cache directory not found: $($Profile.CachePath)" -EntryType Warning
            return $CleanupStats
        }
        
        # Measure cache before cleanup
        $CacheFiles = Get-ChildItem $Profile.CachePath -Recurse -File -ErrorAction SilentlyContinue
        $OriginalSize = ($CacheFiles | Measure-Object -Property Length -Sum).Sum
        $OriginalSizeMB = [Math]::Round($OriginalSize / 1MB, 2)
        $OriginalFileCount = $CacheFiles.Count
        
        Write-LogEntry "Profile $($Profile.ProfileName): Cache contains $OriginalFileCount files ($OriginalSizeMB MB)"
        
        # Clear cache files
        try {
            Remove-Item "$($Profile.CachePath)\*" -Recurse -Force -ErrorAction Stop
            
            # Verify cleanup
            Start-Sleep -Seconds 1
            $RemainingFiles = Get-ChildItem $Profile.CachePath -Recurse -File -ErrorAction SilentlyContinue
            
            if ($RemainingFiles.Count -eq 0) {
                $CleanupStats.Success = $true
                $CleanupStats.SizeClearedMB = $OriginalSizeMB
                $CleanupStats.FilesRemoved = $OriginalFileCount
                Write-LogEntry "Successfully cleared cache for profile $($Profile.ProfileName): removed $OriginalFileCount files ($OriginalSizeMB MB)"
            }
            else {
                Write-LogEntry "Partial cleanup for profile $($Profile.ProfileName): $($RemainingFiles.Count) files remain" -EntryType Warning
                $RemainingSize = ($RemainingFiles | Measure-Object -Property Length -Sum).Sum
                $RemainingMB = [Math]::Round($RemainingSize / 1MB, 2)
                $CleanupStats.SizeClearedMB = $OriginalSizeMB - $RemainingMB
                $CleanupStats.FilesRemoved = $OriginalFileCount - $RemainingFiles.Count
                $CleanupStats.Success = $true  # Partial success
            }
        }
        catch {
            Write-LogEntry "Error clearing cache for profile $($Profile.ProfileName): $(<#
.SCRIPT NAME
		Remediate_Browser_Edge_ClearCache.ps1
    
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
		Microsoft Edge browser cache and data management. Remediation and repair operations.

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
                  - Initial Release - Remediation and repair operations

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
ExitScript -msg "Script Completed" -code $returnCode.Exception.Message)" -EntryType Error
        }
        
        # Recreate cache directory structure
        try {
            if (-not (Test-Path $Profile.CachePath)) {
                New-Item -ItemType Directory -Path $Profile.CachePath -Force | Out-Null
            }
        }
        catch {
            Write-LogEntry "Error recreating cache directory: $(<#
.SCRIPT NAME
		Remediate_Browser_Edge_ClearCache.ps1
    
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
		Microsoft Edge browser cache and data management. Remediation and repair operations.

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
                  - Initial Release - Remediation and repair operations

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
ExitScript -msg "Script Completed" -code $returnCode.Exception.Message)" -EntryType Warning
        }
        
        return $CleanupStats
    }
    catch {
        Write-LogEntry "Error processing cache for profile $($Profile.ProfileName): $(<#
.SCRIPT NAME
		Remediate_Browser_Edge_ClearCache.ps1
    
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
		Microsoft Edge browser cache and data management. Remediation and repair operations.

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
                  - Initial Release - Remediation and repair operations

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
ExitScript -msg "Script Completed" -code $returnCode.Exception.Message)" -EntryType Error
        return $CleanupStats
    }
}

function Test-EdgeFunctionality {
    Write-LogEntry "Testing Edge functionality after cleanup"
    
    try {
        # Check if Edge can be launched
        $EdgePath = "${env:ProgramFiles(x86)}\Microsoft\Edge\Application\msedge.exe"
        if (-not (Test-Path $EdgePath)) {
            $EdgePath = "${env:ProgramFiles}\Microsoft\Edge\Application\msedge.exe"
        }
        
        if (Test-Path $EdgePath) {
            # Launch Edge with minimal profile to test functionality
            $TestProcess = Start-Process $EdgePath -ArgumentList "--no-default-browser-check", "--disable-extensions", "--new-window", "about:blank" -PassThru
            
            Start-Sleep -Seconds 3
            
            if (-not $TestProcess.HasExited) {
                # Edge launched successfully
                $TestProcess.CloseMainWindow() | Out-Null
                Start-Sleep -Seconds 2
                if (-not $TestProcess.HasExited) {
                    $TestProcess.Kill()
                }
                
                Write-LogEntry "Edge functionality test passed"
                return $true
            }
            else {
                Write-LogEntry "Edge functionality test failed - process exited immediately" -EntryType Warning
                return $false
            }
        }
        else {
            Write-LogEntry "Edge executable not found for functionality test" -EntryType Warning
            return $false
        }
    }
    catch {
        Write-LogEntry "Error testing Edge functionality: $(<#
.SCRIPT NAME
		Remediate_Browser_Edge_ClearCache.ps1
    
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
		Microsoft Edge browser cache and data management. Remediation and repair operations.

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
                  - Initial Release - Remediation and repair operations

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
ExitScript -msg "Script Completed" -code $returnCode.Exception.Message)" -EntryType Warning
        return $false
    }
}

# Main remediation logic
try {
    Write-LogEntry "Starting Edge cache remediation"
    Write-LogEntry "Parameters: BackupEnabled=$BackupEnabled, ForceCleanup=$ForceCleanup, IncludeLegacyEdge=$IncludeLegacyEdge, CleanupAllProfiles=$CleanupAllProfiles"
    
    # Check privileges for all-user cleanup
    if ($CleanupAllProfiles -and -not (Test-AdministratorPrivileges)) {
        Write-LogEntry "Administrator privileges required for all-user cleanup, falling back to current user only" -EntryType Warning
        $CleanupAllProfiles = $false
    }
    
    # Stop Edge processes
    $TerminatedProcesses = Stop-EdgeProcesses -ForceTermination $ForceCleanup
    $RemediationResult.ProcessesTerminated = $TerminatedProcesses
    
    if ($TerminatedProcesses.Count -eq 0) {
        $RemainingProcesses = Get-Process -Name "msedge", "MicrosoftEdge*" -ErrorAction SilentlyContinue
        if ($RemainingProcesses.Count -gt 0 -and -not $ForceCleanup) {
            Write-LogEntry "Cannot proceed with cleanup while Edge processes are running. Use -ForceCleanup to override." -EntryType Error
            $RemediationResult.Success = $false
            Write-Output ($RemediationResult | ConvertTo-Json -Depth 3)
            exit 1
        }
    }
    
    # Create backup if enabled
    $BackupPath = $null
    if ($BackupEnabled) {
        $BackupPath = New-EdgeBackup
    }
    
    # Get profiles to clean
    $Profiles = Get-EdgeProfiles
    
    if ($Profiles.Count -eq 0) {
        Write-LogEntry "No Edge profiles found for cleanup" -EntryType Warning
        $RemediationResult.Success = $true  # Nothing to do
        Write-Output ($RemediationResult | ConvertTo-Json -Depth 3)
        exit 0
    }
    
    # Clean cache for each profile
    $TotalSizeCleared = 0
    $TotalFilesRemoved = 0
    $SuccessfulProfiles = 0
    
    foreach ($Profile in $Profiles) {
        $CleanupStats = Clear-EdgeCache -Profile $Profile
        
        $ProfileResult = [PSCustomObject]@{
            UserName = $Profile.UserName
            ProfileName = $Profile.ProfileName
            EdgeType = $Profile.EdgeType
            Success = $CleanupStats.Success
            SizeClearedMB = $CleanupStats.SizeClearedMB
            FilesRemoved = $CleanupStats.FilesRemoved
        }
        
        $RemediationResult.ProfilesProcessed += $ProfileResult
        
        if ($CleanupStats.Success) {
            $SuccessfulProfiles++
            $TotalSizeCleared += $CleanupStats.SizeClearedMB
            $TotalFilesRemoved += $CleanupStats.FilesRemoved
        }
    }
    
    $RemediationResult.CacheClearedMB = [Math]::Round($TotalSizeCleared, 2)
    $RemediationResult.FilesRemoved = $TotalFilesRemoved
    
    # Test Edge functionality
    $FunctionalityOK = Test-EdgeFunctionality
    if (-not $FunctionalityOK) {
        $RemediationResult.RecommendedFollowUp += "Edge functionality test failed - manual verification recommended"
    }
    
    # Determine overall success
    if ($SuccessfulProfiles -eq $Profiles.Count) {
        $RemediationResult.Success = $true
        Write-LogEntry "Edge cache cleanup completed successfully: $($RemediationResult.CacheClearedMB)MB cleared from $SuccessfulProfiles profiles"
        
        # Add recommendations
        if ($RemediationResult.CacheClearedMB -gt 500) {
            $RemediationResult.RecommendedFollowUp += "Significant cache cleared - monitor Edge performance improvement"
        }
        if ($BackupPath) {
            $RemediationResult.RecommendedFollowUp += "Backup created at $BackupPath - review after 24 hours for cleanup"
        }
        
        Write-Output ($RemediationResult | ConvertTo-Json -Depth 3)
        exit 0
    }
    elseif ($SuccessfulProfiles -gt 0) {
        $RemediationResult.Success = $true  # Partial success
        Write-LogEntry "Partial Edge cache cleanup completed: $SuccessfulProfiles of $($Profiles.Count) profiles cleaned successfully" -EntryType Warning
        
        $RemediationResult.RecommendedFollowUp += "Partial cleanup completed - manual intervention may be needed for failed profiles"
        
        Write-Output ($RemediationResult | ConvertTo-Json -Depth 3)
        exit 2
    }
    else {
        $RemediationResult.Success = $false
        Write-LogEntry "Edge cache cleanup failed for all profiles" -EntryType Error
        
        Write-Output ($RemediationResult | ConvertTo-Json -Depth 3)
        exit 1
    }
}
catch {
    $ErrorMessage = "Remediation failed with critical error: $(<#
.SCRIPT NAME
		Remediate_Browser_Edge_ClearCache.ps1
    
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
		Microsoft Edge browser cache and data management. Remediation and repair operations.

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
                  - Initial Release - Remediation and repair operations

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
    $RemediationResult.ErrorsEncountered += $ErrorMessage
    $RemediationResult.Success = $false
    Write-LogEntry $ErrorMessage -EntryType Error
    
    Write-Output ($RemediationResult | ConvertTo-Json -Depth 3)
    exit 1
}
        
        LogWrite "Completed microsoft edge browser cache and data management"
        $returnCode = 0
    }
} catch {
    LogWrite "Error: Unexpected error in main script: $(<#
.SCRIPT NAME
		Remediate_Browser_Edge_ClearCache.ps1
    
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
		Microsoft Edge browser cache and data management. Remediation and repair operations.

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
                  - Initial Release - Remediation and repair operations

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
