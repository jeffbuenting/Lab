Function Config-LabVM {

<#
    .SYNOPSIS
        Create and COnfigure VM for my lab
#>

    [CmdletBinding()]
    Param (
         # ----- DSC Mofs
        [Parameter (Mandatory = $True) ]
        [String]$DSCConfig,

        [Parameter (Mandatory = $True) ]
        [String]$DSCVMScript,
        
        [Parameter (Mandatory = $True) ]
        [String]$LCMConfig,

        [Parameter (Mandatory = $True) ]
        [PSCredential]$LocalAdmin,

        [Parameter (Mandatory = $True) ]
        [String]$MOFPath,
        
        [Parameter (Mandatory = $True) ]
        [String]$DSCModulePath,
        
        [Parameter (Mandatory = $True) ]
        [String[]]$DSCResource,

        [int]$Timeout = '900'
    )

    Try {
        # ----- Dot source configs and DSC scripts
        Write-Verbose "Dot sourcing scripts"

        # ----- Load the Config Data
        Write-Verbose $DSCConfig
        . $DSCConfig

        # ----- Create the Config
        Write-Verbose $DSCVMScript
        . $DSCVMScript

        # ----- Dot source LCM config (same for all scripts)
        Write-Verbose $LCMConfig
        . $LCMConfig
    }
    Catch {
        $ExceptionMessage = $_.Exception.Message
        $ExceptionType = $_.Exception.GetType().Fullname
        Throw "Config-LabVM : Error dot sourcing DSC files.`n`n     $ExceptionMessage`n`n $ExceptionType"
    }


    # ----- Build the MOF files for both the LCM and DSC script
    # ----- Build the Config MOF
    Write-Verbose "Building DSC MOF"
    if ( -Not (Test-Path $MofPath) ) { New-Item -ItemType Directory -Path $MOFPath }

    # ----- Extract File Name from path
    $FileName = Get-Item $DSCVMScript | Select-Object -ExpandProperty BaseName

    try {
        Write-Verbose "LCM Mof"
        LCMConfig -OutputPath $MOFPath -ErrorAction Stop

        Write-Verbose "$Filename MOF"
        & $FileName -ConfigurationData $ConfigData `
            -OutputPath $MOFPath `
            -ErrorAction Stop
    }
    Catch {
        $ExceptionMessage = $_.Exception.Message
        $ExceptionType = $_.Exception.GetType().Fullname
        Throw "Config-LabVM : There was a problem building the MOF.`n`n     $ExceptionMessage`n`n $ExceptionType"
    }

    Try {
    # ----- Create the VM. 

    New-LABVM -VMName $ConfigData.AllNodes.NodeName `
        -ESXHost $ConfigData.AllNodes.ESXHost `
        -Template $ConfigData.AllNodes.VMTemplate `
        -ResourcePool $ConfigData.AllNodes.ResourcePool `
        -Location $ConfigData.AllNodes.VMFolder `
        -OSCustomization $ConfigData.AllNodes.OSCustomization `
        -VMSwitch $ConfigData.AllNodes.Switch `
        -PortGroup $ConfigData.AllNodes.Portgroup `
        -LocalAdmin $LocalAdmin `
        -CPU $ConfigData.AllNodes.CPU `
        -Memory $ConfigData.AllNodes.MemoryGB `
        -Timeout $Timeout `
        -ErrorAction Stop `
        -Verbose
    }
    Catch {
        $ExceptionMessage = $_.Exception.Message
        $ExceptionType = $_.Exception.GetType().Fullname
        Throw "Config-LabVM : Problem creating the VM.`n`n     $ExceptionMessage`n`n $ExceptionType"
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

    # ---- Baked this into the template as I couldn't figure out how to run as admin remotely
    # ----- Sometime there is a problem mapping because of this article https://helgeklein.com/blog/2011/08/access-denied-trying-to-connect-to-administrative-shares-on-windows-7/
    # ----- it says win 7 but this was the problem I had in testing an the registry value fixed.
#    $Reg = @"
#        `$remotecmd = @'
#            if ( (Get-ItemProperty -Path HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System\LocalAccountTokenFilterPolicy -ErrorAction SilentlyContinue) -ne 1 ) {
#                Write-Output 'Regitry value LocalAccountTokenFilterPolicy not set correctly'
# 
#                New-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" -Name "LocalAccountTokenFilterPolicy" -Value 1
#            }
#            Else {
#                Write-Output 'Regitry value LocalAccountTokenFilterPolicy is set correctly'
#            }
#'@
#
#        `$Arg = """-Command $RemoteCmd"""
#
#        Start-Process powershell.exe -Verb runAs -ArgumentList `$Arg 
#"@
#    
#    Invoke-VMScript -vm $VM -GuestCredential $LocalAdmin -ScriptText $Reg -ErrorAction Stop
#
#    Restart-VM -VM $VM -Confirm:$False | Wait-Tools
    
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

    # ----- So this requires to run as admin.  haven't figured how to do that via invoke-VMscript so this must be added to the Template.
#    Try {
#    # ----- in order to map to the remote admin share we must open the firewall 
#        $FW = @"
#            if ( -Not (Get-NetFirewallRule -DisplayName "File And Printer Sharing").Enabled) {
#                Write-Output 'Enabling File and Print sharing'
#
#                Set-NetFirewallRule -DisplayGroup "File And Printer Sharing" -Enabled False -Profile An
#            }
#            Else {
#                Write-Output "File and Print sharing already enabled"
#            }
#"@
#        Invoke-VMScript -vm $VM -GuestCredential $LocalAdmin -ScriptText $FW -ErrorAction Stop
#    }
#    Catch {
#        $ExceptionMessage = $_.Exception.Message
#        $ExceptionType = $_.Exception.GetType().Fullname
#        Throw "Config-LabVM : Error setting Firewall.  It is possible the Local Admin credentials are wrong.`n`n     $ExceptionMessage`n`n $ExceptionType"
#    }

    # ----- The MOF files were created with the new VMs name.  we need to copy it to the server and change the name to Localhost to run locally
    Try {
        Write-Verbose "Checking if Temp directory exists"

        $CMD = "if ( -Not (Test-Path ""c:\temp"") ) { New-Item -ItemType Directory -Path ""c:\temp"" }"
        Invoke-VMScript -vm $VM -GuestCredential $LocalAdmin -ScriptText $CMD -ErrorAction Stop
    }
    Catch {
        $ExceptionMessage = $_.Exception.Message
        $ExceptionType = $_.Exception.GetType().Fullname
        Throw "Config-LabVM : Error creating c:\temp on remote VM.  It is possible the Local Admin credentials are wrong.`n`n     $ExceptionMessage`n`n $ExceptionType"
    }

    # ----- We need to copy some files to the VM.
    # ----- Remove the drive if it exists
    Write-Verbose "Mapping RemoteDrive to \\$IPAddress\c$"
    if ( Get-PSDrive -Name RemoteDrive -ErrorAction SilentlyContinue ) { Remove-PSDrive -Name RemoteDrive }

    Try {
        New-PSDrive -Name RemoteDrive -PSProvider FileSystem -Root "\\$IPAddress\c$" -Credential $LocalAdmin -ErrorAction stop
    }
    Catch {
        $ExceptionMessage = $_.Exception.Message
        $ExceptionType = $_.Exception.GetType().Fullname
        Throw "Config-LabVM : Map Drive failed.`n`n     $ExceptionMessage`n`n $ExceptionType"
    }

    # ----- Copy LCM Config and run on remote system
    Write-Verbose "Configuring LCM on VM"
    Copy-Item -Path $MOFPath\LCMConfig.meta.mof -Destination RemoteDrive:\temp\localhost.meta.mof

    Invoke-VMScript -VM $VM -GuestCredential $LocalAdmin  -ScriptText "Set-DscLocalConfigurationManager -path c:\temp -force"

    Write-Verbose "Copying DSC resources to VM"
    Write-Verbose "Copy MOFs"
    Copy-Item -Path $MOFPath\$($Configdata.AllNodes.NodeName).mof -Destination RemoteDrive:\temp\localhost.mof

    # ----- We are not using a DSC Pull server so we need to make sure the DSC resources are on the remote computer
    Write-Verbose "Copy DSC Resources"

    foreach ( $R in $DSCResource ) {
        Copy-ItemIfNotThere -path $DSCModulePath\$R -Destination "RemoteDrive:\Program Files\WindowsPowerShell\Modules" -Recurse 
    }

    # ----- Run Config MOF on computer
    Write-Verbose "Final DSC MOF"

    Start-Sleep -Seconds 60

    $Cmd = "Start-DscConfiguration -path C:\temp -Wait -Verbose -force"

    # ----- Invoke-VMScript will error as the VM DSC config forces a reboot.
    Invoke-VMScript -VM $VM -GuestCredential $LocalAdmin -ScriptText $CMD  -ErrorAction SilentlyContinue



}