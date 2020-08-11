$VCenterServer = '192.168.1.16'

# ----- Gather Credentials
#$LocalAdmin = (Get-Credential -Message "Servers Local Admin Account")
#$VCenterAdmin = (Get-Credential -UserName "administrator@vsphere.local" -Message "vCenter Account" )
#$DomainAdmin = Get-Credential -UserName "Kings-wood\administrator" -Message "Domain Admin"
#$ADRecoveryAccount =  Get-Credential -UserName '(Password Only)' -Message "New Domain Safe Mode Administrator Password"
#
#$SQLSvcAccount = Get-Credential -UserName "kings-wood\svc.sql" -Message 'SQL Service Account'
#$SAAccount = Get-Credential -UserName SA -Message "SQL SA Account"

$VCSAViewUser = New-Object System.Management.Automation.PSCredential ('SVC.View', $(ConvertTo-SecureString 'Branman1!' -AsPlainText -Force))
#$InstantCloneUser = New-Object System.Management.Automation.PSCredential ('SVC.ViewIC', $(ConvertTo-SecureString 'Branman1!' -AsPlainText -Force))
$ComposerSQLAcct = New-Object System.Management.Automation.PSCredential ('SVC.Composer', $(ConvertTo-SecureString 'Branman1!' -AsPlainText -Force))
$ComposerViewAcct = New-Object System.Management.Automation.PSCredential ('kings-wood\SVC.Composer', $(ConvertTo-SecureString 'Branman1!' -AsPlainText -Force))

#$DSCModulePath = 'C:\Users\jeff\Documents\WindowsPowerShell\Modules'
$DSCModulePath = 'C:\users\600990\Documents\WIndowsPowerShell\Modules'

$SQLServer = 'KW-SQL1'
$ADServer = 'kw-dc1'
$ComposerSource = '\\192.168.1.166\source\VMWare\VMware-viewcomposer-7.12.0-15747753.exe'

# ----- VMWare module is not in a ps path so loading manually
Import-Module C:\Scripts\VMWare\VMWare.psd1 -Force -Verbose:$False

# ----- Dot source functions for LAB
Get-ChildItem C:\Scripts\lab\Functions | foreach { 
    Write-Verbose "Dot sourcing $($_.FullName)"

    . $_.FullName
}

# ----- Connect to vCenter service so we can deal with the VM
Try {
    if ( $global:DefaultVIServer.Name -ne $VCenterServer -or $global:DefaultVIServer.SessionID -eq $Null ) {
        Write-Output "Connecting to $VCenterServer"

        Connect-VIServer -Server 192.168.1.16 -Credential $VCenterAdmin -ErrorAction Stop
    }
    Else {
        Write-Output "Already connected to $VCenterServer"
    }
}
Catch {
    $ExceptionMessage = $_.Exception.Message
    $ExceptionType = $_.Exception.GetType().Fullname
    Throw "Error Connecting to vCenter.`n`n     $ExceptionMessage`n`n $ExceptionType"
}

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
#. $PSScriptRoot\SQL\Build-NewLABSQL.ps1 -VCenterAdmin $VcenterAdmin -DomainAdmin $DomainAdmin -LocalAdmin $LocalAdmin -SQLSvcAccount $SQLSvcAccount -SAAccount $SAAccount -DSCModulePath $DSCModulePath -Timeout 3600 -Verbose


# ------------------------------------------------------------------------------
# VDI Section
# ------------------------------------------------------------------------------

# ----- Connection View server
# ----- I don't want the license key to be in git so I put in in a file locally 
$HVLicense = get-content \\192.168.1.166\source\VMWare\HVLicense.txt

#. "$PSScriptRoot\HorizonView LAB\Build-VMWareHorizonViewLab.ps1" -vcenterAdmin $VCenterAdmin -LocalAdmin $LocalAdmin -domainAdmin $DomainAdmin -ADServer $ADServer -dscModulePath $DSCModulePath -VCSAViewUser $VCSAViewUser -HVLicense $HVLicense -Timeout 3600 -Verbose

#. "$PSScriptRoot\HorizonView LAB\New-VMWareHVComposer.ps1" -ComputerName $SQLServer -DomainAdmin $DomainAdmin -ComposerViewAcct $ComposerViewAcct -ComposerSQLAcct $ComposerSQLAcct -ADServer $ADServer -InstallSource $ComposerSource -Verbose

# Write-Warning "Haven't figured out how to get VCSA and View composer configured via powershell yet.  Until I do, you will have to manually do so in Horizon View Admin"

# ----- Create Master Images

. "$PSScriptRoot\HorizonView LAB\New-HVMasterVM.ps1" -DSCModulePath $DSCModulePath -LocalAdmin $LocalAdmin -Verbose
