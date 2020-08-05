# ----- Configure AD OU etc for VMWare Horizon View.  

# ----- NOTE : May need to remove and readd Horizon servers to domain when domain is rebuilt

[CmdletBinding()]
Param (
    [Parameter ( Mandatory = $True )]
    [PSCredential]$VCenterAdmin,

    [Parameter ( Mandatory = $True )]
    [PSCredential]$LocalAdmin,

    [Parameter ( Mandatory = $True )]
    [PSCredential]$DomainAdmin,

    [Parameter ( Mandatory = $True )]
    [PSCredential]$VCSAViewUser,

    [PSCredential]$InstantCloneUser,

    [String]$ADServer,

    [Parameter ( Mandatory = $True )]
    [String]$DSCModulePath,

    [int]$Timeout = '900',

    [Parameter ( Mandatory = $True )]
    [String]$HVLicense

)


$VerbosePreference = 'Continue'

$IsVerbose = $False
if ( $VerbosePreference -eq 'Continue' ) { $IsVerbose = $True }


## ----- Create OU for Remote Desktops
#Write-Verbose "Create OUs for VDI"
#if ( -Not (Get-ADOrganizationalUnit -Server $ADServer -Credential $DomainAdmin -Filter 'Name -like "VDI"') ) {
#    Write-Verbose "VDI OU does not exist.  Creating"
#    New-ADOrganizationalUnit -Server $ADServer -Credential $DomainAdmin -Name VDI
#}
#
## ----- OU for VDI Service Accounts
#Write-Verbose "Create OU for Horizon View Service Accounts"
#if ( -Not (Get-ADOrganizationalUnit -Server $ADServer -Credential $DomainAdmin -SearchBase "OU=VDI,DC=kings-wood,DC=local" -Filter 'Name -like "ServiceAcct"') ) {
#    Write-Verbose "VDI OU does not exist.  Creating"
#    New-ADOrganizationalUnit -Server $ADServer -Credential $DomainAdmin -Name "Service Accounts" -Path "OU=VDI,DC=kings-wood,DC=local"
#}

# ----- Service Accounts

# ----- Build connection server
# ----- Dot source configs and DSC scripts
Write-Verbose "Dot sourcing scripts"

# ----- Load the Config Data
. $PSScriptRoot\DSCConfigs\Config_ViewConnetionServer.ps1

. $PSScriptRoot\DSCConfigs\New-ViewConnectionServer.ps1

# ----- Dot source LCM config (same for all scripts)
. "$((Get-item -Path 'C:\Scripts\Lab\HorizonView LAB').Parent.FullName)\DSCConfigs\LCMConfig.ps1"

# ----- Build the MOF files for both the LCM and DSC script
# ----- Build the Config MOF
Write-Verbose "Building DSC MOF"
if ( -Not (Test-Path "$PSScriptRoot\MOF") ) { New-Item -ItemType Directory -Path "$PSScriptRoot\MOF" }

try {
    LCMConfig -OutputPath $PSSCriptRoot\MOF -ErrorAction Stop

    New-ViewConnectionServer -ConfigurationData $ConfigData `
        -DomainAdmin $DomainAdmin `
        -OutputPath $PSScriptRoot\MOF `
        -ErrorAction Stop
}
Catch {
    $ExceptionMessage = $_.Exception.Message
    $ExceptionType = $_.Exception.GetType().Fullname
    Throw "Build-NewLABDomain : There was a problem building the MOF.`n`n     $ExceptionMessage`n`n $ExceptionType"
}

Try {
    # ----- Create the VM.  In this case we are building from a VM Template.  But this could be modified to be from an ISO.

    New-LABVM -VMName $ConfigData.AllNodes.NodeName `
        -ESXHost $ConfigData.AllNodes.ESXHost `
        -Template $ConfigData.AllNodes.VMTemplate `
        -ResourcePool $ConfigData.AllNodes.ResourcePool `
        -OSCustomization $ConfigData.AllNodes.OSCustomization `
        -VMSwitch $ConfigData.AllNodes.Switch `
        -PortGroup $ConfigData.AllNodes.Portgroup `
        -LocalAdmin $LocalAdmin `
        -CPU 4 `
        -Memory 4 `
        -Timeout $Timeout `
        -ErrorAction Stop `
        -Verbose



}
Catch {
    $ExceptionMessage = $_.Exception.Message
    $ExceptionType = $_.Exception.GetType().Fullname
    Throw "Problem creating the VM.`n`n     $ExceptionMessage`n`n $ExceptionType"
}

Write-verbose "Waiting for VM to start"
$VM = Get-VM -Name $Configdata.AllNodes.NodeName

while ( $VM.Guest.State -ne 'Running' ) {
    Write-Verbose "Pausing 15 Seconds..."
    Sleep -Seconds 15

    $VM = Get-VM -Name $Configdata.AllNodes.NodeName -ErrorAction Stop
}

Write-verbose "We appear to be going too fast and the VM has not settled.  Pausing to let it."
$Seconds = 300
$T = 0
while ( $T -le $Seconds ) { 
    Write-Verbose "Waiting for VM to 'Settle'...$T -le $Seconds"
    Start-Sleep -Seconds 5
    $T += 5
}


$VM = Get-VM -Name $Configdata.AllNodes.NodeName -ErrorAction Stop
$VM.Guest

Write-Verbose "Getting IP Address"
$IPAddress = $VM.Guest.IpAddress[0]

while ( -Not $IPAddress ) {
    Write-Verbose "IPAddress = $IPaddress"
    Write-Verbose "Pausing 15 Seconds waiting for IP...."
    Sleep -Seconds 15

    # ----- regular expression to extract IP address from IPv4 and IPv6 Ip array.
    $IPAddress = $VM.Guest.IpAddress | Select-String -Pattern "\b(?:(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\b"
}

Write-Verbose "IPAddress = $IPaddress"



# ----- The MOF files were created with the new VMs name.  we need to copy it to the server and change the name to Localhost to run locally
Try {
    Write-Verbose "Checking if Temp directory exists"

    $CMD = "if ( -Not (Test-Path ""c:\temp"") ) { New-Item -ItemType Directory -Path ""c:\temp"" }"
    Invoke-VMScript -vm $VM -GuestCredential $LocalAdmin -ScriptText $CMD -ErrorAction Stop
}
Catch {
    $ExceptionMessage = $_.Exception.Message
    $ExceptionType = $_.Exception.GetType().Fullname
    Throw "Error creating c:\temp on remote VM`n`n     $ExceptionMessage`n`n $ExceptionType"
}

# ----- Remove the drive if it exists
Write-Verbose "Mapping RemoteDrive to \\$IPAddress\c$"
if ( Get-PSDrive -Name RemoteDrive -ErrorAction SilentlyContinue ) { Remove-PSDrive -Name RemoteDrive }

Try {
    New-PSDrive -Name RemoteDrive -PSProvider FileSystem -Root "\\$IPAddress\c$" -Credential $LocalAdmin -ErrorAction stop
  #  New-PSDrive -Name RemoteDrive -PSProvider FileSystem -Root "\\$IPAddress\c$"  -ErrorAction stop
}
Catch {
    $ExceptionMessage = $_.Exception.Message
    $ExceptionType = $_.Exception.GetType().Fullname
    Throw "Map Drive failed.`n`n     $ExceptionMessage`n`n $ExceptionType"
}

# ----- Copy LCM Config and run on remote system
Write-Verbose "Configuring LCM"
Copy-Item -Path $PSScriptRoot\mof\LCMConfig.meta.mof -Destination RemoteDrive:\temp\localhost.meta.mof

$Timeout = 5

$DSCSuccess = $False
$Trys = 0
Do {
    Try {
        Start-Sleep -Seconds 60

        Invoke-VMScript -VM $VM -GuestCredential $LocalAdmin  -ScriptText "Set-DscLocalConfigurationManager -path c:\temp -force"
        $DSCSuccess = $True
    }
    Catch {
        Write-Warning "Problem setting local LCM.  Pausing and then will retry"
        $DSCSuccess = $False
        $Trys++

        Write-Verbose "Retrying ..."
    }
} While ( (-Not $DSCSuccess) -and ($Trys -lt $Timeout) )

Write-Verbose "Copying DSC resources to VM"
Write-Verbose "Copy MOFs"
Copy-Item -Path $PSScriptRoot\mof\$($Configdata.AllNodes.NodeName).mof -Destination RemoteDrive:\temp\localhost.mof
#COpy-Item -Path $PSScriptRoot\mof\$($Configdata.AllNodes.NodeName).meta.mof -Destination RemoteDrive:\temp\localhost.meta.mof


# ----- We are not using a DSC Pull server so we need to make sure the DSC resources are on the remote computer
Write-Verbose "Copy DSC Resources"
Copy-ItemIfNotThere -path $DSCModulePath\xComputerManagement -Destination "RemoteDrive:\Program Files\WindowsPowerShell\Modules" -Recurse 
Copy-ItemIfNotThere -path $DSCModulePath\NetworkingDSC -Destination "RemoteDrive:\Program Files\WindowsPowerShell\Modules" -Recurse 
Copy-ItemIfNotThere -path $DSCModulePath\xSystemSecurity -Destination "RemoteDrive:\Program Files\WindowsPowerShell\Modules" -Recurse 
Copy-ItemIfNotThere -path $DSCModulePath\xtimezone -Destination "RemoteDrive:\Program Files\WindowsPowerShell\Modules" -Recurse

# ----- Source install files
Write-Verbose "install source"
Copy-ItemIfNotThere -path "$ConfigData.AllNodes.Source\VMware-Horizon-Connection-Server-x86_64-7.12.0-15770369.exe" -Destination "RemoteDrive:\Temp" -Recurse

# ----- Run Config MOF on computer
Write-Verbose "Final DSC MOF"


        Start-Sleep -Seconds 60

        $Cmd = "Start-DscConfiguration -path C:\temp -Wait -Verbose -force"

        # ----- Invoke-VMScript will error as the VM DSC config forces a reboot.
        $Result = Invoke-VMScript -VM $VM -GuestCredential $LocalAdmin -ScriptText $CMD  -ErrorAction SilentlyContinue

        Write-Output "Results = $($Result | out-string)"

        $DSCSuccess = $True



$VM = Get-VM -Name $Configdata.AllNodes.NodeName -ErrorAction Stop


# ----- Wait for vm to reboot
$Timeout = 900
$T = 0
Write-Verbose "Waiting for VM "
While ( -Not (Get-Service -ComputerName $IPAddress -Name WinRM -ErrorAction SilentlyContinue ) -and $T -le $Timeout ) {
    Start-Sleep -s 5
    Write-Verbose "Still Waiting : $T -le $Timeout"
    $T += 5
}


Write-Verbose "installing VMWare Horizon View server"

$CMD = @'
if ( -Not ( Get-CIMInstance -Class WIN32_Product -Filter 'Name = "VMware Horizon 7 Connection Server"' ) ) {
    & 'C:\temp\VMware-Horizon-Connection-Server-x86_64-7.12.0-15770369.exe' /s /v "/qn /l c:\temp\viewinstall.log VDM_SERVER_INSTANCE_TYPE=1 INSTALLDIR=""C:\Program Files\VMware\VMware View\Server\"" FWCHOICE=1 VDM_SERVER_RECOVERY_PWD=Branman1! VDM_SERVER_RECOVERY_PWD_REMINDER=""yep"""

    write-Output "Installed Horizon View"
}
Else {
    Write-Output "Horizon View already installed"
}
'@

$Result = Invoke-VMScript -VM $VM -GuestCredential $DomainAdmin -ScriptText $CMD

Write-Verbose $Result.ScriptOutput

# -------------------------------------------------------------------------------------
# Configure Horizon View connection server after install
# -------------------------------------------------------------------------------------


# ----- DNS doesn't seem to be working in by environment ( because I am using a work laptop ) for this server so I need to add a config file that does this
#https://kb.vmware.com/s/article/2144768
$CMD = @'
if ( -Not ( Test-Path -Path 'c:\Program Files\VMware\VMware View\Server\locked.properties' ) ) {
    'checkOrigin=false' | Set-Content -Path 'c:\Program Files\VMware\VMware View\Server\locked.properties' -Force

    Get-service -Name wsbroker | Restart-Service

    Write-Output "Creating locked.properties file and restarting Connection service"
}
Else {
    Write-Output "Locked.properties file already exists."
}
'@

$Result = Invoke-VMScript -VM $VM -GuestCredential $DomainAdmin -ScriptText $CMD

Write-Verbose $Result.ScriptOutput

## ----- Create vCenter AD user
#if ( -Not ([bool](get-aduser -server $ADServer -Filter {SamAccountName -eq "$($VCSAViewUser.UserName)"} -Credential $DomainAdmin) ) ) {
#    Write-Verbose "Creating vCenter AD User for Connection Server"
#
#    $VCenterAcct = New-ADUser -Server $ADServer -Credential $DomainAdmin -Name $VCSAViewUser.UserName -Description "vCenter AD account for Connection Server" -Path $ConfigData.AllNodes.ServiceAcctsOU -AccountPassword $VCSAViewUser.Password -Enabled $True
#}

#### ----- Create Instant Clone AD User
###if ( -Not ([bool]( Get-ADUser -Server $ADServer -Filter {SamAccountName -eq "$($InstantCloneUser.UserName)"} -Credential $DomainAdmin ) ) ) {
###    Write-Verbose "Creating Instant Clone AD User"
###
###    $ICAcct = New-ADUser -Server $ADServer -Credential $DOmainAdmin -Name $InstantCloneUser.UserName -AccountPassword $InstantCloneUser.Password -Description "Instant Clone User" -Path $ConfigData.AllNodes.ServiceAcctsOU -Enabled $True
###}

# ----- Create VCSA Role and assign vCenter User to it
Write-Verbose "Creating VCSA Role for vCenter View user"

$Priviledges = 'Datastore.AllocateSpace','Folder.Create','Folder.Delete','Global.VCServer','Host.Config.AdvancedConfig','Resource.AssignVMToPool',
    'System.Anonymous','System.Read','System.View','VirtualMachine.Config.AddRemoveDevice','VirtualMachine.Config.AdvancedConfig',
    'VirtualMachine.Config.EditDevice','VirtualMachine.Interact.PowerOff','VirtualMachine.Interact.PowerOn','VirtualMachine.Interact.Reset',
    'VirtualMachine.Interact.SESparseMaintenance','VirtualMachine.Interact.Suspend','VirtualMachine.Inventory.Create','VirtualMachine.Inventory.CreateFromExisting',
    'VirtualMachine.Inventory.Delete','VirtualMachine.Provisioning.Clone','VirtualMachine.Provisioning.CloneTemplate',
    'VirtualMachine.Provisioning.Customize','VirtualMachine.Provisioning.DeployTemplate','VirtualMachine.Provisioning.ReadCustSpecs' 

if ( -Not ( Get-VIRole -name $ConfigData.AllNodes.VCSAViewRole -ErrorAction SilentlyContinue ) ) {
    Write-Verbose "Creating"

    New-VIRole -name $ConfigData.AllNodes.VCSAViewRole -Privilege ( Get-VIPrivilege -Server $ConfigData.Allnodes.VCSAServer -Id $Priviledges ) 

    # ----- Do I need Set-VIRole here? https://docs.vmware.com/en/VMware-App-Volumes/2.14/com.vmware.appvolumes.admin.doc/GUID-505624F3-F3EB-428C-BEA0-5BD7F6095A1F.html

}
Else {
    Write-Verbose "Role already exists"
}

$VM = Get-VM -Name $Configdata.AllNodes.NodeName -ErrorAction Stop

# ----- regular expression to extract IP address from IPv4 and IPv6 Ip array.
$IPAddress = $VM.Guest.IpAddress | Select-String -Pattern "\b(?:(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\b"








# ----- View API doc : https://code.vmware.com/apis/956/view
# ----- Connect to View Server

$HV = Connect-HVServer -Server $IPAddress -Credential $DomainAdmin


# ----- Set license
if ( -Not ( ($HV.ExtensionData.License.License_Get()).Licensed ) ) {
    Write-Verbose "License key does not exist.  Installing"

    $HV.ExtensionData.License.License_Set( $HVLicense )
}
Else {
    Write-Verbose "License installed"
}

# ----- Add vCenter Server to View
if ( (($HV.ExtensionData.VirtualCenter.VirtualCenter_List()).ServerSpec.Servername -ne $ConfigData.AllNodes.VCSA) -or (-Not ($HV.ExtensionData.VirtualCenter.VirtualCenter_List()))  ) {
    Write-Verbose "vCenter Server is not configured"

    # ------ https://www.retouw.nl/vsphere/adding-vcenter-server-to-horizon-view-using-the-apis/
    $VCSpec = New-object -TypeName VMware.Hv.VirtualCenterSpec
    $VCSpec.ServerSpec = New-Object -TypeName VMware.Hv.ServerSpec
    $VCSpec.ServerSpec.ServerName = $ConfigData.AllNodes.VCSA
    $VCSpec.ServerSpec.port = 443
    $VCSpec.ServerSpec.UseSSL = $True
    $VCSpec.ServerSpec.UserName = $VCenterAdmin.UserName

    # ----- convert password to HV securestring
    $vcpassword=$VCenterAdmin.Password
    $temppw = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($vcPassword)
    $PlainvcPassword = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($temppw)
    $vcencPassword = New-Object VMware.Hv.SecureString
    $enc = [system.Text.Encoding]::UTF8
    $vcencPassword.Utf8String = $enc.GetBytes($PlainvcPassword)

    $VCspec.ServerSpec.password = $vcencPassword
    $VCSpec.ServerSpec.ServerType = "VIRTUAL_Center"

    #$HV.ExtensionData.VirtualCenter.VirtualCenter_Create($HV.ExtensionData,$VCSpec)
    $HV.ExtensionData.VirtualCenter.VirtualCenter_Create($VCSpec)
}
Else {
    Write-Verbose "vCenter Server already associated with View"
}

# ----- Clean up
Remove-PSDrive -Name RemoteDrive

Write-Verbose "Done"


#