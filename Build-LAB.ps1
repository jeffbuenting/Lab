# ----- Gather Credentials
$LocalAdmin = (Get-Credential -UserName administrator -Message "Servers Local Admin Account")
$VCenterAdmin = (Get-Credential -Message "vCenter Account" )
#$ADRecoveryAcct = (Get-Credential -UserName '(Password Only)' -Message "New Domain Safe Mode Administrator Password")
#$DomainAdmin = (Get-Credential -UserName "$($ConfigData.AllNodes.DomainName)\administrator" -Message "New Domain Admin Credential")


. $PSScriptRoot\Build-LABRouter.ps1 -LocalAdmin $LocalAdmin -VCenterAdmin $VCenterAdmin -Verbose
