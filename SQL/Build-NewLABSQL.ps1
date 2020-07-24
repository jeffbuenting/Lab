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

    [PSCredential]$LocalAdmin,

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
    Copy-ItemIfNotThere -path $DSCModulePath\sqlserverdsc -Destination "RemoteDrive:\Program Files\WindowsPowerShell\Modules" -Recurse -ErrorAction Stop 
    Copy-ItemIfNotThere -path $DSCModulePath\ccdromdriveletter -Destination "RemoteDrive:\Program Files\WindowsPowerShell\Modules" -Recurse -ErrorAction Stop
    Copy-ItemIfNotThere -path $DSCModulePath\NetworkingDSC -Destination "RemoteDrive:\Program Files\WindowsPowerShell\Modules" -Recurse -ErrorAction Stop 
    Copy-ItemIfNotThere -path $DSCModulePath\xWindowsUpdate -Destination "RemoteDrive:\Program Files\WindowsPowerShell\Modules" -Recurse -ErrorAction Stop
    Copy-ItemIfNotThere -path $DSCModulePath\xTimeZone -Destination "RemoteDrive:\Program Files\WindowsPowerShell\Modules" -Recurse -ErrorAction Stop
    Copy-ItemIfNotThere -path $DSCModulePath\xSystemSecurity -Destination "RemoteDrive:\Program Files\WindowsPowerShell\Modules" -Recurse -ErrorAction Stop

    # ----- Copy required powershell module
    Copy-ItemIfNotThere -path $DSCModulePath\sqlserver -Destination "RemoteDrive:\Program Files\WindowsPowerShell\Modules" -Recurse -ErrorAction Stop

    # ----- Remove the drive if it exists
    Copy-ItemIfNotThere -path "$($ConfigData.AllNodes.source)\ssms-setup-enu.exe" -Destination "RemoteDrive:\Temp" -ErrorAction Stop


}
Catch {
    $ExceptionMessage = $_.Exception.Message
    $ExceptionType = $_.Exception.GetType().Fullname
    Throw "Build-NewLABSQL : Error Copying DSC Resources.`n`n     $ExceptionMessage`n`n $ExceptionType"
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

## ----- Create SQL Account on AD
## ----- create accounts for SQL
#Write-Verbose "Checking AD for Accounts"
#
#write-Verbose "DomainName = $($ConfigData.AllNodes.DomainName)"
#
#$OU = $ConfigData.AllNodes.OU
#
#Invoke-Command -ComputerName $ConfigData.AllNodes.DomainName -Credential $DomainAdmin -ScriptBlock {
#    $VerbosePreference = $Using:VerbosePreference
#    $SQLSVC = $Using:SQLSvcAccount
#
#    $U = Get-ADUser -Identity ($SQLSvc.UserName.split('\\'))[1] -ErrorAction Ignore
#
#    Write-Verbose "User = $($U | out-string )"
#
#    if ( $U ) {
#        Write-Verbose "$($SQLSvc.Username) already exists"
#    }
#    Else {
#        Write-Verbose "Creating $($SQLSvc.Username)"
#
#        New-ADUser -Name ($SQLSvc.UserName.Split('\\'))[1] -Path $Using:OU -AccountPassword $SQLSvc.Password -Enabled $true
#    }
#
#}

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
        Invoke-VMScript -VM $VM -GuestCredential $LocalAdmin -ScriptText $CMD 
        $DSCSuccess = $True
    }
    Catch {
        Write-Warning "Problem running DSC.  Pausing and then will retry"
        $DSCSuccess = $False
        $Trys++

        Write-Verbose "Retrying ..."
    }
} While ( (-Not $DSCSuccess) -and ($Trys -lt $Timeout) )

Write-verbose "wait and then reboot"
Start-Sleep -Seconds 900

Restart-VM -VM $VM -Confirm:$False

# ----- Clean up
Remove-PSDrive -Name RemoteDrive
