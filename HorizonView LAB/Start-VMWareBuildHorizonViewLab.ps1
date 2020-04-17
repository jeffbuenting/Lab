$DomainName = 'Kings-wood.local'
$ADServer = 'KW-DC1.kings-wood.local'
#$DSCModulePath = 'C:\Users\jeff\Documents\WindowsPowerShell\Modules'
$DSCModulePath = 'C:\users\600990\Documents\WIndowsPowerShell\Modules'


# ----- Gather Credentials
#$DomainAdmin = (Get-Credential -UserName "$($DomainName)\administrator" -Message "New Domain Admin Credential")

$PSscriptroot

& $PSScriptRoot\Build-VMWareHorizonViewLab.ps1 -ADServer $ADServer -dscModulePath $DSCModulePath -Timeout 1200 -Verbose
