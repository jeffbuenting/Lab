# ----- Configure AD OU etc for VMWare Horizon View.  

# ----- NOTE : May need to remove and readd Horizon servers to domain when domain is rebuilt

[CmdletBinding()]
Param (
    [PSCredential]$VCenterAdmin = (Get-Credential -Message "vCenter Account" ),

   [PSCredential]$LocalAdmin = (Get-Credential -UserName administrator -Message "Servers Local Admin Account"),

    [PSCredential]$DomainAdmin,

    [String]$ADServer,

    [String]$DSCModulePath,

    [int]$Timeout = '900',

    [String]$Source = 'C:\Source\VMware'
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

# ----- Connect to vCenter service so we can deal with the VM
Try {
    Connect-VIServer -Server 192.168.1.16 -Credential $VCenterAdmin -ErrorAction Stop
}
Catch {
    $ExceptionMessage = $_.Exception.Message
    $ExceptionType = $_.Exception.GetType().Fullname
    Throw "Build-NewLABRouter : Error Connecting to vCenter.`n`n     $ExceptionMessage`n`n $ExceptionType"
}

# ----- Only do this if the VM does not exist.  This allows us to rerun this script if there is an error and pick up where it left off

if ( -Not (Get-VM -Name $ConfigData.AllNodes.NodeName -ErrorAction SilentlyContinue) ) {
    Write-Verbose "VM does not exist, Creating"

    Try {
        # ----- Create the VM.  In this case we are building from a VM Template.  But this could be modified to be from an ISO.
        Write-Verbose "Creating VM"
        $task = New-VM -Name $ConfigData.AllNodes.NodeName -Template $ConfigData.AllNodes.VMTemplate -vmhost $ConfigData.AllNodes.ESXHost -ResourcePool $ConfigData.AllNodes.ResourcePool -OSCustomizationSpec 'WIN 2016 Sysprep' -ErrorAction Stop -RunAsync
    
        Write-Verbose "waiting for new-vm to complete"

        Write-Verbose "Task State = $($Task.State )"
        while ( $Task.state -ne 'Success' ) {
            Start-Sleep -Seconds 60

            Write-Verbose "Still waiting for new-vm to complete"

            $Task = Get-Task -Id $Task.Id -Verbose:$False
            Write-Verbose "Task State = $($Task.State)"
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

        Write-Verbose "Starting VM and wait for VM Tools to start."
        $VM = Start-VM -VM $VM -ErrorAction Stop | Wait-Tools



        Write-Verbose "Waiting for OS Custumizations to complete after the VM has powered on."
        wait-vmwareoscustomization -vm $VM -Timeout $Timeout -Verbose:$IsVerbose


        Write-Verbose "Getting VM INfo"
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

    Write-verbose "We appear to be going too fast and the VM has not settled.  Pausing to let it."
    $Seconds = 300
    $T = 0
    while ( $T -le $Seconds ) { 
        Write-Verbose "Waiting for VM to 'Settle'..."
        Start-Sleep -Seconds 5
        $T += 5
    }

}
Else {
    Write-Verbose "VM Exists running config"
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
copy-item -path $DSCModulePath\xComputerManagement -Destination "RemoteDrive:\Program Files\WindowsPowerShell\Modules" -Recurse -force
Copy-Item -path $DSCModulePath\NetworkingDSC -Destination "RemoteDrive:\Program Files\WindowsPowerShell\Modules" -Recurse -force
Copy-Item -path $DSCModulePath\xSystemSecurity -Destination "RemoteDrive:\Program Files\WindowsPowerShell\Modules" -Recurse -force

# ----- Source install files
Write-Verbose "install source"
copy-item -path $Source\VMware-Horizon-Connection-Server-x86_64-7.12.0-15770369.exe -Destination "RemoteDrive:\Temp" -Recurse -force


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

        # ----- Invoke-VMScript will error as the VM DSC config forces a reboot.
        $Result = Invoke-VMScript -VM $VM -GuestCredential $LocalAdmin -ScriptText $CMD  -ErrorAction SilentlyContinue

        Write-Output "Results = $($Result | out-string)"

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

$VM = Get-VM -Name $Configdata.AllNodes.NodeName -ErrorAction Stop


# ----- Wait for vm to reboot
Write-Verbose "Waiting for VM "
While ( -Not (Get-Service -ComputerName $IPAddress -Name WinRM -ErrorAction SilentlyContinue ) ) {
    Start-Sleep -s 5
    Write-Verbose "Still Waiting"
}


Write-Verbose "installing VMWare Horizon View server"

# ----- I broke this up as the quoting was confusing
$Arguments = '/s /v "/qn /l c:\temp\viewinstall.log VDM_SERVER_INSTANCE_TYPE=1 INSTALLDIR=""C:\Program Files\VMware\VMware View\Server\"" FWCHOICE=1 VDM_SERVER_RECOVERY_PWD=Branman1! VDM_SERVER_RECOVERY_PWD_REMINDER=""yep"""'
$CMD = "& 'C:\temp\VMware-Horizon-Connection-Server-x86_64-7.12.0-15770369.exe' $Arguments"
Invoke-VMScript -VM $VM -GuestCredential $DomainAdmin -ScriptText $CMD

# ----- DNS doesn't seem to be working in by environment ( because I am using a work laptop ) for this server so I need to add a config file that does this
#https://kb.vmware.com/s/article/2144768
'checkOrigin=false' | Set-Content -Path "RemoteDrive:\Program Files\VMware\VMware View\Server\locked.properties"

Get-service -ComputerName $Configdata.AllNodes.NodeName -Name wsbroker | Restart-Service

# ----- Add License to Server
Write-Verbose "Adding license key to View Connection Server"

$CMD = "Set-License -Key $ConfigDatat.AllNodes.ViewLicense"
Invoke-VMScript -VM $VM -GuestCredential $DomainAdmin -ScriptText $CMD

# ----- Clean up
Remove-PSDrive -Name RemoteDrive

Write-Verbose "Done"


#