Try {
    if ( $global:DefaultVIServer.Name -ne $VCenterServer -or $global:DefaultVIServer.SessionID -eq $Null ) {
        Write-Output "Connecting to $VCenterServer"

        Connect-VIServer -Server 192.168.1.16 -Credential $VCenterAdmin -ErrorAction Stop
    }
    Else {
        Write-Output "Already connected to $VCenterServer"
    }
}
Catch {
    $ExceptionMessage = $_.Exception.Message
    $ExceptionType = $_.Exception.GetType().Fullname
    Throw "Error Connecting to vCenter.`n`n     $ExceptionMessage`n`n $ExceptionType"
}

$VM =get-vm kw-horconn01
stop-vm -VM $VM -Confirm:$False
Remove-VM -VM $VM -DeletePermanently -Confirm:$False