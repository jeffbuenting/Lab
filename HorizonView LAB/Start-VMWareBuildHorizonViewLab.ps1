$DomainName = 'Kings-wood.local'
$ADServer = 'KW-DC1.kings-wood.local'


# ----- Gather Credentials
#$DomainAdmin = (Get-Credential -UserName "$($DomainName)\administrator" -Message "New Domain Admin Credential")

$PSscriptroot

& $PSScriptRoot\Build-VMWareHorizonViewLab.ps1 -ADServer $ADServer -DomainAdmin $DomainAdmin -Verbose
