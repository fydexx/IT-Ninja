'It is recommended to test the script on a local machine for its purpose and effects. 
'ManageEngine Desktop Central will not be responsible for any 
'damage/loss to the data/setup based on the behavior of the script.

'Description - Script to disable the "Switch User" option
'Parameters -
'Remarks -
'Configuration Type - COMPUTER
'==============================================================

Set WshShell = CreateObject("WScript.Shell")
myKey = "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System\HideFastUserSwitching"
WshShell.RegWrite myKey,1,"REG_DWORD"
Set WshShell = Nothing