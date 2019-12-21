#Connect-VIServer -Server 192.168.1.16 -Credential (Get-Credential)

# ----- Load the Config Data
. $PSScriptRoot\Config_firstDC.PS1

# ----- Build the Config MOF
NewDomain -ConfigurationData $ConfigData `
    -safemodeAdministratorCred (Get-Credential -UserName '(Password Only)' -Message "New Domain Safe Mode Administrator Password") `
    -domainCred (Get-Credential -UserName $DomainName\administrator -Message "New Domain Admin Credential") `
    -OutputPath $PSScriptRoot\MOF -

# ----- Create the VM.  In this case we are building from a VM Template.  But this could be modified to be from an ISO.
#$VM = New-VM -Name $ConfigData.AllNodes.NodeName -Template $ConfigData.AllNodes.VMTemplate -vmhost $ESXHost

#Start-VM -VM $VM

# ----- reget the VM info.
$VM = Get-VM -Name $Configdata.AllNodes.NodeName

# ----- So my environment doesn't want to give me the IP.  THis is supposed to be it but it is blank for this VM.  
# $IPAddress = $VM.Guest.IpAddress
$IPAddress = '192.168.1.167'

# ----- Push Config MOF to computer
Start-DscConfiguration -ComputerName $IPAddress -Path "$PSScriptRoot\mof" -Wait -Verbose

