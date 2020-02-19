# ----- Configure AD OU etc for VMWare Horizon View.  

# ----- NOTE : May need to remove and readd Horizon servers to domain when domain is rebuilt

[CmdletBinding()]
Param (
    [PSCredential]$DomainAdmin,

    [String]$ADServer
)


# ----- Create OU for Remote Desktops
Write-Verbose "Create OUs for VDI"
Get-ADOrganizationalUnit -Server $ADServer -Credential $DomainAdmin




#New-ADOrganizationalUnit -Server $ADServer -Credential $DamainAdmin -Name RemoteDesktops