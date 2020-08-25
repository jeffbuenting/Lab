<#
    .SYNOPSIS
        Configure AD for VDI

#>

[CmdletBinding()]
Param (
    [Parameter ( Mandatory = $True )]
    [String]$DomainController,

    [Parameter ( Mandatory = $True )]
    [PSCredential]$DomainAdmin
)

$VM = Get-VM -Name $DomainController


# ----- Configure Accounts needed for VDI

# ----- Configure Groups


# ----- Configure OUs for VDI

# ----- Configure GPOs
Write-Verbose "GPOs"

# ----- Because I want to only maintain one master image and customize via scripts during the provisioning phase for each pool these scripts need to be copied to the master image
$IPAddress = $VM.Guest.IpAddress | Select-String -Pattern "\b(?:(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\b"

Write-Verbose "IPAddress = $IPaddress"

Try {
    Write-Verbose "Checking if Scripts directory exists"

    $CMD = "if ( -Not (Test-Path ""c:\Scripts"") ) { New-Item -ItemType Directory -Path ""c:\Scripts"" }"
    Invoke-VMScript -vm $VM -GuestCredential $LocalAdmin -ScriptText $CMD -ErrorAction Stop
}
Catch {
    $ExceptionMessage = $_.Exception.Message
    $ExceptionType = $_.Exception.GetType().Fullname
    Throw "Set-VDIADInfrastructure : Error creating c:\temp on remote VM`n`n     $ExceptionMessage`n`n $ExceptionType"
}

# ----- Remove the drive if it exists
Write-Verbose "Mapping RemoteDrive to \\$IPAddress\c$"
if ( Get-PSDrive -Name RemoteDrive -ErrorAction SilentlyContinue ) { Remove-PSDrive -Name RemoteDrive }

Try {
    New-PSDrive -Name RemoteDrive -PSProvider FileSystem -Root "\\$IPAddress\c$" -Credential $DomainAdmin -ErrorAction stop
}
Catch {
    $ExceptionMessage = $_.Exception.Message
    $ExceptionType = $_.Exception.GetType().Fullname
    Throw "Set-VDIADInfrastructure : Map Drive failed.`n`n     $ExceptionMessage`n`n $ExceptionType"
}


# ----- GPO Logon Script
Write-Verbose "GPO Login Script"

'. c:\scripts\Set-VDIDesktops.ps1' | Set-Content -Path "RemoteDrive:\Scripts\Start-VDILogin.ps1"