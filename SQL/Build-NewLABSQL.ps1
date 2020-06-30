<#
    .SYNOPSIS
        Script to create and Configure SQL Server

    .DESCRIPTION
        I got tired of rebuilding the lab everytime the trial versions expired.  So using the IaaS model this code 

    .Links
       
#>

[CmdletBinding()]
Param (
    [PSCredential]$VCenterAdmin = (Get-Credential -Message "vCenter Account" ),

    [PSCredential]$DomainAdmin = (Get-Credential -UserName "$($ConfigData.AllNodes.DomainName)\administrator" -Message "New Domain Admin Credential"),

    [PSCredential]$SQLSvcAccount,

    [PSCredential]$SAAccount,

    [String]$DSCModulePath,

    [int]$Timeout = '900'
)


# ----- Dot source configs and DSC scripts
Write-Output "Dot sourcing scripts"

# ----- Load the Config Data
. $PSScriptRoot\DSCConfigs\Config_New-LABSQL.PS1

# ----- Dot source New-LABDomain
. $PSScriptRoot\DSCConfigs\New-LABSQL.PS1

# ----- Dot source LCM config (same for all scripts)
. "$((Get-item -Path $PSScriptRoot).Parent.FullName)\DSCConfigs\LCMConfig.ps1"

# ----- Build the MOF files for both the LCM and DSC script
# ----- Build the Config MOF
try {
    Write-Output "Building Config MOF"

    LCMConfig -OutputPath $PSScriptRoot\MOF -ErrorAction Stop

    Write-Output "BUilding SQL MOF"
    New-LABSQL -ConfigurationData $ConfigData `
        -domainCred $DomainAdmin `
        -SQLSvcAccount $SQLSvcAccount `
        -SAAccount $SAAccount `
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
    Throw "Build-NewLABDomain : Error Connecting to vCenter.`n`n     $ExceptionMessage`n`n $ExceptionType"
}

# ----- Build new VM if one does not already exist
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
        Throw "Build-NewLABSQL : Error building the VM.`n`n     $ExceptionMessage`n`n $ExceptionType"
    }

    Try {

        # ----- Attach the VM to the portgroup
        Write-verbose "Attaching NIC to correct network"
        Get-NetworkAdapter -vm $VM -ErrorAction Stop | Set-NetworkAdapter -Portgroup (Get-VirtualPortGroup -VirtualSwitch $ConfigData.AllNodes.Switch -Name $ConfigData.AllNodes.PortGroup -ErrorAction Stop) -Confirm:$False -ErrorAction Stop

        Write-Verbose "Modifying CPU and memory"
        Set-VM -VM $VM -NumCpu 2 -MemoryGB 2 -confirm:$False
     
        Write-Verbose "Starting VM and wait for VM Tools to start."
        $VM = Start-VM -VM $VM -ErrorAction Stop | Wait-Tools

        Write-Verbose "Waiting for OS Custumizations to complete after the VM has powered on."
        wait-vmwareoscustomization -vm $VM -Timeout $Timeout -Verbose:$IsVerbose

        Write-Verbose "Getting VM INfo"
        # ----- reget the VM info.  passing the info via the start-vm cmd is not working it would seem.
        $VM = Get-VM -Name $Configdata.AllNodes.NodeName -ErrorAction Stop

        # ----- Sometimes the VM hostname and IPAddress to be correct does not get filled in.  Waiting for a bit and trying again.
        $Timeout = 5

        $Trys = 0
        Do  {
            Write-Verbose "Pausing ..."
            Sleep -Seconds 30

            $VM = Get-VM -Name $Configdata.AllNodes.NodeName -ErrorAction Stop

            $Trys++

            Write-Verbose "HostName = $($VM.Guest.HostName)"
            Write-Verbose "IP = $($VM.Guest.IPAddress)"
            Write-Verbose "Trys = $Trys"
        } while ( ( -Not $VM.Guest.HostName ) -and ( $VM.Guest.IPAddress[0] -notmatch '\d{1,3].\d{1,3].\d{1,3].\d{1,3]}') -and ($Trys -lt $Timeout ) )

        if ( $Trys -eq $Timeout ) { Throw "Build-NewLABSQL : TimeOut getting VM info" }

        # ----- and because we don't have a DHCP server on this network we need to apply an IP
        $netsh = “c:\windows\system32\netsh.exe interface ip set address name=""Ethernet0"" static $($ConfigData.AllNodes.IPAddress) $($ConfigData.AllNodes.SubnetMask) $($ConfigData.AllNodes.DefaultGateway)"
        Invoke-VMScript –VM $VM  -GuestCredential $LocalAdmin -ScriptType bat -ScriptText $netsh -ErrorAction Stop

        # ----- Set DNS
        $DNS = "c:\windows\system32\netsh.exe interface ip set dns name=""Ethernet0"" static $($ConfigData.AllNodes.ExternalDNSServer)"
        Invoke-VMScript –VM $VM  -GuestCredential $LocalAdmin -ScriptType bat -ScriptText $DNS -ErrorAction Stop
    }
    Catch {
        $ExceptionMessage = $_.Exception.Message
        $ExceptionType = $_.Exception.GetType().Fullname
        Throw "Build-NewLABSQL : Error Configuring the VM.`n`n     $ExceptionMessage`n`n $ExceptionType"
    }
}
Else {
    Write-Verbose "VM already exists.  Continuing to configuration"
}
  
$VM = Get-VM -Name $ConfigData.AllNodes.NodeName

$IPAddress = $VM.Guest.IpAddress[0]

Write-Verbose "Checking if Temp directory exists"
Try {
    # ----- The MOF files were created with the new VMs name.  we need to copy it to the server and change the name to Localhost to run locally
    $CMD = "if ( -Not (Test-Path ""\\$IPAddress\c$\temp"") ) { New-Item -ItemType Directory -Path ""\\$IPAddress\c$\temp"" }"
    Invoke-VMScript -vm $VM -GuestCredential $LocalAdmin -ScriptText $CMD -ErrorAction Stop
}
Catch {
    $ExceptionMessage = $_.Exception.Message
    $ExceptionType = $_.Exception.GetType().Fullname
    Throw "Build-NewLABDomain : Problem checking if the temp drive exist.`n`n     $ExceptionMessage`n`n $ExceptionType"
}

# ----- So it seems that the windows firewall prevents mapping.  Opening port in firewall so I can mapp and copy files
Write-Verbose "enabling firewall rules for file share."
Try {
    Invoke-VMScript -vm $VM -GuestCredential $LocalAdmin -ScriptText "Enable-NetFirewallRule -Name FPS-ICMP4-ERQ-In,FPS-SMB-In-TCP" -ErrorAction Stop
}
Catch {
    $ExceptionMessage = $_.Exception.Message
    $ExceptionType = $_.Exception.GetType().Fullname
    Throw "Build-NewLABDomain : Error enabling firewall rules.`n`n     $ExceptionMessage`n`n $ExceptionType"
}


# ----- Remove the drive if it exists
Write-Verbose "Mapping drive to root of c on $($VM.Guest.HostName)"
if ( Get-PSDrive -Name RemoteDrive -ErrorAction SilentlyContinue ) { Remove-PSDrive -Name RemoteDrive }

Try {
    New-PSDrive -Name RemoteDrive -PSProvider FileSystem -Root "\\$($Configdata.AllNodes.IPAddress)\c$" -Credential $LocalAdmin -ErrorAction Stop
    #New-PSDrive -Name RemoteDrive -PSProvider FileSystem -Root "\\10.10.10.10\c$" -Credential $LocalAdmin -ErrorAction Stop
}
Catch {
    $ExceptionMessage = $_.Exception.Message
    $ExceptionType = $_.Exception.GetType().Fullname
    Throw "Build-NewLABDomain : mapping to root.`n`n     $ExceptionMessage`n`n $ExceptionType"
}

# ----- Copy LCM Config and run on remote system
Try {
    Write-Verbose "Configuring LCM"
    Copy-Item -Path $PSScriptRoot\mof\LCMConfig.meta.mof -Destination RemoteDrive:\temp\localhost.meta.mof
}
Catch {
    $ExceptionMessage = $_.Exception.Message
    $ExceptionType = $_.Exception.GetType().Fullname
    Throw "Build-NewLABDomain : Error Copying LCMConfig.Meta.Mof.`n`n     $ExceptionMessage`n`n $ExceptionType"
}


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


Try {
    Write-Output "Copying DSC resources to VM"
    Write-Output "Copy MOFs"
    Copy-Item -Path "$PSScriptRoot\mof\$($Configdata.AllNodes.NodeName).mof" -Destination RemoteDrive:\temp\localhost.mof -ErrorAction Stop
#    COpy-Item -Path "$PSScriptRoot\mof\$($Configdata.AllNodes.NodeName).meta.mof" -Destination RemoteDrive:\temp\localhost.meta.mof


    #copy-item -path C:\Scripts\lab\MOF\KW-DC1.mof -Destination RemoteDrive:\temp\localhost.mof
    #copy-item -path C:\Scripts\lab\MOF\KW-DC1.meta.mof -Destination RemoteDrive:\temp\localhost.meta.mof

    # ----- We are not using a DSC Pull server so we need to make sure the DSC resources are on the remote computer
    Write-Output "Copy DSC Resources"
    copy-item -path $DSCModulePath\xComputerManagement -Destination "RemoteDrive:\Program Files\WindowsPowerShell\Modules" -Recurse -ErrorAction Stop -force
    copy-item -path $DSCModulePath\sqlserverdsc -Destination "RemoteDrive:\Program Files\WindowsPowerShell\Modules" -Recurse -ErrorAction Stop -force
    copy-item -path $DSCModulePath\ccdromdriveletter -Destination "RemoteDrive:\Program Files\WindowsPowerShell\Modules" -Recurse -ErrorAction Stop -force
}
Catch {
    $ExceptionMessage = $_.Exception.Message
    $ExceptionType = $_.Exception.GetType().Fullname
    Throw "Build-NewLABDomain : Error Copying DSC Resources.`n`n     $ExceptionMessage`n`n $ExceptionType"
}

# ----- Mount the SQL ISO
 Try {   
    Write-Verbose "Mounting SQL ISO" 

    Get-CDDrive -vm $VM -ErrorAction Stop | Set-CDDrive -IsoPath $Configdata.AllNodes.SQLISO -StartConnected:$True -Connected:$True -Confirm:$False -ErrorAction Stop 
}
Catch {
    $ExceptionMessage = $_.Exception.Message
    $ExceptionType = $_.Exception.GetType().Fullname
    Throw "Problem mounting WINPE ISO.`n`n     $ExceptionMessage`n`n $ExceptionType" 
}

# ----- Create SQL Account on AD
# ----- create accounts for SQL
write-Verbose "DomainName = $($ConfigData.AllNodes.DomainName)"

$OU = $ConfigData.AllNodes.OU

Invoke-Command -ComputerName $ConfigData.AllNodes.DomainName -Credential $DomainAdmin -ScriptBlock {
    $VerbosePreference = $Using:VerbosePreference
    $SQLSVC = $Using:SQLSvcAccount

    $U = Get-ADUser -Identity ($SQLSvc.UserName.split('\\'))[1] -ErrorAction Ignore

    Write-Verbose "User = $($U | out-string )"

    if ( $U ) {
        Write-Verbose "$($SQLSvc.Username) already exists"
    }
    Else {
        Write-Verbose "Creating $($SQLSvc.Username)"

        New-ADUser -Name ($SQLSvc.UserName.Split('\\'))[1] -Path $Using:OU -AccountPassword $SQLSvc.Password -Enabled $true
    }

}

#restart-VM -VM $VM -Confirm:$False | Wait-Tools

# ----- Timed out waiting for tools in my envionment
Start-Sleep -Seconds 120


# ----- Run Config MOF on computer
$DSCSuccess = $False
$Trys = 0
Do {
    Try {
        Write-Verbose "Running SQL DSC config"

        Start-Sleep -Seconds 60

        $Cmd = "Start-DscConfiguration -path C:\temp -Wait -Verbose -force"
        $Result = Invoke-VMScript -VM $VM -GuestCredential $LocalAdmin -ScriptText $CMD 
        $DSCSuccess = $True
    }
    Catch {
        Write-Warning "Problem running DSC.  Pausing and then will retry"
        $DSCSuccess = $False
        $Trys++

        Write-Verbose "Retrying ..."
    }
} While ( (-Not $DSCSuccess) -and ($Trys -lt $Timeout) )


# ----- Clean up
Remove-PSDrive -Name RemoteDrive
