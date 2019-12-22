﻿Connect-VIServer -Server 192.168.1.16 -Credential (Get-Credential)

$LocalAdmin = Get-Credential -UserName administrator -Message "Servers Local Admin Account"

# ----- Load the Config Data
. $PSScriptRoot\Config_New-LABDomain.PS1

# ----- Dot source New-LABDomain
. $PSScriptRoot\New-LABDomain.PS1

# ----- Build the Config MOF
New-LABDomain -ConfigurationData $ConfigData `
    -safemodeAdministratorCred (Get-Credential -UserName '(Password Only)' -Message "New Domain Safe Mode Administrator Password") `
    -domainCred (Get-Credential -UserName $DomainName\administrator -Message "New Domain Admin Credential") `
    -OutputPath $PSScriptRoot\MOF -

# ----- Create the VM.  In this case we are building from a VM Template.  But this could be modified to be from an ISO.
$VM = New-VM -Name $ConfigData.AllNodes.NodeName -Template $ConfigData.AllNodes.VMTemplate -vmhost $ConfigData.AllNodes.ESXHost

Start-VM -VM $VM

# ----- reget the VM info.
$VM = Get-VM -Name $Configdata.AllNodes.NodeName
  
$IPAddress = $VM.Guest.IpAddress[0]

# ----- The MOF files were created with the new VMs name.  we need to copy it to the server and change the name to Localhost to run locally
$CMD = "if ( -Not (Test-Path ""\\$IPAddress\c$\temp"") ) { New-Item -ItemType Directory -Path ""\\$IPAddress\c$\temp"" }"
Invoke-VMScript -vm $VM -GuestCredential $LocalAdmin -ScriptText $CMD

New-PSDrive -Name RemoteDrive -PSProvider FileSystem -Root "\\$($VM.Guest.HostName)\c$" -Credential $LocalAdmin
Copy-Item -Path $PSScriptRoot\mof\$($Configdata.AllNodes.NodeName).mof -Destination RemoteDrive:\temp\localhost.mof
COpy-Item -Path $PSScriptRoot\mof\$($Configdata.AllNodes.NodeName).meta.mof -Destination RemoteDrive:\temp\localhost.meta.mof


copy-item -path C:\Scripts\lab\MOF\KW-DC1.mof -Destination RemoteDrive:\temp\localhost.mof
copy-item -path C:\Scripts\lab\MOF\KW-DC1.meta.mof -Destination RemoteDrive:\temp\localhost.meta.mof

# ----- We are not using a DSC Pull server so we need to make sure the DSC resources are on the remote computer
copy-item -path C:\Users\600990\Documents\WindowsPowerShell\Modules\xComputerManagement -Destination "RemoteDrive:\Program Files\WindowsPowerShell\Modules" -Recurse -force

# ----- Push Config MOF to computer
#Start-DscConfiguration -ComputerName $IPAddress -Path "$PSScriptRoot\mof" -Wait -Verbose
$Cmd = "Start-DscConfiguration -path C:\temp -Wait -Verbose -force"
Invoke-VMScript -VM $VM -GuestCredential $LocalAdmin -ScriptText $CMD 



