<#
    .SYNOPSYS
        Creates a and configures a VDI Pool
#>

[CmdletBinding()]
Param (
    [Parameter (Mandatory = $True) ]
    [VMware.VimAutomation.ViCore.Impl.V1.VM.UniversalVirtualMachineImpl]$MasterImageVM,

    [Parameter (Mandatory = $True) ]
    [String]$DomainController,

    [Parameter (Mandatory = $True) ]
    [PSCredential]$DomainAdmin,

    [Parameter (Mandatory = $True) ]
    [String]$DomainNetBiosName,

    [Parameter (Mandatory = $True) ]
    [String]$Name,

    [Parameter (Mandatory = $True) ]
    [String]$VMFolder,

    [Parameter (Mandatory = $True) ]
    [String]$HostOrCluster,

    [String]$ResourcePool = 'Resources',

    [Parameter (Mandatory = $True) ]
    [String]$DataStore,

    [Parameter (Mandatory = $True) ]
    [String]$NameingPattern,

    [Parameter (Mandatory = $True) ]
    [String]$Min,

    [Parameter (Mandatory = $True) ]
    [String]$Max,

    [String]$Spare = 1,

    [Parameter (Mandatory = $True) ]
    [String]$PoolOSCustomization,

    [Parameter (Mandatory = $True) ]
    [String[]]$EntitledGroup


)

# ----- Create Snapshot for Pool

$SnapShot = $MasterImageVM | New-Snapshot -Name "$($MasterImageVM.Name)-$(Get-Date -Format yyyyMMMdd)"

# ----- Create AD Groups that are Entitled to use the VDI Pool
Foreach ( $E in $EntitledGroup ) {

    $Group = @"
        if ( Get-ADGroup -Name $E -ErrorAction SilentlyContinue ) {
            Write-Output "Creating Group"

            New-ADGroup -Name $E
        }
        Else {
            Write-Output "Group already exists"
        }
"@

    Invoke-VMScript -VM $DomainController -GuestCredential $DomainAdmin -ScriptText $Group
}

if ( Get-HVPool -PoolName $Name -ErrorAction SilentlyContinue ) {
    Write-Verbose "Creating Pool"

    New-HVPool -LinkedClone `
        -PoolName $Name `
        -UserAssignment FLOATING `
        -GlobalEntitlement $EntitledGroup
        -ParentVM $MasterImageVM.Name `
        -SnapshotVM $SnapShot.name `
        -VmFolder $VMFolder `
        -HostOrCluster $HostOrCluster `
        -ResourcePool $ResourcePool `
        -Datastores $DataStore `
        -NamingMethod PATTERN `
        -PoolDisplayName $Name `
        -Description $Name `
        -EnableProvisioning $True `
        -NamingPattern $NamePattern `
        -MinReady $Min `
        -MaximumCount $Max `
        -SpareCount $Spare `
        -ProvisioningTime UP_FRONT `
        -SysPrepName $PoolOSCustomization `
        -CustType QUICK_PREP `
        -NetBiosName $DomainNetbios `
        -DomainAdmin $DomainAdmin.UserName `
        -deleteOrRefreshMachineAfterLogoff DELETE `
        -RedirectWindowsProfile $false
}
Else {
    Write-Verbose "Pool already exists"
}