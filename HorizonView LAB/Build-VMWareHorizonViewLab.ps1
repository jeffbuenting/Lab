# ----- Configure AD OU etc for VMWare Horizon View.  

# ----- NOTE : May need to remove and readd Horizon servers to domain when domain is rebuilt

[CmdletBinding()]
Param (
   # [PSCredential]$VCenterAdmin = (Get-Credential -Message "vCenter Account" ),

   #[PSCredential]$LocalAdmin = (Get-Credential -UserName administrator -Message "Servers Local Admin Account"),

    #[PSCredential]$DomainAdmin,

    [String]$ADServer
)


$VerbosePreference = 'Continue'

## ----- Create OU for Remote Desktops
#Write-Verbose "Create OUs for VDI"
#if ( -Not (Get-ADOrganizationalUnit -Server $ADServer -Credential $DomainAdmin -Filter 'Name -like "VDI"') ) {
#    Write-Verbose "VDI OU does not exist.  Creating"
#    New-ADOrganizationalUnit -Server $ADServer -Credential $DomainAdmin -Name VDI
#}
#
## ----- OU for VDI Service Accounts
#Write-Verbose "Create OU for Horizon View Service Accounts"
#if ( -Not (Get-ADOrganizationalUnit -Server $ADServer -Credential $DomainAdmin -SearchBase "OU=VDI,DC=kings-wood,DC=local" -Filter 'Name -like "Service Accounts"') ) {
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

# ----- Dot source LCM config
. $PSScriptRoot\DSCConfigs\LCMConfig.ps1

# ----- Build the MOF files for both the LCM and DSC script
# ----- Build the Config MOF
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

# ----- Connect to vCenter service so we can deal with the VM
Try {
    Connect-VIServer -Server 192.168.1.16 -Credential $VCenterAdmin -ErrorAction Stop
}
Catch {
    $ExceptionMessage = $_.Exception.Message
    $ExceptionType = $_.Exception.GetType().Fullname
    Throw "Build-NewLABRouter : Error Connecting to vCenter.`n`n     $ExceptionMessage`n`n $ExceptionType"
}
Try {
    # ----- Create the VM.  In this case we are building from a VM Template.  But this could be modified to be from an ISO.
    Write-Verbose "Creating VM"
    $Task = New-VM -Name $ConfigData.AllNodes.NodeName -Template $ConfigData.AllNodes.VMTemplate -vmhost $ConfigData.AllNodes.ESXHost -ResourcePool $ConfigData.AllNodes.ResourcePool -OSCustomizationSpec 'WIN 2016 Sysprep' -ErrorAction Stop -RunAsync 
    
    Write-Verbose "wainting for new-vm to complete"
    Write-Verbose $($Task.State )
    while ( $Task.state -ne 'Success' ) {
        Start-Sleep -Seconds 60

        $Task = Get-Task -Id $Task.Id
        Write-Verbose $($Task.State )
    }


    write-verbose "VM done"
    $VM = Get-VM -Name $Configdata.AllNodes.NodeName -ErrorAction Stop

}
Catch {
    $ExceptionMessage = $_.Exception.Message
    $ExceptionType = $_.Exception.GetType().Fullname
    Throw "Build-NewLABRouter : Error building the VM.`n`n     $ExceptionMessage`n`n $ExceptionType"
}

Try {

    # ----- Attach the VM to the portgroup
    Write-verbose "Attaching NIC to correct network"
    $VMNIC = Get-NetworkAdapter -vm $VM -Name 'Network adapter 1' 
    Write-Verbose "NIC = $($VMNIC | Out-String)"
    
    $PG = (Get-VirtualPortGroup -VirtualSwitch $ConfigData.AllNodes.Switch -Name $ConfigData.AllNodes.PortGroup -ErrorAction SilentlyContinue)
    Write-Verbose "PG = $($PG | Out-String)"

    $VMNIC | Set-NetworkAdapter -Portgroup $PG -Confirm:$False -ErrorAction SilentlyContinue


    #$VMNic = Get-NetworkAdapter -vm $VM -ErrorAction Stop 
    #if ( $VMNIC.NetworkName -ne $ConfigData.AllNodes.PortGroup ) {
    #    $VMNIC | Set-NetworkAdapter -Portgroup (Get-VirtualPortGroup -VirtualSwitch $ConfigData.AllNodes.Switch -Name $ConfigData.AllNodes.PortGroup -ErrorAction Stop) -Confirm:$False -ErrorAction Stop
    #}

    Write-Verbose "Setting CPU and Memory"
    Set-VM -VM $VM -NumCpu 2 -MemoryGB 4 -Confirm:$False

    Write-Verbose "Starting VM"
    Start-VM -VM $VM -ErrorAction Stop | Wait-Tools

    # ----- reget the VM info.  passing the info via the start-vm cmd is not working it would seem.
    $VM = Get-VM -Name $Configdata.AllNodes.NodeName -ErrorAction Stop

    # ----- Sometimes the VM hostname does not get filled in.  Waiting for a bit and trying again.
    while ( -Not $VM.Guest.HostName ) {
        Write-Verbose "Pausing 15 Seconds..."
        Sleep -Seconds 15

        $VM = Get-VM -Name $Configdata.AllNodes.NodeName -ErrorAction Stop
    }
}
Catch {
    $ExceptionMessage = $_.Exception.Message
    $ExceptionType = $_.Exception.GetType().Fullname
    Throw "Configuring the VM.`n`n     $ExceptionMessage`n`n $ExceptionType"
}


Write-verbose "Waiting for VM to start"
$VM = Get-VM -Name $Configdata.AllNodes.NodeName

while ( $VM.Guest.State -ne 'Running' ) {
    Write-Verbose "Pausing 15 Seconds..."
    Sleep -Seconds 15

    $VM = Get-VM -Name $Configdata.AllNodes.NodeName -ErrorAction Stop
}

Write-verbose "sleep and reget info"
Start-Sleep -Seconds 120


$VM = Get-VM -Name $Configdata.AllNodes.NodeName -ErrorAction Stop
$VM.Guest


$IPAddress = $VM.Guest.IpAddress[0]

Write-Verbose "Checking if Temp directory exists"
# ----- The MOF files were created with the new VMs name.  we need to copy it to the server and change the name to Localhost to run locally
$CMD = "if ( -Not (Test-Path ""c:\temp"") ) { New-Item -ItemType Directory -Path ""c:\temp"" }"
Invoke-VMScript -vm $VM -GuestCredential $LocalAdmin -ScriptText $CMD

# ----- Remove the drive if it exists
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
copy-item -path C:\Users\600990\Documents\WindowsPowerShell\Modules\xComputerManagement -Destination "RemoteDrive:\Program Files\WindowsPowerShell\Modules" -Recurse -force
Copy-Item -path C:\users\600990\Documents\WindowsPowerShell\Modules\NetworkingDSC -Destination "RemoteDrive:\Program Files\WindowsPowerShell\Modules" -Recurse -force

# ----- Source install files
Write-Verbose "install source"
copy-item -path C:\Source\VMware\VMware-Horizon-Connection-Server-x86_64-7.10.0-14584133.exe -Destination "RemoteDrive:\Temp" -Recurse -force


# ----- Because I can't get DSC to set the DNS server I am doing before the config runs
Write-Verbose "Set Interface DNS "
$CMD = "import-module DNSClient; Set-DnsClientServerAddress -InterfaceIndex (Get-NetAdapter -Name Ethernet0).interfaceindex -ServerAddresses ($($Configdata.AllNodes.DNSServer -join ','))"
Invoke-VMScript -VM $VM -GuestCredential $LocalAdmin -ScriptText $CMD

# ----- Run Config MOF on computer
Write-Verbose "Final DSC MOF"

#$DSCSuccess = $False
#$Trys = 0
#Do {
#    Try {
        Start-Sleep -Seconds 60

        $Cmd = "Start-DscConfiguration -path C:\temp -Wait -Verbose -force"
        Invoke-VMScript -VM $VM -GuestCredential $LocalAdmin -ScriptText $CMD 
        $DSCSuccess = $True

#    }
#    Catch {
#        Write-Warning "Problem running DSC.  Pausing and then will retry"
#        $DSCSuccess = $False
#        $Trys++
#
#
#
#        Write-Verbose "Retrying ..."
#    }
#} While ( (-Not $DSCSuccess) -and ($Trys -lt $Timeout) )






# ----- Clean up
Remove-PSDrive -Name RemoteDrive




#