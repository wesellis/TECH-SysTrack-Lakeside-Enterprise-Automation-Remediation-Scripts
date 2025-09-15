<#
.SCRIPT NAME
		Remediate_SCCM_Client_AppDeployEvalCycle.ps1
    
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
		System Center Configuration Manager client operations. Remediation and repair operations.

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
        LogWrite "SIMULATION MODE: Script would perform: system center configuration manager client operations"
        $returnCode = 0
    } else {
        # Original script logic preserved below
        LogWrite "Starting system center configuration manager client operations"
        
]
    [switch]$Force,
    
    [Parameter(Mandatory = $false)]
    [bool]$IncludeUserApps = $true,
    
    [Parameter(Mandatory = $false)]
    [ValidateRange(60, 1800)]
    [int]$Timeout = 300,
    
    [Parameter(Mandatory = $false)]
    [ValidateRange(1, 10)]
    [int]$RetryAttempts = 3
)

# Initialize script variables
$ScriptName = "Remediate_SCCM_Client_AppDeployEvalCycle"
$ScriptVersion = "1.0.0"
$EventSource = "SysTrack_SCCM_Remediation"
$EventLog = "Application"

# SCCM namespace and class definitions
$SCCMNamespace = "ROOT\CCM"
$SCCMClientNamespace = "ROOT\CCM\ClientSDK"
$SCCMPolicyNamespace = "ROOT\CCM\Policy"

# Application Deployment Evaluation Cycle GUID
$AppDeployEvalGuid = "{00000000-0000-0000-0000-000000000121}"

# Initialize remediation result object
$RemediationResult = @{
    ScriptName = $ScriptName
    ScriptVersion = $ScriptVersion
    Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    ComputerName = $env:COMPUTERNAME
    UserContext = $env:USERNAME
    Success = $false
    Operations = @()
    Results = @{}
    Issues = @()
    RecommendedActions = @()
    ExitCode = 0
}

#region Logging Functions

function Write-EventLogEntry {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message,
        
        [Parameter(Mandatory = $false)]
        [ValidateSet('Information', 'Warning', 'Error')]
        [string]$EntryType = 'Information',
        
        [Parameter(Mandatory = $false)]
        [int]$EventId = 2000
    )
    
    try {
        if (-not [System.Diagnostics.EventLog]::SourceExists($EventSource)) {
            [System.Diagnostics.EventLog]::CreateEventSource($EventSource, $EventLog)
        }
        
        Write-EventLog -LogName $EventLog -Source $EventSource -EntryType $EntryType -EventId $EventId -Message $Message
    }
    catch {
        Write-Warning "Failed to write to Event Log: <#
.SCRIPT NAME
		Remediate_SCCM_Client_AppDeployEvalCycle.ps1
    
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
		System Center Configuration Manager client operations. Remediation and repair operations.

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
ExitScript -msg "Script Completed" -code $returnCode"
    }
}

function Write-LogMessage {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message,
        
        [Parameter(Mandatory = $false)]
        [ValidateSet('Info', 'Warning', 'Error', 'Debug')]
        [string]$Level = 'Info'
    )
    
    $LogMessage = "[{0}] [{1}] {2}" -f (Get-Date -Format "yyyy-MM-dd HH:mm:ss"), $Level.ToUpper(), $Message
    
    switch ($Level) {
        'Info' { Write-Host $LogMessage -ForegroundColor Green }
        'Warning' { Write-Host $LogMessage -ForegroundColor Yellow }
        'Error' { Write-Host $LogMessage -ForegroundColor Red }
        'Debug' { Write-Host $LogMessage -ForegroundColor Cyan }
    }
    
    # Write to Event Log for Warning and Error levels
    if ($Level -in @('Warning', 'Error')) {
        $EventType = if ($Level -eq 'Warning') { 'Warning' } else { 'Error' }
        Write-EventLogEntry -Message $LogMessage -EntryType $EventType
    }
}

function Add-Operation {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Name,
        
        [Parameter(Mandatory = $true)]
        [string]$Status,
        
        [Parameter(Mandatory = $false)]
        [string]$Details = "",
        
        [Parameter(Mandatory = $false)]
        [datetime]$Timestamp = (Get-Date)
    )
    
    $Operation = @{
        Name = $Name
        Status = $Status
        Details = $Details
        Timestamp = $Timestamp.ToString("yyyy-MM-dd HH:mm:ss")
    }
    
    $RemediationResult.Operations += $Operation
    Write-LogMessage "$Name - $Status $(if($Details) { "- $Details" })" -Level Info
}

#endregion

#region SCCM Client Functions

function Test-SCCMClientReady {
    <#
    .SYNOPSIS
        Validates SCCM client is ready for evaluation cycle operations.
    #>
    
    Write-LogMessage "Validating SCCM client readiness" -Level Info
    
    $ReadinessCheck = @{
        ClientInstalled = $false
        ServiceRunning = $false
        WMIAccessible = $false
        PolicyEngineReady = $false
        Issues = @()
    }
    
    try {
        # Check SCCM client service
        $CCMService = Get-Service -Name "CcmExec" -ErrorAction SilentlyContinue
        if ($CCMService) {
            $ReadinessCheck.ClientInstalled = $true
            
            if ($CCMService.Status -eq 'Running') {
                $ReadinessCheck.ServiceRunning = $true
            }
            else {
                $ReadinessCheck.Issues += "SCCM Client service is not running (Status: $($CCMService.Status))"
            }
        }
        else {
            $ReadinessCheck.Issues += "SCCM Client service not found"
            return $ReadinessCheck
        }
        
        # Test WMI access
        try {
            $WMITest = Get-WmiObject -Namespace $SCCMNamespace -Class "SMS_Client" -ErrorAction Stop
            if ($WMITest) {
                $ReadinessCheck.WMIAccessible = $true
            }
        }
        catch {
            $ReadinessCheck.Issues += "Cannot access SCCM WMI namespace: <#
.SCRIPT NAME
		Remediate_SCCM_Client_AppDeployEvalCycle.ps1
    
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
		System Center Configuration Manager client operations. Remediation and repair operations.

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
ExitScript -msg "Script Completed" -code $returnCode"
        }
        
        # Test policy engine readiness
        try {
            $PolicyEngine = Get-WmiObject -Namespace $SCCMClientNamespace -Class "CCM_ClientUtilities" -ErrorAction SilentlyContinue
            if ($PolicyEngine) {
                $ReadinessCheck.PolicyEngineReady = $true
            }
            else {
                $ReadinessCheck.Issues += "SCCM policy engine not accessible"
            }
        }
        catch {
            $ReadinessCheck.Issues += "Error testing policy engine: <#
.SCRIPT NAME
		Remediate_SCCM_Client_AppDeployEvalCycle.ps1
    
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
		System Center Configuration Manager client operations. Remediation and repair operations.

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
ExitScript -msg "Script Completed" -code $returnCode"
        }
    }
    catch {
        $ReadinessCheck.Issues += "Error validating SCCM client readiness: <#
.SCRIPT NAME
		Remediate_SCCM_Client_AppDeployEvalCycle.ps1
    
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
		System Center Configuration Manager client operations. Remediation and repair operations.

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
ExitScript -msg "Script Completed" -code $returnCode"
        Write-LogMessage "Error validating SCCM client: <#
.SCRIPT NAME
		Remediate_SCCM_Client_AppDeployEvalCycle.ps1
    
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
		System Center Configuration Manager client operations. Remediation and repair operations.

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
ExitScript -msg "Script Completed" -code $returnCode" -Level Error
    }
    
    return $ReadinessCheck
}

function Start-ApplicationPolicyRefresh {
    <#
    .SYNOPSIS
        Refreshes application policies before triggering evaluation cycle.
    #>
    
    Write-LogMessage "Refreshing application policies" -Level Info
    
    $PolicyRefresh = @{
        Success = $false
        MachinePolicyRefreshed = $false
        UserPolicyRefreshed = $false
        Details = @()
        Issues = @()
    }
    
    try {
        # Refresh machine policy for applications
        try {
            $MachinePolicyRefresh = Invoke-WmiMethod -Namespace $SCCMClientNamespace -Class "CCM_ClientUtilities" -Name "TriggerSchedule" -ArgumentList "{00000000-0000-0000-0000-000000000021}" -ErrorAction Stop
            
            if ($MachinePolicyRefresh.ReturnValue -eq 0) {
                $PolicyRefresh.MachinePolicyRefreshed = $true
                $PolicyRefresh.Details += "Machine policy refresh initiated successfully"
                Add-Operation -Name "Machine Policy Refresh" -Status "Success" -Details "Policy refresh triggered"
            }
            else {
                $PolicyRefresh.Issues += "Machine policy refresh failed with return value: $($MachinePolicyRefresh.ReturnValue)"
                Add-Operation -Name "Machine Policy Refresh" -Status "Failed" -Details "Return value: $($MachinePolicyRefresh.ReturnValue)"
            }
        }
        catch {
            $PolicyRefresh.Issues += "Error refreshing machine policy: <#
.SCRIPT NAME
		Remediate_SCCM_Client_AppDeployEvalCycle.ps1
    
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
		System Center Configuration Manager client operations. Remediation and repair operations.

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
ExitScript -msg "Script Completed" -code $returnCode"
            Add-Operation -Name "Machine Policy Refresh" -Status "Error" -Details <#
.SCRIPT NAME
		Remediate_SCCM_Client_AppDeployEvalCycle.ps1
    
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
		System Center Configuration Manager client operations. Remediation and repair operations.

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
ExitScript -msg "Script Completed" -code $returnCode
        }
        
        # Refresh user policy for applications if requested
        if ($IncludeUserApps) {
            try {
                $UserPolicyRefresh = Invoke-WmiMethod -Namespace $SCCMClientNamespace -Class "CCM_ClientUtilities" -Name "TriggerSchedule" -ArgumentList "{00000000-0000-0000-0000-000000000026}" -ErrorAction Stop
                
                if ($UserPolicyRefresh.ReturnValue -eq 0) {
                    $PolicyRefresh.UserPolicyRefreshed = $true
                    $PolicyRefresh.Details += "User policy refresh initiated successfully"
                    Add-Operation -Name "User Policy Refresh" -Status "Success" -Details "Policy refresh triggered"
                }
                else {
                    $PolicyRefresh.Issues += "User policy refresh failed with return value: $($UserPolicyRefresh.ReturnValue)"
                    Add-Operation -Name "User Policy Refresh" -Status "Failed" -Details "Return value: $($UserPolicyRefresh.ReturnValue)"
                }
            }
            catch {
                $PolicyRefresh.Issues += "Error refreshing user policy: <#
.SCRIPT NAME
		Remediate_SCCM_Client_AppDeployEvalCycle.ps1
    
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
		System Center Configuration Manager client operations. Remediation and repair operations.

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
ExitScript -msg "Script Completed" -code $returnCode"
                Add-Operation -Name "User Policy Refresh" -Status "Error" -Details <#
.SCRIPT NAME
		Remediate_SCCM_Client_AppDeployEvalCycle.ps1
    
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
		System Center Configuration Manager client operations. Remediation and repair operations.

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
ExitScript -msg "Script Completed" -code $returnCode
            }
        }
        
        # Wait for policy refresh to complete
        if ($PolicyRefresh.MachinePolicyRefreshed -or $PolicyRefresh.UserPolicyRefreshed) {
            Write-LogMessage "Waiting for policy refresh to complete..." -Level Info
            Start-Sleep -Seconds 10
            $PolicyRefresh.Success = $true
        }
    }
    catch {
        $PolicyRefresh.Issues += "Error during policy refresh process: <#
.SCRIPT NAME
		Remediate_SCCM_Client_AppDeployEvalCycle.ps1
    
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
		System Center Configuration Manager client operations. Remediation and repair operations.

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
ExitScript -msg "Script Completed" -code $returnCode"
        Write-LogMessage "Error during policy refresh: <#
.SCRIPT NAME
		Remediate_SCCM_Client_AppDeployEvalCycle.ps1
    
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
		System Center Configuration Manager client operations. Remediation and repair operations.

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
ExitScript -msg "Script Completed" -code $returnCode" -Level Error
    }
    
    return $PolicyRefresh
}

function Invoke-ApplicationDeploymentEvaluationCycle {
    <#
    .SYNOPSIS
        Triggers the SCCM application deployment evaluation cycle.
    #>
    
    Write-LogMessage "Triggering SCCM application deployment evaluation cycle" -Level Info
    
    $EvaluationCycle = @{
        Success = $false
        CycleTriggered = $false
        ReturnValue = $null
        StartTime = Get-Date
        EndTime = $null
        Duration = $null
        Details = @()
        Issues = @()
    }
    
    try {
        # Record pre-evaluation state
        $PreEvalApps = @()
        try {
            $Apps = Get-WmiObject -Namespace "ROOT\CCM\Policy\Machine\ActualConfig" -Class "CCM_ApplicationCIAssignment" -ErrorAction SilentlyContinue
            if ($Apps) {
                $PreEvalApps = $Apps | ForEach-Object { 
                    @{
                        Name = <#
.SCRIPT NAME
		Remediate_SCCM_Client_AppDeployEvalCycle.ps1
    
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
		System Center Configuration Manager client operations. Remediation and repair operations.

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
ExitScript -msg "Script Completed" -code $returnCode.AssignmentName
                        State = <#
.SCRIPT NAME
		Remediate_SCCM_Client_AppDeployEvalCycle.ps1
    
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
		System Center Configuration Manager client operations. Remediation and repair operations.

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
ExitScript -msg "Script Completed" -code $returnCode.AssignmentState
                        IsCompliant = <#
.SCRIPT NAME
		Remediate_SCCM_Client_AppDeployEvalCycle.ps1
    
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
		System Center Configuration Manager client operations. Remediation and repair operations.

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
ExitScript -msg "Script Completed" -code $returnCode.IsCompliant
                    }
                }
            }
        }
        catch {
            Write-LogMessage "Could not capture pre-evaluation application state" -Level Warning
        }
        
        # Trigger the application deployment evaluation cycle
        $CycleResult = Invoke-WmiMethod -Namespace $SCCMClientNamespace -Class "CCM_ClientUtilities" -Name "TriggerSchedule" -ArgumentList $AppDeployEvalGuid -ErrorAction Stop
        
        $EvaluationCycle.ReturnValue = $CycleResult.ReturnValue
        
        if ($CycleResult.ReturnValue -eq 0) {
            $EvaluationCycle.CycleTriggered = $true
            $EvaluationCycle.Details += "Application deployment evaluation cycle triggered successfully"
            Add-Operation -Name "App Deployment Evaluation Cycle" -Status "Triggered" -Details "WMI call successful"
            
            # Monitor evaluation progress
            $MonitorResult = Wait-ForEvaluationCompletion -TimeoutSeconds $Timeout
            
            if ($MonitorResult.Completed) {
                $EvaluationCycle.Success = $true
                $EvaluationCycle.Details += "Evaluation cycle completed successfully"
                Add-Operation -Name "Evaluation Monitoring" -Status "Success" -Details "Cycle completed within timeout"
            }
            else {
                $EvaluationCycle.Issues += "Evaluation cycle timed out or did not complete properly"
                Add-Operation -Name "Evaluation Monitoring" -Status "Warning" -Details "Timeout reached"
            }
        }
        else {
            $EvaluationCycle.Issues += "Failed to trigger evaluation cycle. Return value: $($CycleResult.ReturnValue)"
            Add-Operation -Name "App Deployment Evaluation Cycle" -Status "Failed" -Details "Return value: $($CycleResult.ReturnValue)"
        }
        
        $EvaluationCycle.EndTime = Get-Date
        $EvaluationCycle.Duration = ($EvaluationCycle.EndTime - $EvaluationCycle.StartTime).TotalSeconds
        
        # Capture post-evaluation state for comparison
        try {
            Start-Sleep -Seconds 5  # Allow time for changes to be reflected
            $PostEvalApps = @()
            $Apps = Get-WmiObject -Namespace "ROOT\CCM\Policy\Machine\ActualConfig" -Class "CCM_ApplicationCIAssignment" -ErrorAction SilentlyContinue
            if ($Apps) {
                $PostEvalApps = $Apps | ForEach-Object { 
                    @{
                        Name = <#
.SCRIPT NAME
		Remediate_SCCM_Client_AppDeployEvalCycle.ps1
    
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
		System Center Configuration Manager client operations. Remediation and repair operations.

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
ExitScript -msg "Script Completed" -code $returnCode.AssignmentName
                        State = <#
.SCRIPT NAME
		Remediate_SCCM_Client_AppDeployEvalCycle.ps1
    
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
		System Center Configuration Manager client operations. Remediation and repair operations.

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
ExitScript -msg "Script Completed" -code $returnCode.AssignmentState
                        IsCompliant = <#
.SCRIPT NAME
		Remediate_SCCM_Client_AppDeployEvalCycle.ps1
    
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
		System Center Configuration Manager client operations. Remediation and repair operations.

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
ExitScript -msg "Script Completed" -code $returnCode.IsCompliant
                    }
                }
            }
            
            # Compare states to verify evaluation occurred
            $StateChanges = 0
            foreach ($PreApp in $PreEvalApps) {
                $PostApp = $PostEvalApps | Where-Object { <#
.SCRIPT NAME
		Remediate_SCCM_Client_AppDeployEvalCycle.ps1
    
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
		System Center Configuration Manager client operations. Remediation and repair operations.

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
ExitScript -msg "Script Completed" -code $returnCode.Name -eq $PreApp.Name }
                if ($PostApp -and ($PostApp.State -ne $PreApp.State -or $PostApp.IsCompliant -ne $PreApp.IsCompliant)) {
                    $StateChanges++
                }
            }
            
            if ($StateChanges -gt 0) {
                $EvaluationCycle.Details += "Detected $StateChanges application state changes after evaluation"
                Add-Operation -Name "State Change Verification" -Status "Success" -Details "$StateChanges apps changed state"
            }
        }
        catch {
            Write-LogMessage "Could not verify post-evaluation state changes" -Level Warning
        }
    }
    catch {
        $EvaluationCycle.Issues += "Error triggering application deployment evaluation cycle: <#
.SCRIPT NAME
		Remediate_SCCM_Client_AppDeployEvalCycle.ps1
    
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
		System Center Configuration Manager client operations. Remediation and repair operations.

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
ExitScript -msg "Script Completed" -code $returnCode"
        Write-LogMessage "Error triggering evaluation cycle: <#
.SCRIPT NAME
		Remediate_SCCM_Client_AppDeployEvalCycle.ps1
    
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
		System Center Configuration Manager client operations. Remediation and repair operations.

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
ExitScript -msg "Script Completed" -code $returnCode" -Level Error
        Add-Operation -Name "App Deployment Evaluation Cycle" -Status "Error" -Details <#
.SCRIPT NAME
		Remediate_SCCM_Client_AppDeployEvalCycle.ps1
    
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
		System Center Configuration Manager client operations. Remediation and repair operations.

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
ExitScript -msg "Script Completed" -code $returnCode
    }
    
    return $EvaluationCycle
}

function Wait-ForEvaluationCompletion {
    <#
    .SYNOPSIS
        Monitors the application deployment evaluation cycle for completion.
    #>
    
    param(
        [Parameter(Mandatory = $true)]
        [int]$TimeoutSeconds
    )
    
    Write-LogMessage "Monitoring evaluation cycle completion (timeout: $TimeoutSeconds seconds)" -Level Info
    
    $Monitor = @{
        Completed = $false
        TimedOut = $false
        MonitoredTime = 0
        LastActivity = $null
        Details = @()
    }
    
    $StartTime = Get-Date
    $TimeoutTime = $StartTime.AddSeconds($TimeoutSeconds)
    
    try {
        while ((Get-Date) -lt $TimeoutTime -and -not $Monitor.Completed) {
            Start-Sleep -Seconds 5
            $Monitor.MonitoredTime = ((Get-Date) - $StartTime).TotalSeconds
            
            # Check for evaluation activity in recent log entries
            try {
                $RecentLogs = Get-WinEvent -FilterHashtable @{LogName='Microsoft-Windows-ConfigMgr-ClientAgentRuntime/Admin'; StartTime=(Get-Date).AddMinutes(-2)} -MaxEvents 50 -ErrorAction SilentlyContinue
                
                $EvalActivity = $RecentLogs | Where-Object { 
                    <#
.SCRIPT NAME
		Remediate_SCCM_Client_AppDeployEvalCycle.ps1
    
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
		System Center Configuration Manager client operations. Remediation and repair operations.

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
ExitScript -msg "Script Completed" -code $returnCode.LevelDisplayName -eq 'Information' -and 
                    (<#
.SCRIPT NAME
		Remediate_SCCM_Client_AppDeployEvalCycle.ps1
    
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
		System Center Configuration Manager client operations. Remediation and repair operations.

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
ExitScript -msg "Script Completed" -code $returnCode.Message -like "*application*" -or <#
.SCRIPT NAME
		Remediate_SCCM_Client_AppDeployEvalCycle.ps1
    
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
		System Center Configuration Manager client operations. Remediation and repair operations.

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
ExitScript -msg "Script Completed" -code $returnCode.Message -like "*deployment*" -or <#
.SCRIPT NAME
		Remediate_SCCM_Client_AppDeployEvalCycle.ps1
    
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
		System Center Configuration Manager client operations. Remediation and repair operations.

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
ExitScript -msg "Script Completed" -code $returnCode.Message -like "*evaluation*")
                }
                
                if ($EvalActivity) {
                    $Monitor.LastActivity = $EvalActivity[0].TimeCreated
                    $Monitor.Details += "Recent evaluation activity detected at $($Monitor.LastActivity)"
                }
            }
            catch {
                # Log access might not be available, continue monitoring
            }
            
            # Check if enough time has passed for a typical evaluation
            if ($Monitor.MonitoredTime -gt 30) {
                # Assume completion after reasonable time period
                $Monitor.Completed = $true
                $Monitor.Details += "Evaluation cycle assumed complete after $($Monitor.MonitoredTime) seconds"
                break
            }
        }
        
        if ((Get-Date) -ge $TimeoutTime -and -not $Monitor.Completed) {
            $Monitor.TimedOut = $true
            $Monitor.Details += "Monitoring timed out after $TimeoutSeconds seconds"
        }
    }
    catch {
        $Monitor.Details += "Error during evaluation monitoring: <#
.SCRIPT NAME
		Remediate_SCCM_Client_AppDeployEvalCycle.ps1
    
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
		System Center Configuration Manager client operations. Remediation and repair operations.

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
ExitScript -msg "Script Completed" -code $returnCode"
        Write-LogMessage "Error monitoring evaluation: <#
.SCRIPT NAME
		Remediate_SCCM_Client_AppDeployEvalCycle.ps1
    
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
		System Center Configuration Manager client operations. Remediation and repair operations.

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
ExitScript -msg "Script Completed" -code $returnCode" -Level Warning
    }
    
    return $Monitor
}

function Invoke-RetryOperation {
    <#
    .SYNOPSIS
        Retries the evaluation cycle operation with exponential backoff.
    #>
    
    param(
        [Parameter(Mandatory = $true)]
        [int]$AttemptNumber,
        
        [Parameter(Mandatory = $true)]
        [int]$MaxAttempts
    )
    
    if ($AttemptNumber -gt $MaxAttempts) {
        return $false
    }
    
    $BackoffSeconds = [math]::Min(30, [math]::Pow(2, $AttemptNumber - 1) * 5)
    Write-LogMessage "Retrying operation in $BackoffSeconds seconds (attempt $AttemptNumber of $MaxAttempts)" -Level Info
    
    Start-Sleep -Seconds $BackoffSeconds
    return $true
}

#endregion

#region Main Remediation Logic

try {
    Write-LogMessage "Starting SCCM Application Deployment Evaluation Cycle remediation" -Level Info
    Write-LogMessage "Script version: $ScriptVersion" -Level Info
    Write-LogMessage "Force evaluation: $Force" -Level Info
    Write-LogMessage "Include user apps: $IncludeUserApps" -Level Info
    Write-LogMessage "Timeout: $Timeout seconds" -Level Info
    Write-LogMessage "Retry attempts: $RetryAttempts" -Level Info
    
    # Validate SCCM client readiness
    $ClientReadiness = Test-SCCMClientReady
    $RemediationResult.Results.ClientReadiness = $ClientReadiness
    
    if ($ClientReadiness.Issues.Count -gt 0) {
        Write-LogMessage "SCCM client readiness issues detected" -Level Warning
        $RemediationResult.Issues += $ClientReadiness.Issues
        
        if (-not $ClientReadiness.WMIAccessible) {
            throw "SCCM client WMI access not available - cannot proceed with remediation"
        }
    }
    
    if (-not $ClientReadiness.ServiceRunning) {
        Write-LogMessage "SCCM client service is not running - attempting to start" -Level Warning
        try {
            Start-Service -Name "CcmExec" -ErrorAction Stop
            Start-Sleep -Seconds 10
            Add-Operation -Name "SCCM Service Start" -Status "Success" -Details "Service started successfully"
        }
        catch {
            Add-Operation -Name "SCCM Service Start" -Status "Failed" -Details <#
.SCRIPT NAME
		Remediate_SCCM_Client_AppDeployEvalCycle.ps1
    
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
		System Center Configuration Manager client operations. Remediation and repair operations.

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
ExitScript -msg "Script Completed" -code $returnCode
            throw "Cannot start SCCM client service: <#
.SCRIPT NAME
		Remediate_SCCM_Client_AppDeployEvalCycle.ps1
    
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
		System Center Configuration Manager client operations. Remediation and repair operations.

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
ExitScript -msg "Script Completed" -code $returnCode"
        }
    }
    
    # Main remediation loop with retry logic
    $AttemptNumber = 1
    $Success = $false
    
    while ($AttemptNumber -le $RetryAttempts -and -not $Success) {
        Write-LogMessage "Starting remediation attempt $AttemptNumber of $RetryAttempts" -Level Info
        
        try {
            # Step 1: Refresh application policies
            $PolicyRefresh = Start-ApplicationPolicyRefresh
            $RemediationResult.Results["PolicyRefresh_Attempt$AttemptNumber"] = $PolicyRefresh
            
            if ($PolicyRefresh.Issues.Count -gt 0) {
                Write-LogMessage "Policy refresh issues detected" -Level Warning
                $RemediationResult.Issues += $PolicyRefresh.Issues
            }
            
            # Step 2: Trigger application deployment evaluation cycle
            $EvaluationCycle = Invoke-ApplicationDeploymentEvaluationCycle
            $RemediationResult.Results["EvaluationCycle_Attempt$AttemptNumber"] = $EvaluationCycle
            
            if ($EvaluationCycle.Success) {
                $Success = $true
                $RemediationResult.Success = $true
                $RemediationResult.ExitCode = 0
                Write-LogMessage "SCCM application deployment evaluation cycle completed successfully" -Level Info
                Add-Operation -Name "Overall Remediation" -Status "Success" -Details "Evaluation cycle completed in attempt $AttemptNumber"
                break
            }
            elseif ($EvaluationCycle.CycleTriggered) {
                # Partial success - cycle was triggered but monitoring had issues
                $Success = $true
                $RemediationResult.Success = $true
                $RemediationResult.ExitCode = 2
                Write-LogMessage "SCCM evaluation cycle triggered but monitoring incomplete" -Level Warning
                Add-Operation -Name "Overall Remediation" -Status "Partial Success" -Details "Cycle triggered, monitoring incomplete"
                break
            }
            else {
                $RemediationResult.Issues += $EvaluationCycle.Issues
                
                if ($AttemptNumber -lt $RetryAttempts) {
                    if (Invoke-RetryOperation -AttemptNumber $AttemptNumber -MaxAttempts $RetryAttempts) {
                        $AttemptNumber++
                        continue
                    }
                }
            }
        }
        catch {
            $ErrorMessage = "Error in remediation attempt $AttemptNumber`: <#
.SCRIPT NAME
		Remediate_SCCM_Client_AppDeployEvalCycle.ps1
    
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
		System Center Configuration Manager client operations. Remediation and repair operations.

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
ExitScript -msg "Script Completed" -code $returnCode"
            Write-LogMessage $ErrorMessage -Level Error
            $RemediationResult.Issues += $ErrorMessage
            
            if ($AttemptNumber -lt $RetryAttempts) {
                if (Invoke-RetryOperation -AttemptNumber $AttemptNumber -MaxAttempts $RetryAttempts) {
                    $AttemptNumber++
                    continue
                }
            }
        }
        
        $AttemptNumber++
    }
    
    # Final result evaluation
    if (-not $Success) {
        $RemediationResult.ExitCode = 1
        $RemediationResult.RecommendedActions += "Manual investigation required - automatic remediation failed"
        $RemediationResult.RecommendedActions += "Check SCCM client logs and WMI functionality"
        $RemediationResult.RecommendedActions += "Verify network connectivity to management point"
        
        Write-LogMessage "Failed to complete SCCM application deployment evaluation cycle after $RetryAttempts attempts" -Level Error
        Add-Operation -Name "Overall Remediation" -Status "Failed" -Details "All retry attempts exhausted"
    }
    
    # Add final recommendations
    if ($RemediationResult.Success) {
        $RemediationResult.RecommendedActions += "Monitor application deployment status through SCCM console"
        $RemediationResult.RecommendedActions += "Verify application compliance after evaluation cycle"
    }
    
    Write-LogMessage "SCCM Application Deployment Evaluation Cycle remediation completed" -Level Info
}
catch {
    $ErrorMessage = "Critical error during SCCM remediation: <#
.SCRIPT NAME
		Remediate_SCCM_Client_AppDeployEvalCycle.ps1
    
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
		System Center Configuration Manager client operations. Remediation and repair operations.

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
ExitScript -msg "Script Completed" -code $returnCode"
    Write-LogMessage $ErrorMessage -Level Error
    
    $RemediationResult.Success = $false
    $RemediationResult.ExitCode = 99
    $RemediationResult.Issues += $ErrorMessage
    $RemediationResult.RecommendedActions += "Investigate and resolve critical script execution errors"
    Add-Operation -Name "Overall Remediation" -Status "Critical Error" -Details <#
.SCRIPT NAME
		Remediate_SCCM_Client_AppDeployEvalCycle.ps1
    
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
		System Center Configuration Manager client operations. Remediation and repair operations.

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
ExitScript -msg "Script Completed" -code $returnCode
    
    Write-EventLogEntry -Message $ErrorMessage -EntryType Error -EventId 2001
}

#endregion

#region Output Generation

try {
    $OutputData = @"
SCCM Application Deployment Evaluation Cycle Remediation Results
===============================================================
Generated: $($RemediationResult.Timestamp)
Computer: $($RemediationResult.ComputerName)
Script Version: $($RemediationResult.ScriptVersion)

REMEDIATION SUMMARY
Success: $($RemediationResult.Success)
Exit Code: $($RemediationResult.ExitCode)

OPERATIONS PERFORMED
$($RemediationResult.Operations | ForEach-Object { 
    "[$(<#
.SCRIPT NAME
		Remediate_SCCM_Client_AppDeployEvalCycle.ps1
    
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
		System Center Configuration Manager client operations. Remediation and repair operations.

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
ExitScript -msg "Script Completed" -code $returnCode.Timestamp)] $(<#
.SCRIPT NAME
		Remediate_SCCM_Client_AppDeployEvalCycle.ps1
    
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
		System Center Configuration Manager client operations. Remediation and repair operations.

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
ExitScript -msg "Script Completed" -code $returnCode.Name): $(<#
.SCRIPT NAME
		Remediate_SCCM_Client_AppDeployEvalCycle.ps1
    
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
		System Center Configuration Manager client operations. Remediation and repair operations.

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
ExitScript -msg "Script Completed" -code $returnCode.Status) $(if(<#
.SCRIPT NAME
		Remediate_SCCM_Client_AppDeployEvalCycle.ps1
    
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
		System Center Configuration Manager client operations. Remediation and repair operations.

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
ExitScript -msg "Script Completed" -code $returnCode.Details) { "- $(<#
.SCRIPT NAME
		Remediate_SCCM_Client_AppDeployEvalCycle.ps1
    
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
		System Center Configuration Manager client operations. Remediation and repair operations.

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
ExitScript -msg "Script Completed" -code $returnCode.Details)" })"
} | Out-String)

DETECTED ISSUES
$($RemediationResult.Issues | ForEach-Object { "- <#
.SCRIPT NAME
		Remediate_SCCM_Client_AppDeployEvalCycle.ps1
    
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
		System Center Configuration Manager client operations. Remediation and repair operations.

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
ExitScript -msg "Script Completed" -code $returnCode" } | Out-String)

RECOMMENDED ACTIONS
$($RemediationResult.RecommendedActions | ForEach-Object { "- <#
.SCRIPT NAME
		Remediate_SCCM_Client_AppDeployEvalCycle.ps1
    
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
		System Center Configuration Manager client operations. Remediation and repair operations.

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
ExitScript -msg "Script Completed" -code $returnCode" } | Out-String)
"@
    
    Write-Output $OutputData
    
    # Log final result
    $ResultMessage = "SCCM Application Deployment Evaluation Cycle remediation completed. Success: $($RemediationResult.Success), Exit Code: $($RemediationResult.ExitCode)"
    Write-EventLogEntry -Message $ResultMessage -EntryType Information -EventId 2000
}
catch {
    Write-LogMessage "Error generating output: <#
.SCRIPT NAME
		Remediate_SCCM_Client_AppDeployEvalCycle.ps1
    
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
		System Center Configuration Manager client operations. Remediation and repair operations.

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
ExitScript -msg "Script Completed" -code $returnCode" -Level Error
    Write-Output "Error: Failed to generate remediation output"
    exit 99
}

#endregion

exit $RemediationResult.ExitCode
        
        LogWrite "Completed system center configuration manager client operations"
        $returnCode = 0
    }
} catch {
    LogWrite "Error: Unexpected error in main script: $(<#
.SCRIPT NAME
		Remediate_SCCM_Client_AppDeployEvalCycle.ps1
    
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
		System Center Configuration Manager client operations. Remediation and repair operations.

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
