# ----- Gather Credentials
#$LocalAdmin = (Get-Credential -UserName administrator -Message "Servers Local Admin Account")
#$VCenterAdmin = (Get-Credential -Message "vCenter Account" )
#$ADRecoveryAcct = (Get-Credential -UserName '(Password Only)' -Message "New Domain Safe Mode Administrator Password")
#$DomainAdmin = (Get-Credential -UserName "$($ConfigData.AllNodes.DomainName)\administrator" -Message "New Domain Admin Credential")
$SQLSvcAccount = Get-Credential -Message 'SQL Service Account'
$SAAccount = Get-Credential -UserName SA -Message "SQL SA Account"

$DSCModulePath = 'C:\Users\jeff\Documents\WindowsPowerShell\Modules'
#$DSCModulePath = 'C:\users\600990\Documents\WIndowsPowerShell\Modules'

# ----- Build Router
#. $PSScriptRoot\Infrastructure\Build-LABRouter.ps1 -LocalAdmin $LocalAdmin -VCenterAdmin $VCenterAdmin -Verbose

# ----- Build AD
#. $PSScriptRoot\Domain\Build-newLABDomain.ps1 -LocalAdmin $LocalAdmin -VCenterAdmin $VCenterAdmin -ADRecoveryAcct $ADRecoveryAcct -DomainAdmin $DomainAdmin -DSCModulePath $DSCModulePath -Verbose

# ----- Build AD
#. $PSScriptRoot\Domain\Add-LABDHCP.ps1 -VCenterAdmin $VCenterAdmin  -DomainAdmin $DomainAdmin -DSCModulePath $DSCModulePath -Verbose

# ----- Build TFTP
#. $PSScriptRoot\Build-LABTFTPServer.ps1 -VCenterAdmin $VCenterAdmin  -LocalAdmin $LocalAdmin -Verbose

# ----- Build AD
. $PSScriptRoot\SQL\Build-NewLABSQL.ps1 -VCenterAdmin $VcenterAdmin -DomainAdmin $DomainAdmin -SQLSvcAccount $SQLSvcAccount -SAAccount $SAAccount -DSCModulePath $DSCModulePath -Verbose
