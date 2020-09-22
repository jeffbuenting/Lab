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

