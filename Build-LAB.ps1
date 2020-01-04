# ----- Gather Credentials
#$LocalAdmin = (Get-Credential -UserName administrator -Message "Servers Local Admin Account")
#$VCenterAdmin = (Get-Credential -Message "vCenter Account" )
#$ADRecoveryAcct = (Get-Credential -UserName '(Password Only)' -Message "New Domain Safe Mode Administrator Password")
#$DomainAdmin = (Get-Credential -UserName "$($ConfigData.AllNodes.DomainName)\administrator" -Message "New Domain Admin Credential")

# ----- Build Router
#. $PSScriptRoot\Build-LABRouter.ps1 -LocalAdmin $LocalAdmin -VCenterAdmin $VCenterAdmin -Verbose

# ----- Build AD
#. $PSScriptRoot\Build-newLABDomain.ps1 -LocalAdmin $LocalAdmin -VCenterAdmin $VCenterAdmin -ADRecoveryAcct $ADRecoveryAcct -DomainAdmin $DomainAdmin -Verbose

# ----- Build AD
#. $PSScriptRoot\Add-LABDHCP.ps1 -VCenterAdmin $VCenterAdmin  -DomainAdmin $DomainAdmin -Verbose

# ----- Build TFTP
. $PSScriptRoot\Build-LABTFTPServer.ps1 -VCenterAdmin $VCenterAdmin  -LocalAdmin $LocalAdmin -Verbose