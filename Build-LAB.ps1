# ----- Gather Credentials
#$LocalAdmin = (Get-Credential -UserName administrator -Message "Servers Local Admin Account")
#$VCenterAdmin = (Get-Credential -Message "vCenter Account" )
#$ADRecoveryAcct = (Get-Credential -UserName '(Password Only)' -Message "New Domain Safe Mode Administrator Password")
#$DomainAdmin = (Get-Credential -UserName "$($ConfigData.AllNodes.DomainName)\administrator" -Message "New Domain Admin Credential")

$DSCModulePath = 'C:\Users\jeff\Documents\WindowsPowerShell\Modules'
#$DSCModulePath = 'C:\users\600990\Documents\WIndowsPowerShell\Modules'

# ----- Build Router
#. $PSScriptRoot\Infrastructure\Build-LABRouter.ps1 -LocalAdmin $LocalAdmin -VCenterAdmin $VCenterAdmin -Verbose

# ----- Build AD
#. $PSScriptRoot\Domain\Build-newLABDomain.ps1 -LocalAdmin $LocalAdmin -VCenterAdmin $VCenterAdmin -ADRecoveryAcct $ADRecoveryAcct -DomainAdmin $DomainAdmin -DSCModulePath $DSCModulePath -Verbose

# ----- Build AD
. $PSScriptRoot\Domain\Add-LABDHCP.ps1 -VCenterAdmin $VCenterAdmin  -DomainAdmin $DomainAdmin -DSCModulePath $DSCModulePath -Verbose

# ----- Build TFTP
#. $PSScriptRoot\Build-LABTFTPServer.ps1 -VCenterAdmin $VCenterAdmin  -LocalAdmin $LocalAdmin -Verbose