#-------------------------------------------------------------------------
# Solution: Get Local Admins
# Author: Aaron Lewis
# Updated: 11/13/2012
#-------------------------------------------------------------------------


#-------------------------------------------------------------------------
# DEFINE VARIABLES
#-------------------------------------------------------------------------

$serverlist = Get-content C:\monthly_audit\local_audit\Servers.txt

# Set the SMTP Server address
$SMTPSRV = "owa2010.bridgepointeducation.com"
# Set the Email address to recieve from
$EmailFrom = "systemsengineeringproducts@ashford.edu"
# Set the Email address to send the email to
#$EmailTo = "systemsengineeringproducts@ashford.edu"
$EmailTo = "systemsengineeringproducts@ashford.edu"
#Set Message Body
$Report = ""
$FinalReport = ""

#-------------------------------------------------------------------------
# Function Send-SMTPEMail
#-------------------------------------------------------------------------

function Send-SMTPmail($to, $from, $subject, $smtpserver, $body) 
{

    $mailer = new-object Net.Mail.SMTPclient($smtpserver)
	$msg = new-object Net.Mail.MailMessage($from,$to,$subject,$body)
	$msg.IsBodyHTML = $true
	$mailer.send($msg)
}

#-------------------------------------------------------------------------
# Function Get Local Admin
#-------------------------------------------------------------------------

function GetLocalAdministrators([string]$server)
{
     $group=[adsi]"WinNT://$server/Administrators,group"
     try{
     $group.psbase.Invoke("Members") | 
          ForEach-Object{
              $name=$_.GetType().InvokeMember("Name", 'GetProperty', $null, $_, $null)
              new-Object PSObject -property @{System=$server;AccountName=$name}
              $Report += "Local Administrators on $Server are $name<br>"
          } 
      }
      catch [exception]
      {
        # Does nothing with exception.
        # Uncomment below if you want to see error for debugging
        #Write-Host ($_)
      }
    return $Report
}

#-------------------------------------------------------------------------
# MAIN APP LOGIC
#-------------------------------------------------------------------------

foreach ($server in $serverlist)

{
    #Write-Host($server)
    $FinalReport += GetLocalAdministrators($server)
}


# Send Audit Email
send-SMTPmail $EmailTo $EmailFrom "$Date BPEServices Local Admin Audit" $SMTPSRV $FinalReport