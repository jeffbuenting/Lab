[CmdletBinding()]
Param (
    [PSCredential]$LocalAdmin = (Get-Credential -UserName administrator -Message "Servers Local Admin Account"),

    [PSCredential]$VCenterAdmin = (Get-Credential -Message "vCenter Account" ),

    [int]$Timeout = '900',

    [Parameter (Mandatory=$True)]
    [String]$DSCModulePath

#    [PSCredential]$ADRecoveryAcct = (Get-Credential -UserName '(Password Only)' -Message "New Domain Safe Mode Administrator Password"),

#    [PSCredential]$DomainAdmin = (Get-Credential -UserName "$($ConfigData.AllNodes.DomainName)\administrator" -Message "New Domain Admin Credential")
)

# ----- Dot source configs and DSC scripts
Write-Verbose "Dot sourcing scripts"

# ----- Load the Config Data
. $PSScriptRoot\DSCConfigs\Config_New-LABRouter.PS1

. $PSScriptRoot\DSCConfigs\New-LABRouter.ps1

# ----- Dot source LCM config
. $PSScriptRoot\DSCConfigs\LCMConfig.ps1

# ----- Build the MOF files for both the LCM and DSC script
# ----- Build the Config MOF
try {
    LCMConfig -OutputPath C:\Scripts\Lab\MOF -ErrorAction Stop

    New-LABRouter -ConfigurationData $ConfigData `
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

if ( -Not ( Get-VM -Name $ConfigData.AllNodes.NodeName -ErrorAction SilentlyContinue ) ) {

     Try {
        # ----- Create the VM.  In this case we are building from a VM Template.  But this could be modified to be from an ISO.
        Write-Verbose "Creating VM"
        $task = New-VM -Name $ConfigData.AllNodes.NodeName -Template $ConfigData.AllNodes.VMTemplate -vmhost $ConfigData.AllNodes.ESXHost -ResourcePool $ConfigData.AllNodes.ResourcePool -OSCustomizationSpec $ConfigData.AllNodes.OSCustomization -ErrorAction Stop -RunAsync
    
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
        Get-NetworkAdapter -vm $VM -Name 'Network adapter 1' -ErrorAction Stop | Set-NetworkAdapter -Portgroup (Get-VirtualPortGroup -VirtualSwitch $ConfigData.AllNodes.ExternalSwitch -Name $ConfigData.AllNodes.ExternalPortGroup -ErrorAction Stop) -Confirm:$False -ErrorAction Stop 
        New-NetworkAdapter -vm $VM -Type Vmxnet3 -Portgroup (Get-VirtualPortGroup -VirtualSwitch $ConfigData.AllNodes.Switch -Name $ConfigData.AllNodes.PortGroup -ErrorAction Stop) -StartConnected -ErrorAction Stop

        Set-VM -VM $VM -NumCpu 2 -MemoryGB 2 -Confirm:$False

        Write-Verbose "Starting VM"
        Start-VM -VM $VM -ErrorAction Stop | Wait-Tools

        # ----- Seems to be an issue where the Wait-Tools completes but the VM is still not powered on.  But only for this vm.
        Write-Verbose "Pausing for VM to Poweron..."
        while ( $VM.PowerState -ne 'PoweredOn' ) {
            Write-Verbose "Powerstate = $($VM.PowerState)"
            start-sleep -Seconds 5
            $VM = Get-VM -Name $Configdata.AllNodes.NodeName -ErrorAction Stop
        }

        Write-Verbose "Waiting for OS Custumizations to complete after the VM has powered on."
        wait-vmwareoscustomization -vm $VM -Timeout $Timeout -Verbose:$IsVerbose

         # ----- Set DNS
        $DNS = "c:\windows\system32\netsh.exe interface ip set dns name=""Ethernet0"" static $($ConfigData.AllNodes.DNSServer)"
        Invoke-VMScript –VM $VM  -GuestCredential $LocalAdmin -ScriptType bat -ScriptText $DNS -ErrorAction Stop

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
        Throw "Build-NewLABRouter : Error building the VM.`n`n     $ExceptionMessage`n`n $ExceptionType"
    }
}
Else {
    Write-Verbose "VM already exists.  Continuing to configuration"
}

if ( $VM.PowerState -ne 'PoweredOn' ) { 
    Write-Verbose "Starting VM..."
    Start-VM -VM $VM | Wait-Tools 
}

$IPAddress = $VM.Guest.IpAddress[0]

Write-Verbose "Checking if Temp directory exists"
# ----- The MOF files were created with the new VMs name.  we need to copy it to the server and change the name to Localhost to run locally
$CMD = "if ( -Not (Test-Path ""\\$IPAddress\c$\temp"") ) { New-Item -ItemType Directory -Path ""\\$IPAddress\c$\temp"" }"
Invoke-VMScript -vm $VM -GuestCredential $LocalAdmin -ScriptText $CMD

# ----- SI decided for now to keep the firewall off.  But this is where you would configure the rules
Write-Verbose "DISabling firewall."
Try {
    Invoke-VMScript -vm $VM -GuestCredential $LocalAdmin -ScriptText "Set-NetFirewallProfile -Profile Domain,Private,Public -Enabled False -Verbose" -ErrorAction Stop
    #Invoke-VMScript -vm $VM -GuestCredential $LocalAdmin -ScriptText "Enable-NetFirewallRule -Name FPS-ICMP4-ERQ-In,FPS-SMB-In-TCP" -ErrorAction Stop
}
Catch {
    $ExceptionMessage = $_.Exception.Message
    $ExceptionType = $_.Exception.GetType().Fullname
    Throw "Build-NewLABDomain : Error enabling firewall rules.`n`n     $ExceptionMessage`n`n $ExceptionType"
}

# ----- Remove the drive if it exists
if ( Get-PSDrive -Name RemoteDrive -ErrorAction SilentlyContinue ) { Remove-PSDrive -Name RemoteDrive }
New-PSDrive -Name RemoteDrive -PSProvider FileSystem -Root "\\$($VM.Guest.HostName)\c$" -Credential $LocalAdmin

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
Write-Verbose "Copy DSC Resources from $DSCModulePath"
copy-item -path $DSCModulePath\xComputerManagement -Destination "RemoteDrive:\Program Files\WindowsPowerShell\Modules" -Recurse -force
Copy-Item -path $DSCModulePath\NetworkingDSC -Destination "RemoteDrive:\Program Files\WindowsPowerShell\Modules" -Recurse -force


# ----- Run Config MOF on computer
Write-Verbose "Final DSC COnfig"

$DSCSuccess = $False
$Trys = 0
Do {
    Try {
        Start-Sleep -Seconds 60

        $Cmd = "Start-DscConfiguration -path C:\temp -Wait -Verbose -force"
        Invoke-VMScript -VM $VM -GuestCredential $LocalAdmin -ScriptText $CMD 
    }
    Catch {
        Write-Warning "Problem running DSC.  Pausing and then will retry"
        $DSCSuccess = $False
        $Trys++



        Write-Verbose "Retrying ..."
    }
} While ( (-Not $DSCSuccess) -and ($Trys -lt 5) )

# ----- Clean up
Remove-PSDrive -Name RemoteDrive
