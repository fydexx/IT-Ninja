Function AddWebConfigParser {
param( [System.Xml.XMLElement]$ConfigInfo )

	#Parse the XML Element into a PSPath String and a Value Hashtable
	$PSPath = $ConfigInfo.PSPath
	$ParamHash = @{}
	$ParamArray = $ConfigInfo.ParamHash -Split ";"
	foreach($KeyValuePair in $ParamArray){
		$Key = ($KeyValuePair -Split "=")[0]
		$Val = ($KeyValuePair -Split "=")[1]
		$ParamHash.Add($Key,$Val)
	}

	LLToLog -EventID $LLTRACE -Text "Performing Add-Webconfiguration on $PSPath with $($ConfigInfo.ParamHash)"
	AddWebConfiguration -PSPath $PSPath -Value $ParamHash
}
Function AddWebConfiguration {
param(
	[Parameter()] [string]$PSPath,
	[Parameter()] [hashtable]$Value
)
	Add-WebConfiguration $PSPath -Value $Value
}
Function SetWebConfigurationProperty {
param(
	[Parameter()] [string]$Filter,
	[Parameter()] [string]$Name,
	[Parameter()] [string]$Value
)
	Set-WebConfigurationProperty -Filter $Filter -Name $Name -Value $Value
}
#region Unit Test
# Test Code
# The following test checks to see if this script was sourced (to provide access to the functions to a master script)
# or run directly from the command-line. If run from the command-line then run the test code below.
if ($MyInvocation.InvocationName -eq ".") {$Script:RunMode = "Sourced" } else {$Script:RunMode = "Standalone"}
if($Script:RunMode -ne "Sourced") {
	$XMLFile = $args[0]
	#Read the XML file
	[xml]$XMLParams = gc $XMLFile
	
	$AddConfColl = $XMLParams.params.IIS.AddWebConfiguration
	ForEach ($AddConfig in $AddConfColl) {
		$PSPath = $AddConfig.PSPath
		$AddValue = $AddConfig.Value
		
		$CmdHash = @{}
		if($PSPath) { $CmdHash.Add( "-PSPath","$PSPath" ) }
		if($AddValue) { $CmdHash.Add( "-Value","$AddValue" ) }

		AddWebConfiguration @CmdHash
	}
	
	$SetConfColl = $XMLParams.params.IIS.AddWebConfiguration
	ForEach ($SetConfig in $SetConfColl) {
		$Filter = $SetConfig.Filter
		$Name = $SetConfig.Name
		$Value = $SetConfig.Value
		
		$CmdHash = @{}
		if($Filter) { $CmdHash.Add( "-Filter","$Filter") }
		if($Name) { $CmdHash.Add( "-Name","$Name") }
		if($Value) { $CmdHash.Add( "-Value","$Value") }
		
		SetWebConfigurationProperty @CmdHash
	}
}
#endregion