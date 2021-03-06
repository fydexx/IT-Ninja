param([String]$XMLType, [String]$EnvName, [String]$XMLPath, [String]$AppName, [String]$SiteRoot)
#region Global Variables
<# 
.SYNOPSIS
	STIG-XMLHandler identifies or if need be creates the XML file to be used by STIG-ServerStandup.ps1
.DESCRIPTION
	This script is used to identify the proper xml to be used by the STIG server standup by taking the App properties from UrbanCode Deploy.
    Additionally, if the envName in Deploy is set to Deprecated, it will generate Deprecation XMLS on the server and point to STIG server standup to them.
.NOTES  
	Author        : Michael Gutierrez
	Assumptions   :
		The script is being run by UrbanCode Deploy on the target server.
.OUTPUTS
    Returns the path to an xml to be used by STIG-ServerStandup.ps1
    In case of Deprecation, it will also output the generated files to the appropriate location
.PARAMETER XMLType
    The type of XML to handle (WebServer, MSMQServer, or SetParameter)
.PARAMETER EnvName
    Name of the environment in UrbanCode Deploy (The property envName specifically)
.PARAMETER XMLPath
    Path to the XML file
.PARAMETER AppName
    The name of the application
.PARAMETER SiteRoot
    Name of the root site the application belongs to.
.EXAMPLE
    STIG-XMLHandler.ps1 -XMLType WebServer -EnvName Deprecated -XMLPath C:\udeploy-agent\var\work\SOA_APP_ActivityEngine -AppName ActivityEngine -SiteRoot InternalServices
#>

#Determin what kind of XML type to handle

switch ($XMLType)
{
    "WebServer" {$xml = "WebServer.xml"}
    "MSMQServer" {$xml = "MSMQServer.xml"}
    "SetParameters" {$xml = "SetParameters.xml"}
    default 
    {
        Write-Host "Stopping script.`nPlease provide an XMLType"
        exit 1
    }
}

#Set some global variables
$xmlFile = join-path $XMLPath $xml
$AppCMD = "C:\Windows\System32\inetsrv\appcmd.exe"

#Create and deliver deprecated XMLs
if ($EnvName -eq "Deprecated")
{
    try
    {    
        $xml = "Deprecated.$xml" 
        $xmlFile = join-path $XMLPath $xml
        Write-Host "Generating Deprecation XML File for $XMLType"
        if ($XMLType -eq "WebServer")
        {

            Write-Host "Aquiring MSMQ Service name from current WebServer.xml"
            $CurrentXMLPath = join-path $XMLPath "WebServer.xml"
            [xml]$CurrentXML = Get-Content -Path $CurrentXMLPath
            if ($CurrentXML.params.MSMQQueue.Queue.Name)
            {
                $MSMQServiceName = $CurrentXML.params.MSMQQueue.Queue.Name
            }
            else
            {
                $MSMQServiceName = ""
            }
            
            Write-Host "Aquiring App Pool name for $AppName"            Import-Module WebAdministration
            $AppObj = Get-WebApplication -Site $SiteRoot -Name $AppName
            $AppPoolName = $AppObj.applicationPool
            $AppPoolDelete = $true
            
            Write-Host "Ensuring no other applications are using the $AppPoolName application pool"
            foreach ($App in Get-WebApplication -Site $SiteRoot)
            {
                if ($App.applicationPool -eq $AppPoolName -And $App.path.Substring(1) -ne $AppName)
                {
                    $AppPoolDelete = $false
                    break
                }
            }
            if ($AppPoolDelete -eq $true -And $MSMQServiceName -ne "")
            {
$WebXML = @"
<?xml version="1.0" encoding="utf-8"?>
<params Version="1.9">
  <Folders>
    <!--Leave the folder alone. Also, Dont remove it from any version of this file-->
    <Includes>Includes</Includes>
    <Temp>tmp</Temp>
  </Folders>
  <IIS>
    <WebApp>
      <App Action="Delete" Path="IIS:\Sites\$SiteRoot\$AppName" AppPool="$AppPoolName" DeletePhysical="True" />
    </WebApp>
    <ManageAppPool>
      <Pool Action="Delete" NAME="$AppName" NETVer="v4.0" IDType="SpecificUser" />
    </ManageAppPool>
  </IIS>
  <MSMQQueue>
    <Queue Action="Delete" Name="$MSMQServiceName" />
  </MSMQQueue>
</params>
"@ | Out-File -filepath $xmlFile
            write-host "XML file used: $xmlFile"
            return $xmlFile 
            }
            elseif ($AppPoolDelete -eq $false -And $MSMQServiceName -ne "")
            {
$WebXML = @"
<?xml version="1.0" encoding="utf-8"?>
<params Version="1.9">
  <Folders>
    <!--Leave the folder alone. Also, Dont remove it from any version of this file-->
    <Includes>Includes</Includes>
    <Temp>tmp</Temp>
  </Folders>
  <IIS>
    <WebApp>
      <App Action="Delete" Path="IIS:\Sites\$SiteRoot\$AppName" AppPool="$AppPoolName" DeletePhysical="True" />
    </WebApp>
  </IIS>
  <MSMQQueue>
    <Queue Action="Delete" Name="$MSMQServiceName" />
  </MSMQQueue>
</params>
"@ | Out-File -filepath $xmlFile
            write-host "XML file used: $xmlFile"
            return $xmlFile 
            }
            elseif ($AppPoolDelete -eq $true -And $MSMQServiceName -eq "")
            {
$WebXML = @"
<?xml version="1.0" encoding="utf-8"?>
<params Version="1.9">
  <Folders>
    <!--Leave the folder alone. Also, Dont remove it from any version of this file-->
    <Includes>Includes</Includes>
    <Temp>tmp</Temp>
  </Folders>
  <IIS>
    <WebApp>
      <App Action="Delete" Path="IIS:\Sites\$SiteRoot\$AppName" AppPool="$AppPoolName" DeletePhysical="True" />
    </WebApp>
    <ManageAppPool>
      <Pool Action="Delete" NAME="$AppName" NETVer="v4.0" IDType="SpecificUser" />
    </ManageAppPool>
  </IIS>
</params>
"@ | Out-File -filepath $xmlFile
            write-host "XML file used: $xmlFile"
            return $xmlFile 
            }
            else
            {
$WebXML = @"
<?xml version="1.0" encoding="utf-8"?>
<params Version="1.9">
  <Folders>
    <!--Leave the folder alone. Also, Dont remove it from any version of this file-->
    <Includes>Includes</Includes>
    <Temp>tmp</Temp>
  </Folders>
  <IIS>
    <WebApp>
      <App Action="Delete" Path="IIS:\Sites\$SiteRoot\$AppName" AppPool="$AppPoolName" DeletePhysical="True" />
    </WebApp>
  </IIS>
</params>
"@ | Out-File -filepath $xmlFile
            write-host "XML file used: $xmlFile"
            return $xmlFile 
            }

        }
        elseif ($XMLType -eq "MSMQServer")
        {
            $xml = "Deprecated.$xml"
            $CurrentMSMQXMLPath = join-path $XMLPath "MSMQServer.xml"
            [xml]$CurrentMSMQXML = Get-Content -Path $CurrentMSMQXMLPath
            $MSMQServiceName = $CurrentMSMQXML.params.MSMQQueue.Queue.Name
$WebXML = @"
<?xml version="1.0" encoding="utf-8"?>
<params Version="1.9">
  <Folders>
    <!--Leave the folder alone. Also, Dont remove it from any version of this file-->
    <Includes>Includes</Includes>
    <Temp>tmp</Temp>
  </Folders>
  <MSMQQueue>
    <Queue Action="Delete" Name="$MSMQServiceName" />
  </MSMQQueue>
</params>
"@ | Out-File -filepath $xmlFile
            write-host "XML file used: $xmlFile"
            return $xmlFile
        }
        else
        {
            $WebXML = "" | Out-File -filepath $xmlFile
            write-host "XML file used: $xmlFile"
            return $xmlFile
        }
    }
    catch [Exception]
    {
        Write-Host "FAILURE:: Failed to generate Deprecated XML with the following error...`n $_.Exception.Message"
    }
}
else
{
    try
    {
        Write-Host "Identifying appropriate xml file to use."
        if ($EnvName -ne "PROD") { 
        $xml = "nonprod.$XMLType.xml" 
        $testPath = join-path $XMLPath $xml
        if (test-path $testPath -pathType leaf) { $xmlFile = $testPath }
        }
        $xml = "$envName.$XMLType.xml"
        $testPath = join-path $XMLPath $xml
        if (test-path $testPath -pathType leaf) { $xmlFile = $testPath }
        write-host "XML file used: $xmlFile"
        return $xmlFile
    }
    catch [Exception]
    {
        Write-Host "FAILURE::Failed to identify the proper XML with the following error... $_.Exception.Message"
    }
}