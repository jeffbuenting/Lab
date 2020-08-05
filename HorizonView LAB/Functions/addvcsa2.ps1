$CMD = @"
    if ( -Not ( Get-Module -Name vmware.powercli -ListAvailable ) ) {
        write-output "installing powercli"

        Install-PackageProvider -Name NuGet -force
        Install-module -Name Vmware.Powercli -force
    }
    Else {
        Write-Output "PowerCLI already installed"
    }
"@

$Result = Invoke-VMScript -VM $VM -GuestCredential $LocalAdmin -ScriptText $CMD

$result.ScriptOutput

$VM = get-vm kw-horconn01
#. c:\program files\vmware\view\server\extras\powershell\add-snapin.ps1  

$VCSAServer = '192.168.1.16'

$SetVCSA = @"
    . 'C:\Program Files\VMware\VMware View\Server\extras\PowerShell\add-snapin.ps1'

    if ( -not (Get-ViewVC -ServerName $VCSAServer -ErrorAction SilentlyContinue) ) {
        Write-Output "Configuring vCenter Server"

        Set-PowerCLIConfiguration -InvalidCertificateAction Ignore -Confirm:$false
        Add-ViewVC -ServerName $VCSAServer -username $($VCSAViewUser.UserName) -password $($VCSAViewUser.GetNetworkCredential().Password) -createRampFactor 5 -deleteRampFactor 5

    }
    Else {
        Write-Output "vCenter server already configured"
    }
"@

$Result = Invoke-VMScript -VM $VM -GuestCredential $LocalAdmin -ScriptText $SetVCSA

$result.ScriptOutput