$VCenterServer = '192.168.1.16'
$ViewServer = '192.168.1.17'


$PoolName = 'SurfP'
$PoolVMFolder = $PoolName
$ESXHost = '192.168.1.15'
$PoolDataStore = 'NFS-Drobo'
$PoolNamePattern = 'KW-SurfP'
$PoolMin = 0
$PoolMax = 1
$PoolSpare = 1
$PoolOSCustomization = 'WIN 10 VDI'

$DomainController = 'KW-DC1'
$DomainNetBiosName = 'kings-wood'
$PoolContainer = 'OU=SurfPPool,OU=VDI'



# ----- Gather Credentials
#$LocalAdmin = (Get-Credential -Message "Servers Local Admin Account")
$LOcalAdmin = New-Object System.Management.Automation.PSCredential ('jeff', $(ConvertTo-SecureString 'Branman1!' -AsPlainText -Force))
#$VCenterAdmin = (Get-Credential -UserName "administrator@vsphere.local" -Message "vCenter Account" )
$VCenterAdmin = New-Object System.Management.Automation.PSCredential ('administrator@vsphere.local', $(ConvertTo-SecureString 'Branman1!' -AsPlainText -Force))
#$DomainAdmin = Get-Credential -UserName "Kings-wood\administrator" -Message "Domain Admin"
$DomainAdmin = New-Object System.Management.Automation.PSCredential ('kings-wood\administrator', $(ConvertTo-SecureString 'Branman1!' -AsPlainText -Force))
#$ADRecoveryAccount =  Get-Credential -UserName '(Password Only)' -Message "New Domain Safe Mode Administrator Password"
$ADRecoveryAccount = New-Object System.Management.Automation.PSCredential ('(Password Only)', $(ConvertTo-SecureString 'Branman1!' -AsPlainText -Force))

#$SQLSvcAccount = Get-Credential -UserName "kings-wood\svc.sql" -Message 'SQL Service Account'
$SQLSvcAccount = New-Object System.Management.Automation.PSCredential ('kings-wood\svc.sql', $(ConvertTo-SecureString 'Branman1!' -AsPlainText -Force))
#$SAAccount = Get-Credential -UserName SA -Message "SQL SA Account"
$SAAccount = New-Object System.Management.Automation.PSCredential ('SA', $(ConvertTo-SecureString 'Branman1!' -AsPlainText -Force))

$VCSAViewUser = New-Object System.Management.Automation.PSCredential ('SVC.View', $(ConvertTo-SecureString 'Branman1!' -AsPlainText -Force))
#$InstantCloneUser = New-Object System.Management.Automation.PSCredential ('SVC.ViewIC', $(ConvertTo-SecureString 'Branman1!' -AsPlainText -Force))
$ComposerSQLAcct = New-Object System.Management.Automation.PSCredential ('SVC.Composer', $(ConvertTo-SecureString 'Branman1!' -AsPlainText -Force))
$ComposerViewAcct = New-Object System.Management.Automation.PSCredential ('kings-wood\SVC.Composer', $(ConvertTo-SecureString 'Branman1!' -AsPlainText -Force))
$ViewAdmin = $DomainAdmin
$ViewSQLAcct = New-Object System.Management.Automation.PSCredential ('ViewConnection', $(ConvertTo-SecureString 'Branman1!' -AsPlainText -Force))

$SharedDriveCred = New-Object System.Management.Automation.PSCredential ('Jeff', $(ConvertTo-SecureString 'Branman1!' -AsPlainText -Force))

$DSCModulePath = 'C:\Users\jeff\Documents\WindowsPowerShell\Modules'
#$DSCModulePath = 'C:\users\600990\Documents\WIndowsPowerShell\Modules'

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
# ----- vsphere 6.7 requires tls 1.2
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

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
#$HVLicense = get-content \\192.168.1.166\source\VMWare\HVLicense.txt

#. "$PSScriptRoot\HorizonView LAB\Build-HVAdminConsole.ps1" -vcenterAdmin $VCenterAdmin `
#    -LocalAdmin $LocalAdmin `
#    -domainAdmin $DomainAdmin `
#    -ADServer $ADServer `
#    -dscModulePath $DSCModulePath `
#    -VCSAViewUser $VCSAViewUser `
#    -HVLicense $HVLicense `
#    -Timeout 3600 `
#    -EventDB `
#    -ViewSQLAcct $ViewSQLACCT `
#    -Verbose

#. "$PSScriptRoot\HorizonView LAB\New-VMWareHVComposer.ps1" -ComputerName $SQLServer -DomainAdmin $DomainAdmin -ComposerViewAcct $ComposerViewAcct -ComposerSQLAcct $ComposerSQLAcct -ADServer $ADServer -InstallSource $ComposerSource -Verbose

# Write-Warning "Haven't figured out how to get VCSA and View composer configured via powershell yet.  Until I do, you will have to manually do so in Horizon View Admin"

# ----- Create Master Images

#$MasterImage = . "$PSScriptRoot\HorizonView LAB\New-HVMasterVM.ps1" -DSCModulePath $DSCModulePath -LocalAdmin $LocalAdmin -SHaredDriveCred $SharedDriveCred -Verbose

# ----- Create linked clone pool
Connect-HVServer -Server $ViewServer -Credential $ViewAdmin

. "$PSScriptRoot\HorizonView LAB\Build-HVLinkedClonePool.ps1" -DSCConfig "$PSScriptRoot\HorizonView LAB\dscConfigs\Config_HVPool.ps1" -DomainAdmin $DomainAdmin -Verbose