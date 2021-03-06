$Time = [System.Diagnostics.Stopwatch]::StartNew()

$global:viservers = "bpeca-aevc01","ca-vcentersmn"
$APIPAregex = [regex]'169\.254\.\d{1,3}\.\d{1,3}'
$global:outfile = "h:\vmreport.csv"

if (Test-Path $outfile) { remove-item $global:outfile -force }

if(!($vmcreds)) {
	$vmcreds = Get-Credential
}


foreach ($VIServer in $global:viservers) {
    try {
        Connect-VIServer $VIServer -Credential $vmcreds -ErrorAction Stop
    } catch {
        throw
    }
}

#$vmlist = Get-View -ViewType VirtualMachine -Property Name,Config,Storage,Guest
$vmlist = Get-View -ViewType VirtualMachine -Property Name,Config,Storage,Guest -filter @{"name" = "lme1*"}


$objArray = @()
$RITMPattern = [regex]'.*(RITM\d*)'
$UIDPattern = [regex]'(.*=)(.*\\.*@)(.*)'

foreach ($vmview in $vmlist) {
	$vmObj = New-Object PSObject
	$DNSName = $null

	
	$IPArray = $vmview.Guest.IPAddress
	
	foreach($IP in $IPArray) {
		if($IP -and $APIPAregex.Match($IP).Success -eq $false) { #Don't try to get DNS for blank IP's or APIPA IP's
			try {
				$DNSName += ([System.Net.Dns]::GetHostByAddress($IP)).HostName
			} catch {
				$DNSName += "Unable to resolve DNS name for IP: $IP"
			}
		}
	}
	

    $vm = $vmview | Get-VIObjectByVIView

    $TotalDiskSpaceGB = 0
    $FreeDiskSpaceGB = 0

    foreach($disk in $vmview.Storage.PerDatastoreUsage) {
        $dsview = (Get-View $disk.Datastore)
        $TotalDiskSpaceGB = (($disk.Committed+$disk.Uncommitted)/1024/1024/1024)
        $FreeDiskSpaceGB = ($disk.Uncommitted/1024/1024/1024)
    }

    if ($FreeDiskSpaceGB -eq 0) {
        $PctFree = 0.00
    } else {
        $PctFree = [system.math]::Round(($FreeDiskSpaceGB / $TotalDiskSpaceGB),3)
    }

    $TotalDiskSpaceGB = [system.math]::Round($TotalDiskSpaceGB)
    $FreeDiskSpaceGB = [system.math]::Round($FreeDiskSpaceGB)

    $result = $UIDPattern.Match($vm.uid)
    $UUID = $result.Groups[1].Value + $result.Groups[3].Value


    if($vm.VApp) {
        $vappid = (Get-VApp $vm.VApp).Uid
        $result = $UIDPattern.Match($vappid)
        $vappid = $result.Groups[1].Value + $result.Groups[3].Value
    } else {
        $folder = $vm.Folder
        $vappid = $null
    }
  	$vmObj | Add-Member -Type NoteProperty -Name Name -Value $vmview.Name
    $vmObj | Add-Member -Type NoteProperty -Name IP -Value $IPArray
    $vmObj | Add-Member -Type NoteProperty -Name DNS -Value $DNSName
    $vmObj | Add-Member -Type NoteProperty -Name Status -Value $vm.PowerState
    $vmObj | Add-Member -Type NoteProperty -Name TotalDiskGB -Value $TotalDiskSpaceGB
    $vmObj | Add-Member -Type NoteProperty -Name FreeDiskGB -value $FreeDiskSpaceGB
    $vmObj | Add-Member -Type NoteProperty -Name PctFree -Value $PctFree
    $vmObj | Add-Member -Type NoteProperty -Name OS -value $vm.Guest.OSFullName
    $vmObj | Add-Member -Type NoteProperty -Name Ticket -Value $ticket
    $vmObj | Add-Member -Type NoteProperty -Name Folder -value $folder
    $vmObj | Add-Member -Type NoteProperty -Name vApp -Value $vm.VApp
	$vmObj | Add-Member -Type NoteProperty -Name CPUs -Value $vm.NumCpu
    $vmObj | Add-Member -Type NoteProperty -Name Mem -Value $vm.MemoryGB
    $vmObj | Add-Member -Type NoteProperty -Name UUID -value $UUID
    $vmObj | Add-Member -Type NoteProperty -Name VAppID -value $vappid

    $vmObj | Export-Csv -NoTypeInformation $outfile -append
	$objArray += $vmObj
}

#$objArray | Out-GridView

$CurrentTime = $Time.Elapsed
write-host $([string]::Format("`rTime: {0:d2}:{1:d2}:{2:d2}",
    $CurrentTime.hours, 
    $CurrentTime.minutes, 
    $CurrentTime.seconds)) -nonewline