<#
    .SYNOPSIS
        Script to create and Configure SQL Server

    .DESCRIPTION
        I got tired of rebuilding the lab everytime the trial versions expired.  So using the IaaS model this code 

    .Links
       
#>

[CmdletBinding()]
Param (
 #   [PSCredential]$VCenterAdmin = (Get-Credential -Message "vCenter Account" ),
 #
    [PSCredential]$DomainAdmin = (Get-Credential -UserName "$($ConfigData.AllNodes.DomainName)\administrator" -Message "New Domain Admin Credential"),
 
    [PSCredential]$LocalAdmin,
 
    [String]$DSCModulePath,
 
    [int]$Timeout = '900'
)


$VerbosePreference = 'Continue'

$IsVerbose = $False
if ( $VerbosePreference -eq 'Continue' ) { $IsVerbose = $True }

Write-Verbose "----- Building Windows Container Server"

# ----- Dot source configs and DSC scripts
Write-Verbose "Dot sourcing scripts"

# ----- Load the Config Data
. $PSScriptRoot\DSCConfigs\Config_WINContainerSvr.ps1

. $PSScriptRoot\DSCConfigs\New-WINContainerSvr.ps1

# ----- Dot source LCM config (same for all scripts)
. "$((Get-item -Path 'C:\Scripts\Lab\HorizonView LAB').Parent.FullName)\DSCConfigs\LCMConfig.ps1"

# ----- Build the MOF files for both the LCM and DSC script
# ----- Build the Config MOF
Write-Verbose "Building DSC MOF"
if ( -Not (Test-Path "$PSScriptRoot\MOF") ) { New-Item -ItemType Directory -Path "$PSScriptRoot\MOF" }

try {
    LCMConfig -OutputPath $PSSCriptRoot\MOF -ErrorAction Stop

    New-WINContainerSvr -ConfigurationData $ConfigData `
        -DomainAdmin $DomainAdmin `
        -OutputPath $PSScriptRoot\MOF `
        -ErrorAction Stop
}
Catch {
    $ExceptionMessage = $_.Exception.Message
    $ExceptionType = $_.Exception.GetType().Fullname
    Throw "Build-NewLABDomain : There was a problem building the MOF.`n`n     $ExceptionMessage`n`n $ExceptionType"
}

# ----- Build new VM if one does not already exist


    New-LABVM -VMName $ConfigData.AllNodes.NodeName `
        -ESXHost $ConfigData.AllNodes.ESXHost `
        -Template $ConfigData.AllNodes.VMTemplate `
        -OSCustomization $ConfigData.AllNodes.OSCustomization `
        -ResourcePool $ConfigData.AllNodes.ResourcePool `
        -VMSwitch $ConfigData.AllNodes.Switch `
        -PortGroup $ConfigData.AllNodes.Portgroup `
        -DataStore $ConfigData.AllNodes.DataStore `
        -LocalAdmin $LocalAdmin `
        -CPU 4 `
        -Memory 4 `
        -Timeout $Timeout `
        -ErrorAction Stop `
        -Verbose

Write-Verbose "Getting VM IP"       
$VM = Get-VM -Name $ConfigData.AllNodes.NodeName

Write-Verbose "$($VM.Guest.IPAddress | Out-String)"

$IPAddress = $VM.Guest.ipaddress | select-string -Pattern "\d{1,3}\.\d{1,3}\.\d{1,3}"

Write-Verbose "IPAddress = $($IPAddress | Out-String)"

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
    New-PSDrive -Name RemoteDrive -PSProvider FileSystem -Root "\\$IPAddress\c$" -Credential $LocalAdmin -ErrorAction Stop
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
    Copy-Item -Path "$PSScriptRoot\mof\$($Configdata.AllNodes.NodeName).mof" -Destination RemoteDrive:\temp\localhost.mof -ErrorAction Stop -Force
#    COpy-Item -Path "$PSScriptRoot\mof\$($Configdata.AllNodes.NodeName).meta.mof" -Destination RemoteDrive:\temp\localhost.meta.mof


    #copy-item -path C:\Scripts\lab\MOF\KW-DC1.mof -Destination RemoteDrive:\temp\localhost.mof
    #copy-item -path C:\Scripts\lab\MOF\KW-DC1.meta.mof -Destination RemoteDrive:\temp\localhost.meta.mof

    # ----- We are not using a DSC Pull server so we need to make sure the DSC resources are on the remote computer
    Write-Output "Copy DSC Resources"
    Copy-ItemIfNotThere -path $DSCModulePath\xComputerManagement -Destination "RemoteDrive:\Program Files\WindowsPowerShell\Modules" -Recurse -ErrorAction Stop 
    Copy-ItemIfNotThere -path $DSCModulePath\NetworkingDSC -Destination "RemoteDrive:\Program Files\WindowsPowerShell\Modules" -Recurse -ErrorAction Stop 
    Copy-ItemIfNotThere -path $DSCModulePath\xWindowsUpdate -Destination "RemoteDrive:\Program Files\WindowsPowerShell\Modules" -Recurse -ErrorAction Stop
    Copy-ItemIfNotThere -path $DSCModulePath\xTimeZone -Destination "RemoteDrive:\Program Files\WindowsPowerShell\Modules" -Recurse -ErrorAction Stop
    Copy-ItemIfNotThere -path $DSCModulePath\xSystemSecurity -Destination "RemoteDrive:\Program Files\WindowsPowerShell\Modules" -Recurse -ErrorAction Stop

   
}
Catch {
    $ExceptionMessage = $_.Exception.Message
    $ExceptionType = $_.Exception.GetType().Fullname
    Throw "Build-NewLABSQL : Error Copying DSC Resources.`n`n     $ExceptionMessage`n`n $ExceptionType"
}




# ----- Run Config MOF on computer
$DSCSuccess = $False
$Trys = 0
#Do {
    Try {
        Write-Verbose "Running DSC config"

        Start-Sleep -Seconds 60

        $Cmd = "Start-DscConfiguration -path C:\temp -Wait -Verbose -force"
        Invoke-VMScript -VM $VM -GuestCredential $LocalAdmin -ScriptText $CMD 
        $DSCSuccess = $True
    }
    Catch {
        Write-Warning "Problem running DSC.  Pausing and then will retry"
        $DSCSuccess = $False
        $Trys++

 #       Write-Verbose "Retrying ..."
    }
#} While ( (-Not $DSCSuccess) -and ($Trys -lt $Timeout) )

#Write-verbose "wait and then reboot"
#Start-Sleep -Seconds 600
#
#Restart-VMGuest -VM $VM -Confirm:$False
#

