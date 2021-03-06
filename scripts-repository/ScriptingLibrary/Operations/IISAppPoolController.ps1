param (
    [Parameter(Mandatory=$true)] [string]$AppPoolAction,
    [Parameter(Mandatory=$true)] [string]$AppPoolString
)

$ExitCode = 0
<#
.Error Code Guide
    0 No errors
    1 Something went wrong
#>

<#
.SYNOPSIS
	IISAppPoolController will perform actions on target App pools
.DESCRIPTION
    IISAppPoolController will take an action and IIS application pool list as arguments and perform the given action on the application pools.
.NOTES  
    File Name  : IISAppPoolController.ps1  
	Author  : Michael Gutierrez
    Date	: 3/4/2015
.EXAMPLE
	StopAppPools -AppPoolAction Start -AppPoolList Site1,Site2,Site4
.PARAMETER AppPoolAction
	Start, Start and set AutoStart to true, Stop, or Recycle depending on what you want the app pools to do.
.PARAMETER AppPoolList
	Takes an app pool name, or a coma deliminated list of app pools to perform the action on.
    
#>

#Splitting the app pool string and converting it to a List for ease of use.
$AppPoolList = New-Object System.Collections.ArrayList
foreach ($AppPool in ($AppPoolString -split ",")) 
{
    if (-not ($AppPool::NullorEmpty))
    {
        $AppPoolList.Add($AppPool)
    }
}

#This function takes the Array List of application pools and attempts to start them.
function StartAppPools
{
    param ([Parameter(Mandatory=$true)] [System.Collections.ArrayList]$AppPoolList)
    foreach ($AppPool in $AppPoolList)
    {
        $AppPoolDetails = & "C:\Windows\System32\inetsrv\appcmd.exe" "list" "Apppool" "/apppool.name:$AppPool"
        if (-not ($AppPoolDetails::NullorEmpty))
        {
            if ($AppPoolDetails -like "*Started)")
            {
                write-output "The $AppPool Application Pool was already running.`nThe start command does not need to be run."
            }
            else
            {
                write-output "Starting the $AppPool application pool now."
              & "C:\Windows\System32\inetsrv\appcmd.exe" "start" "Apppool" "/apppool.name:$AppPool"
              $AppPoolDetails = & "C:\Windows\System32\inetsrv\appcmd.exe" "list" "Apppool" "/apppool.name:$AppPool"
              if ($AppPoolDetails -like "*Started)")
                {
                    write-output "$AppPool application pool successfully started."
                }
                else
                {
                    write-output "Unable to start the $AppPool application pool."
                    $ExitCode = 1
                }
            }
        }
        else
        {
            write-output "Could not find the $AppPool on the target server"
            $ExitCode = 1
        }
    }
    if ($ExitCode -eq 0)
    {
        write-output "Application pools started successfully."
    }
    else
    {
        write-output "One or more errors occurred during the application pool starts. Please see above."
    }
}

#This function takes the Array List of application pools and attempts to start them, setting auto start to true in the app pool.
function StartAppPoolsAuto
{
    param ([Parameter(Mandatory=$true)] [System.Collections.ArrayList]$AppPoolList)
    foreach ($AppPool in $AppPoolList)
    {
        $AppPoolDetails = & "C:\Windows\System32\inetsrv\appcmd.exe" "list" "Apppool" "/apppool.name:$AppPool"
        if (-not ($AppPoolDetails::NullorEmpty))
        {
            if ($AppPoolDetails -like "*Started)")
            {
                write-output "The $AppPool Application Pool was already running.`nThe start command does not need to be run."
            }
            else
            {
                write-output "Starting the $AppPool application pool now."
              & "C:\Windows\System32\inetsrv\appcmd.exe" "start" "Apppool" "/apppool.name:$AppPool"
              & "C:\Windows\System32\inetsrv\appcmd.exe" "set" "Apppool" "$AppPool" "/autoStart:true"
              $AppPoolDetails = & "C:\Windows\System32\inetsrv\appcmd.exe" "list" "Apppool" "/apppool.name:$AppPool"
              if ($AppPoolDetails -like "*Started)")
                {
                    write-output "$AppPool application pool successfully started."
                }
                else
                {
                    write-output "Unable to start the $AppPool application pool."
                    $ExitCode = 1
                }
            }
        }
        else
        {
            write-output "Could not find the $AppPool on the target server"
            $ExitCode = 1
        }
    }
    if ($ExitCode -eq 0)
    {
        write-output "Application pools started successfully."
    }
    else
    {
        write-output "One or more errors occurred during the application pool starts. Please see above."
    }
}

#This function takes the Array List of application pools and attempts to stop them.
function StopAppPools
{
    param ([Parameter(Mandatory=$true)] [System.Collections.ArrayList]$AppPoolList)
    foreach ($AppPool in $AppPoolList)
    {
        $AppPoolDetails = & "C:\Windows\System32\inetsrv\appcmd.exe" "list" "Apppool" "/apppool.name:$AppPool"
        if (-not ($AppPoolDetails::NullorEmpty))
        {
            if ($AppPoolDetails -like "*Stopped)")
            {
                write-output "The $AppPool Application Pool was already stopped.`nThe stop command does not need to be run."
            }
            else
            {
                write-output "Stopping the $AppPool application pool now."
                & "C:\Windows\System32\inetsrv\appcmd.exe" "stop" "Apppool" "/apppool.name:$AppPool"
                & "C:\Windows\System32\inetsrv\appcmd.exe" "set" "Apppool" "$AppPool" "/autoStart:false"
                $AppPoolDetails = & "C:\Windows\System32\inetsrv\appcmd.exe" "list" "Apppool" "/apppool.name:$AppPool"
                if ($AppPoolDetails -like "*Stopped)")
                {
                    write-output "$AppPool application pool successfully stopped."
                }
                else
                {
                    write-output "Unable to stop the &AppPool application pool."
                    $ExitCode = 1
                }
            }
        }
        else
        {
            write-output "Could not find the $AppPool on the target server"
            $ExitCode = 1
        }
    }
    if ($ExitCode -eq 0)
    {
        write-output "Application pools stopped successfully."
    }
    else
    {
        write-output "One or more errors occurred during the application pool stops. Please see above."
    }
}

#This function takes the Array List of application pools and attempts to recycle them.
function RecycleAppPools
{
    param ([Parameter(Mandatory=$true)] [System.Collections.ArrayList]$AppPoolList)
    foreach ($AppPool in $AppPoolList)
    {
        $AppPoolDetails = & "C:\Windows\System32\inetsrv\appcmd.exe" "list", "Apppool", "/apppool.name:$AppPool"
        write-output $AppPoolDetails
        if (-not ($AppPoolDetails::NullorEmpty))
        {
            & "C:\Windows\System32\inetsrv\appcmd.exe" "recycle", "Apppool", "/apppool.name:$AppPool"
        }
        else
        {
            write-output "Could not find the $AppPool on the target server"
            $ExitCode = 1
        }
    }
    if ($ExitCode -eq 0)
    {
        write-output "Application pools recycled successfully."
    }
    else
    {
        write-output "One or more errors occurred during the application pool recycles. Please see above."
    }
}

#Run the function based on the users AppPoolAction input.
switch ($AppPoolAction)
{
    Start       {StartAppPools $AppPoolList}
    StartAuto   {StartAppPoolsAuto $AppPoolList}
    Stop        {StopAppPools $AppPoolList}
    Recycle     {RecycleAppPools $AppPoolList}
    default     {write-output "Please choose Start, Stop, or Recycle as the action."}
}

exit $ExitCode