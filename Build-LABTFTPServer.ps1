

[CmdletBinding()]
Param (
    [PSCredential]$LocalAdmin = (Get-Credential -UserName administrator -Message "Servers Local Admin Account"),

    [PSCredential]$VCenterAdmin = (Get-Credential -Message "vCenter Account" )
    )


# ----- Dot source configs and DSC scripts
Write-Verbose "Dot sourcing scripts"

# ----- Load the Config Data
. $PSScriptRoot\DSCConfigs\Config_New-LABTFTP.PS1

# ----- Dot source New-LABDomain
. $PSScriptRoot\DSCConfigs\New-LABTFTPServer.PS1

# ----- Dot source LCM config
. $PSScriptRoot\DSCConfigs\LCMConfig.ps1

# ----- Build the MOF files for both the LCM and DSC script
# ----- Build the Config MOF
try {
    LCMConfig -OutputPath C:\Scripts\Lab\MOF -ErrorAction Stop

    New-LABTFTPServer -ConfigurationData $ConfigData `
        -OutputPath $PSScriptRoot\MOF `
        -ErrorAction Stop
}
Catch {
    $ExceptionMessage = $_.Exception.Message
    $ExceptionType = $_.Exception.GetType().Fullname
    Throw "Add-LABDHCP : There was a problem building the MOF.`n`n     $ExceptionMessage`n`n $ExceptionType"
}



# ----- Connect to vCenter service so we can deal with the VM
Try {
    Connect-VIServer -Server 192.168.1.16 -Credential $VCenterAdmin -ErrorAction Stop
}
Catch {
    $ExceptionMessage = $_.Exception.Message
    $ExceptionType = $_.Exception.GetType().Fullname
    Throw "Add-LABDHCP : Error Connecting to vCenter.`n`n     $ExceptionMessage`n`n $ExceptionType"
}

Try {
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

    if ( $Trys -eq $Timeout ) { Throw "Build-NewLABDomain : TimeOut getting VM info" }

}
Catch {
    $ExceptionMessage = $_.Exception.Message
    $ExceptionType = $_.Exception.GetType().Fullname
    Throw "Add-LABDHCP : Error getting VM info.`n`n     $ExceptionMessage`n`n $ExceptionType"
}
  
$IPAddress = $VM.Guest.IpAddress[0]

Write-Verbose "Checking if Temp directory exists"
# ----- The MOF files were created with the new VMs name.  we need to copy it to the server and change the name to Localhost to run locally
$CMD = "if ( -Not (Test-Path ""\\$IPAddress\c$\temp"") ) { New-Item -ItemType Directory -Path ""\\$IPAddress\c$\temp"" }"
Invoke-VMScript -vm $VM -GuestCredential $LocalAdmin -ScriptText $CMD


# ----- Remove the drive if it exists
Write-Verbose "Mapping drive to root of c on $($VM.Guest.HostName)"
if ( Get-PSDrive -Name RemoteDrive -ErrorAction SilentlyContinue ) { Remove-PSDrive -Name RemoteDrive }

Try {
    New-PSDrive -Name RemoteDrive -PSProvider FileSystem -Root "\\$IPAddress\c$" -Credential $LocalAdmin -ErrorAction Stop
   }
Catch {
    $ExceptionMessage = $_.Exception.Message
    $ExceptionType = $_.Exception.GetType().Fullname
    Throw "Add-LABDHCP : mapping to root.`n`n     $ExceptionMessage`n`n $ExceptionType"
}

# ----- Copy LCM Config and run on remote system
Write-Verbose "Configuring LCM"
Copy-Item -Path $PSScriptRoot\mof\LCMConfig.meta.mof -Destination RemoteDrive:\temp\localhost.meta.mof -Force

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
Copy-Item -Path $PSScriptRoot\mof\$($Configdata.AllNodes.NodeName).mof -Destination RemoteDrive:\temp\localhost.mof -Force

# ----- Copy install file.  normally you could use DSC for this, but I am having credential issues with my work laptop
COpy-Item -Path $PSScriptRoot\tftp\TFTPInstaller.msi -Destination RemoteDrive:\temp\TFTPInstaller.msi -Force


# ----- Run Config MOF on computer
$DSCSuccess = $False
$Trys = 0
Do {
    Try {
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
