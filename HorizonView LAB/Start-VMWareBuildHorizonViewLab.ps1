$DomainName = 'Kings-wood.local'
$ADServer = 'KW-DC1.kings-wood.local'
$DSCModulePath = 'C:\Users\jeff\Documents\WindowsPowerShell\Modules'
#$DSCModulePath = 'C:\users\600990\Documents\WIndowsPowerShell\Modules'
$HVLicense = '14286-JV211-Q8TA4-0G1HM-21RJM'

import-module C:\Scripts\VMWare\VMWare.psd1 -force

# ----- Gather Credentials
#$DomainAdmin = (Get-Credential -UserName "$($DomainName)\administrator" -Message "New Domain Admin Credential")

$VCSAViewUser = New-Object System.Management.Automation.PSCredential ('SVC.View', $(ConvertTo-SecureString 'Branman1!' -AsPlainText -Force))
$InstantCloneUser = New-Object System.Management.Automation.PSCredential ('SVC.ViewIC', $(ConvertTo-SecureString 'Branman1!' -AsPlainText -Force))

$PSscriptroot

& $PSScriptRoot\Build-VMWareHorizonViewLab.ps1 -vcenterAdmin $VCenterAdmin -LocalAdmin $LocalAdmin -domainAdmin $DomainAdmin -ADServer $ADServer -dscModulePath $DSCModulePath -VCSAViewUser $VCSAViewUser -Timeout 1200 -Verbose
