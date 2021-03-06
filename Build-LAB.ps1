﻿

# ----- Gather Credentials
#$LocalAdmin = (Get-Credential -UserName administrator -Message "Servers Local Admin Account")
#$VCenterAdmin = (Get-Credential -Message "vCenter Account" )
#$DomainAdmin = Get-Credential -UserName "Kings-wood\administrator" -Message "Domain Admin"
#$ADRecoveryAccount =  Get-Credential -UserName '(Password Only)' -Message "New Domain Safe Mode Administrator Password"
#
#$SQLSvcAccount = Get-Credential -UserName "kings-wood\svc.sql" -Message 'SQL Service Account'
#$SAAccount = Get-Credential -UserName SA -Message "SQL SA Account"

$DSCModulePath = 'C:\Users\jeff\Documents\WindowsPowerShell\Modules'
#$DSCModulePath = 'C:\users\600990\Documents\WIndowsPowerShell\Modules'

# ----- VMWare module is not in a ps path so loading manually
Import-Module C:\Scripts\VMWare\VMWare.psd1 -Force

# ----- Dot source functions for LAB
. $PSSCriptRoot\Functions\New-LABVM.ps1
. $PSScriptRoot\Functions\Copy-ItemIfNotThere.ps1


# ----- Build Router
#. $PSScriptRoot\Infrastructure\Build-LABRouter.ps1 -LocalAdmin $LocalAdmin -VCenterAdmin $VCenterAdmin -DSCModulePath $DSCModulePath -Verbose

# ----- Build AD
#. $PSScriptRoot\Domain\Build-newLABDomain.ps1 -LocalAdmin $LocalAdmin -VCenterAdmin $VCenterAdmin -ADRecoveryAcct $ADRecoveryAccount -DomainAdmin $DomainAdmin -DSCModulePath $DSCModulePath -Verbose
# ----- Build AD
#. $PSScriptRoot\Domain\Add-LABDHCP.ps1 -VCenterAdmin $VCenterAdmin  -DomainAdmin $DomainAdmin -DSCModulePath $DSCModulePath -Verbose

# ----- Build TFTP
#. $PSScriptRoot\Build-LABTFTPServer.ps1 -VCenterAdmin $VCenterAdmin  -LocalAdmin $LocalAdmin -Verbose

# ----- Build SQL
# (Wait-OSCustomization is really slow on my lab increased the timeout from default to account for this)
. $PSScriptRoot\SQL\Build-NewLABSQL.ps1 -VCenterAdmin $VcenterAdmin -DomainAdmin $DomainAdmin -LocalAdmin $LocalAdmin -SQLSvcAccount $SQLSvcAccount -SAAccount $SAAccount -DSCModulePath $DSCModulePath -Timeout 3600 -Verbose
