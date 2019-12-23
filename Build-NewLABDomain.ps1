<#
    .SYNOPSIS
        Script to create and Configure LAB forrest.

    .DESCRIPTION
        I got tired of rebuilding the lab everytime the trial versions expired.  So using the IaaS model this code will deploy and configure using DSC the first DC in a forrest.

    .Links
        DSC AD Forrest

        https://blogs.technet.microsoft.com/ashleymcglone/2015/03/20/deploy-active-directory-with-powershell-dsc-a-k-a-dsc-promo/

    .Links
        DSC Computername and IP

        https://pleasework.robbievance.net/howto-desired-state-configuration-dsc-overview/
#>

Try {
    Connect-VIServer -Server 192.168.1.16 -Credential (Get-Credential -Message "vCenter Account" ) -ErrorAction Stop
}
Catch {
    $ExceptionMessage = $_.Exception.Message
    $ExceptionType = $_.Exception.GetType().Fullname
    Throw "Build-NewLABDomain : Error Connecting to vCenter.`n`n     $ExceptionMessage`n`n $ExceptionType"
}

$LocalAdmin = Get-Credential -UserName administrator -Message "Servers Local Admin Account"

# ----- Load the Config Data
. $PSScriptRoot\DSCConfigs\Config_New-LABDomain.PS1

# ----- Dot source New-LABDomain
. $PSScriptRoot\DSCConfigs\New-LABDomain.PS1

# ----- Build the Config MOF
try {
    New-LABDomain -ConfigurationData $ConfigData `
        -safemodeAdministratorCred (Get-Credential -UserName '(Password Only)' -Message "New Domain Safe Mode Administrator Password") `
        -domainCred (Get-Credential -UserName "$($ConfigData.AllNodes.DomainName)\administrator" -Message "New Domain Admin Credential") `
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
    Write-Output "Creating VM"
    $VM = New-VM -Name $ConfigData.AllNodes.NodeName -Template $ConfigData.AllNodes.VMTemplate -vmhost $ConfigData.AllNodes.ESXHost -ErrorAction Stop

    Start-VM -VM $VM -ErrorAction Stop | Wait-Tools

    # ----- reget the VM info.  passing the info via the start-vm cmd is not working it would seem.
    $VM = Get-VM -Name $Configdata.AllNodes.NodeName -ErrorAction Stop

    # ----- Sometimes the VM hostname does not get filled in.  Waiting for a bit and trying again.
    while ( -Not $VM.Guest.HostName ) {
        Write-output "Pausing 15 Seconds..."
        Sleep -Seconds 15

        $VM = Get-VM -Name $Configdata.AllNodes.NodeName -ErrorAction Stop
    }
}
Catch {
    $ExceptionMessage = $_.Exception.Message
    $ExceptionType = $_.Exception.GetType().Fullname
    Throw "Build-NewLABDomain : Error building the VM.`n`n     $ExceptionMessage`n`n $ExceptionType"
}
  
$IPAddress = $VM.Guest.IpAddress[0]

Write-Output "Checking if Temp directory exists"
# ----- The MOF files were created with the new VMs name.  we need to copy it to the server and change the name to Localhost to run locally
$CMD = "if ( -Not (Test-Path ""\\$IPAddress\c$\temp"") ) { New-Item -ItemType Directory -Path ""\\$IPAddress\c$\temp"" }"
Invoke-VMScript -vm $VM -GuestCredential $LocalAdmin -ScriptText $CMD

Write-Output "Copying DSC resources to VM"
# ----- Remove the drive if it exists
if ( Get-PSDrive -Name RemoteDrive ) { Remove-PSDrive -Name RemoteDrive }

New-PSDrive -Name RemoteDrive -PSProvider FileSystem -Root "\\$($VM.Guest.HostName)\c$" -Credential $LocalAdmin

Write-Output "Copy MOFs"
Copy-Item -Path $PSScriptRoot\mof\$($Configdata.AllNodes.NodeName).mof -Destination RemoteDrive:\temp\localhost.mof
COpy-Item -Path $PSScriptRoot\mof\$($Configdata.AllNodes.NodeName).meta.mof -Destination RemoteDrive:\temp\localhost.meta.mof


#copy-item -path C:\Scripts\lab\MOF\KW-DC1.mof -Destination RemoteDrive:\temp\localhost.mof
#copy-item -path C:\Scripts\lab\MOF\KW-DC1.meta.mof -Destination RemoteDrive:\temp\localhost.meta.mof

# ----- We are not using a DSC Pull server so we need to make sure the DSC resources are on the remote computer
Write-Output "Copy DSC Resources"
copy-item -path C:\Users\600990\Documents\WindowsPowerShell\Modules\xComputerManagement -Destination "RemoteDrive:\Program Files\WindowsPowerShell\Modules" -Recurse -force
Copy-Item -path C:\users\600990\Documents\WindowsPowerShell\Modules\xActiveDirectory -Destination "RemoteDrive:\Program Files\WindowsPowerShell\Modules" -Recurse -force

# ----- Pausing as running the script too soon fails.
Start-Sleep -Seconds 30

# ----- Run Config MOF on computer
$Cmd = "Start-DscConfiguration -path C:\temp -Wait -Verbose -force"
Invoke-VMScript -VM $VM -GuestCredential $LocalAdmin -ScriptText $CMD 

# ----- Clean up
Remove-PSDrive -Name RemoteDrive
