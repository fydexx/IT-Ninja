<# 
.SYNOPSIS
	New-SQLInstall performs a new MS SQL Server installation using parameters from an XML element.  
.DESCRIPTION
	Recieves an XML element from STIG-ServerStandup and performs an MS SQL Server installation.
.NOTES  
	Author        : Dan Meier  
	Assumptions   :
		This script is only called for the first time installation of SQL on a brand new server (so there is no possibility of other installs in the summary.txt file)
		There is only one summary.txt file
.EXAMPLE
	$SQLNode = $XMLParams.params.MSSQL.Install
	if ($SQLNode) {
		New-SQLInstall $SQLNode
	}
.INPUTS
    [xml]$SQLNode an xml element like:
	<MSSQL>
		<Install>
			<ININame>INIFiles\@@@SQL_EDITION@@@.ini</ININame>
			<EXEName>setup.exe</EXEName>
			<Argument>/Q</Argument>
			<Argument>/UpdateEnabled=True</Argument>
			<Argument>/UpdateSource=..\UpdateSource</Argument>
			<Argument>/SQLSVCPASSWORD="@@@SQLSVCPASSWORD@@@"</Argument>
			<Argument>/PID="@@@SQLPRODUCTID@@@"</Argument>
			<Argument>/AGTSVCPASSWORD="@@@AGTSVCPASSWORD@@@"</Argument>
			<Argument>/SAPWD="@@@SAPWD@@@"</Argument>
			<LocalFolderName>SQLExtractedFiles</LocalFolderName>
		</Install>
	</MSSQL>
	
	Assumes these variables are defined (by calling script):
	$LoggingCheck
	$LFName
	$TempFldrPath
	$PakPath
.OUTPUTS
    Returns a 0 for success; 1 for failure. Writes to the console any failure messages, logs to a log file other informational messages.
#>
Function New-SQLInstall {
param (
	[System.Xml.XmlElement]$SQLNode
)
	LLTraceMsg -InvocationInfo $MyInvocation

if ($LoggingCheck) {
	ToLog -LogFile $LFName -EventID $LLINFO -Text "MS SQL Server is requested to install."
}
	$retcode = 0 #For debugging PostInstall
if ((gwmi Win32_Product | ? {$_.name -Like "*SQL*Engine*"})) {
	if ($LoggingCheck) {ToLog -LogFile $LFName -EventID $INFO -Text "MS SQL Server was found, and will not install."}
	Write-Host "MS SQL Server was requested to install but is already installed, no action taken."
	$retcode = 1 #Was return 1 changed for debugging PostInstall
}

if ($LoggingCheck) {ToLog -LogFile $LFName -Text "MS SQL Server was not found, and will install."}

# Setup SQL install command line
	$CArgs = $SQLNode.Install.Argument
	$BinName = $SQLNode.Install.EXEName
	$SQL_ININame = $SQLNode.Install.ININame
	if (($SQL_ININame -ne "") -or ($SQL_ININame -ne $null)) {
		$SQL_LocalINIFile = Join-Path $TempFldrPath $SQL_ININame
		if (!(Test-Path $SQL_LocalINIFile)) {
			ToLog -LogFile $LFName -EventID $FAILURE -Text "FAILURE:: MS SQL Server ini file defined, but can not be found!! `'$SQL_LocalINIFile`'."
			Write-Host "FAILURE:: MS SQL Server ini file defined, but can not be found!! `'$SQL_LocalINIFile`'."
			throw "FAILURE:: MS SQL Server ini file defined, but can not be found!! `'$SQL_LocalINIFile`'."
		} else {
			$CLA = "/ConfigurationFile=`"$SQL_LocalINIFile`" "
		}
	} else {
		$CLA = ""
	}

	# Validate that there is a SQL installer at the specified command path
	$SQL_Local_Folder = Join-Path $TempFldrPath ($SQLNode.Install.LocalFolderName)
	if (!(test-path $SQL_Local_Folder)) {
		#$SkipSQLInstallTry = 1
		if ($LoggingCheck) {ToLog -LogFile $LFName -EventID $FAILURE -Text "FAILURE:: MS SQL Server local folder was not found!! can not install! `'$SQL_Local_Folder`'."}
		write-host "FAILURE:: MS SQL Server local folder was not found!! can not install! `'$SQL_Local_Folder`'."
		$retcode = 1 #Was return 1 changed for debugging PostInstall
	}
	
	if($retcode -eq 0){ #for debugging PostInstall
# Add arguments to command line
	if ($CArgs) {
		foreach ($argu in $CArgs) {
			$CoA = $argu
			if ($CoA -eq "/Package %:PACKAGELOCALPATH%") {
				$PakPath = Join-Path $TempFldrPath $BinName
				$CoA = $CoA.Replace("/Package %:PACKAGELOCALPATH%", "/Package `'$PakPath`'")
			}
			$CLA += $CoA + " "
		}
		$CLA = $CLA.TrimEnd(" ")
	}
	
# If /UpdateSource is specified ensure there is a folder, doesn't have to have anything in it, but if the folder isn't there, quit without installing.
	
	$UpdSrcRegex = [regex]'(.*/UpdateSource=)(.*?)(\s.*)'
	if( $UpdSrcRegex.match($CLA).Success ) { #Then it is specified
		$UpdSrcPath = [regex]::match($CLA,$UpdSrcRegex).Groups[2].Value
		
        $UpdatePath = Join-Path $TempFldrPath $UpdSrcPath
		if (!(Test-Path $UpdatePath)) { #It's not there
			if ($LoggingCheck) {ToLog -LogFile $LFName -EventID $FAILURE -Text "FAILURE:: UpdateSource ($UpdatePath) was specified but the folder does not exist"}
			[Environment]::Exit(1)
		} else {
            $CLA = $CLA -replace $UpdSrcRegex,'$1&$3'
            $CLA = $CLA -replace "&",$UpdatePath
        }
	}

# Execute the command line
	$LogPath = "C:\Program Files\Microsoft SQL Server\*\Setup Bootstrap\Log\Summary.txt"
	try {
		LaunchProcessAndWait -Destination $SQL_Local_Folder -FileName $BinName -CommandLineArgs $CLA

		#Validate installed patch level
		if ($SQLNode.Validate.ReqdPatchLevel) {
			$SQLAcct = $SQLNode.Validate.SQLCreds.Username
			$SQLPwd = $SQLNode.Validate.SQLCreds.Password
			if ($SQLAcct -and $SQLPwd) {
				if (Test-IsSQLVersionInstalled -TestVersion $SQLNode.Validate.ReqdPatchLevel -SQLAcct $SQLAcct -SQLPwd $SQLPwd ) {
					$InstalledPatchLevel = Get-SQLVersion -SQLAcct $SQLAcct -SQLPwd $SQLPwd
				} else {
					$InstalledPatchLevel = "was not found"
				}
			} else {
				$errstr = "Insufficient credentials provided for accessing SQL. Validation check skipped."
				if ($LoggingCheck) {ToLog -LogFile $LFName -EventID $INFO -Text $errstr }
				return 1
			}
		}
	} catch {
		# Let's try to provide some useful information
		# Let's see if the last line of the summary.txt is a useful error message
		if( Test-Path $LogPath) {
			Write-Host "----------------------- SQL Summary.txt last 15 -----------------------------------------"
			Get-Content $LogPath | Select-Object -Last 15
			Write-Host "-----------------------------------------------------------------------------------------"
		}
		throw
	}
	} #for debugging PostInstall
# Run Post-Install *.sql Scripts
	if ($SQLNode.PostInstall) {
		foreach($Script in $SQLNode.PostInstall.Script){
			$ScriptPath = Join-Path $pwd $Script.Path
			foreach($file in (Get-ChildItem $ScriptPath | Sort-Object Fullname)){
				$ScriptCmd = "$($Script.Cmd) $($file.Fullname)"
				ToLog -LogFile $LFName -EventID $LLINFO -Text "Preparing to run $ScriptCmd."
				$result = Invoke-Expression $ScriptCmd
				ToLog -LogFile $LFName -EventID $LLINFO -Text "Result of $ScriptCmd = $result."
			}
		}
	}
}
<#
.SYNOPSIS
	New-SQLManagedObjects is the interface to load the sqlps Powershell module (Available in SQL versions 2012+)
.DESCRIPTION
    New-SQLManagedObjects is used to perform operations where the SQL Server Module is required. Any/all operations requiring "sqlps" module should be loaded from within this function 
	
.NOTES  
    File Name  : STIG-SQL-Install.ps1  
	Author  : Todd Pluciennik (New-SQLManagedObjects function)
    Date	: 5/2/2014 
.Link
	http://msdn.microsoft.com/en-us/library/hh231286.aspx
.PARAMETER None
	No parameters needed
#>
Function New-SQLManagedObjects
{
param (
	[System.Xml.XmlElement]$SQLNode
)
	LLTraceMsg -InvocationInfo $MyInvocation

    # import powershell module; first find/set module path
    $SQLRootDrives = @("D","C") # available install paths 
    $FoundSQL = $false
    foreach ($Drive in $SQLRootDrives ) {
        $sqlpsPath = (Get-ChildItem -Recurse -Force  "${Drive}:\Program Files (x86)\Microsoft SQL Server\" | Where-Object { ($_.PSIsContainer -eq $true) -and  ( $_.Name -like "*Powershell*") }).FullName
        $env:PSModulePath = $env:PSModulePath + ";$sqlpsPath\Modules"
        $sqlpsCheck = Get-Module -ListAvailable -Name sqlps
        if ($sqlpsCheck) { 
            $FoundSQL = $true
            break
            }
    }
	if (!$FoundSQL) {
		if ($LoggingCheck) {ToLog -LogFile $LFName -Text "FAILURE:: MS SQL was not installed properly, cannot load Powershell module (sqlps) within path ($env:PSModulePath). Aborting script"}
	} else {
        # import the module, this will change path to the PS SQLSERVER:\> container
		Import-Module -Name sqlps -DisableNameChecking
        
        ## STIG-ManageSQL.ps1 library
        # SQL-AlwaysOn
        $SQLAlwaysOn = $SQLNode | ? {$_.Name -eq "SQL$T-AlwaysOn"}
	    if ($SQLAlwaysOn) {
            $SQLAlwaysOnAction = $SQLAlwaysOn.Action
            # path is pulled from local installation / instance
            # e.g. Enable-SqlAlwaysOn -Path SQLSERVER:\SQL\Computer\Instance
            $SQLPath = gci SQL -name
            $SQLAlwaysOnPath  = "SQLSERVER:\SQL\${SQLPath}\DEFAULT"
            ConfigureSQLAlwaysOn -Action $SQLAlwaysOnAction -Path $SQLAlwaysOnPath
        }
	}
}
<#
.SYNOPSIS
	Test-IsSQLVersionInstalled queries the SQL database for the SQL Version number and compares it to a desired-state version and returns a true if the installed version is more up-to-date than the desired state.
.DESCRIPTION
	Test-IsSQLVersionInstalled came about because the previous method of determining if SP1 had been applied was to look at the gwmi Win32_Product | Where-Object {$_.name -Like "*SQL*2008*SP1*"}
	However apparently after SP2 is installed any reference to SP1 is destroyed. So the above test would fail after SP2 was installed and SP1 would try to install again and would
	apparently hang waiting for user recognition of the message box saying, "um, are you sure you want to do this?"

    Currently account and password are not required as we are getting the version information from Get-WMiObject to retrieve the install engine file version.
.NOTES  
    File Name  : STIG-SQL-Install.ps1  
	Author  : Dan Meier
    Date	: 5/2/2014 
.Link
	http://sqlserverbuilds.blogspot.com/ List of SQL Server build numbers
.EXAMPLE
	The following command tests to see if SQL Server 2008 R2 SP1 (or later) is installed.
	Test-IsSQLVersionInstalled -TestVersion "10.50.2500" -SQLAcct "sa" -SQLPwd "a0a8-avna84r32rfma*&(&*%jhdf"
.EXAMPLE
	The following command tests to see if SQL Server 2008 R2 hotfix 2633357 is installed.
	Test-IsSQLVersionInstalled -TestVersion "10.50.2799" -SQLAcct "sa" -SQLPwd "a0a8-avna84r32rfma*&(&*%jhdf"
.EXAMPLE
    Test-IsSQLVersionInstalled -TestVersion "10.50.2500"
.PARAMETER TestVersion
	The version string that you want to check for. Will return true if this version or later is installed.
.PARAMETER SQLAcct
	An account name to authenticate to the SQL server with. Default is "sa"
.PARAMETER SQLPwd
	The password to use with SQLAcct.
#>
function Test-IsSQLVersionInstalled {
param(
    [Parameter(Mandatory=$true)] [string]$TestVersion,
	[Parameter()] [string]$SQLAcct,
	[Parameter()] [string]$SQLPwd
)
	LLTraceMsg -InvocationInfo $MyInvocation

    $MAJOR = 0
    $MINOR = 1
    $BUILD = 2
    $REV = 3

    # Get the SQL version string. It should be in format "mm.nn.bbbb", e.g.: 10.52.4000
	    if($SQLAcct -and $SQLPwd) {
	    $SQLVersion = Get-SQLVersion -SQLAcct $SQLAcct -SQLPwd $SQLPwd
    } else {
        $SQLVersion = (gwmi Win32_Product | Where-Object {$_.name -like "*SQL*2008*Engine*"} | Select -First 1).Version
    }

    # Break it up into individual elements as separated by the period
    $TestArray = $TestVersion -split "\."
    $ActArray = $SQLVersion -split "\." 

    # Convert it to integer to make difference comparison rational (i.e.: 9 is less than 10, but "9" is greater than "10")
    [int[]] $iActual = 0,0,0,0
    [int[]] $iTest = 0,0,0,0

    for($i=0; $i -le $REV; $i++) {
        $iActual[$i] = $ActArray[$i] -As [int]
        $iTest[$i] = $TestArray[$i] -As [int]
    }

    # Initialize our output variable; just to ensure that we set it below and don't inherit it from a previous usage.
    $UpToDate = $false

	# Sanity check - if the major versions mismatch, throw an error, caller was expecting something wildly different
	if ($iActual[$MAJOR] -ne $iTest[$MAJOR] ) {
		$errmsg = "FAILURE::A SQL version comparison was requested and the expected major version number ($TestVersion) does not equal the actual major version number ($SQLVersion)."
		if ($LoggingCheck) {ToLog -LogFile $LFName -EventID $FAILURE -Text $errmsg }
		throw $errmsg
	}

    # Compare the values
    if ( ($iActual[$Major] -eq $iTest[$Major] ) -and
         ($iActual[$Minor] -ge $iTest[$Minor] ) -and
         ($iActual[$Build] -ge $iTest[$Build] ) ) {

         $UpToDate = $true
    } else {
        $UpToDate = $false
    }

    # Return our finding
    return $UpToDate
}
function Get-SQLVersion {
param(
	[Parameter()] [string]$SQLAcct,
	[Parameter()] [string]$SQLPwd
)
	LLTraceMsg -InvocationInfo $MyInvocation

	$env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine")
	$sqlcmd = "sqlcmd -U $SQLAcct -P $SQLPwd -Q `"SELECT SERVERPROPERTY('productversion')`" -Y 15"
	$result = Invoke-Expression $sqlcmd 
	$regex = [RegEx]'\d+\.\d+\.\d+\.\d+'
	$SQLVersion = $regex.Match($result).Groups[0].Value
	return $SQLVersion
}
