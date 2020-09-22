Function Import-GPOFromBackup {

    Param (
        [Parameter ( Mandatory=$True )]
        [String]$GPOName,

        [Parameter ( Mandatory = $True )]
        [String]$Path,

        [Parameter ( Mandatory = $True )]
        [String]$DomainController

    )

    $VM = Get-VM -Name $DomainController

    $IPAddress = $VM.Guest.IpAddress | Select-String -Pattern "\b(?:(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\b"

    Write-Verbose "IPAddress = $IPaddress"

    # ----- Map drive to DC c$
    # ----- Remove the drive if it exists
    Write-Verbose "Mapping RemoteDrive to \\$IPAddress\c$"
    if ( Get-PSDrive -Name RemoteDrive -ErrorAction SilentlyContinue ) { Remove-PSDrive -Name RemoteDrive }

    Try {
        Write-Verbose "Mapping Drive"
        New-PSDrive -Name RemoteDrive -PSProvider FileSystem -Root "\\$IPAddress\c$" -Credential $DomainAdmin -ErrorAction stop
    }
    Catch {
        $ExceptionMessage = $_.Exception.Message
        $ExceptionType = $_.Exception.GetType().Fullname
        Throw "Set-VDIADInfrastructure : Map Drive failed.`n`n     $ExceptionMessage`n`n $ExceptionType"
    }

    # ----- Copy the the GPO backup
    Copy-ItemIfNotThere -path $Path\$GPOName -Destination "RemoteDrive:\Temp\$GPOName" -Recurse 

    # ----- Import GPO
    Invoke-VMScript -VM $VM -ScriptText "Import-GPO -BackupGpoName $GPOName -TargetName $GPOName -path c:\temp\$GPOName -CreateIfNeeded"

}