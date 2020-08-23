<#
    .SYNOPSYS
        Creates a and configures a VDI Pool
#>

[CmdletBinding()]
Param (
    [Parameter (Mandatory = $True) ]
    [String]$DSCConfig
)

Try {
        # ----- Dot source configs and DSC scripts
        Write-Verbose "Dot sourcing scripts"

        # ----- Load the Config Data
        Write-Verbose $DSCConfig
        . $DSCConfig

    }
    Catch {
        $ExceptionMessage = $_.Exception.Message
        $ExceptionType = $_.Exception.GetType().Fullname
        Throw "Config-LabVM : Error dot sourcing DSC files.`n`n     $ExceptionMessage`n`n $ExceptionType"
    }

Foreach ( $Node in $ConfigData.AllNodes | where Role -eq 'HVPool' ) {
    Write-Verbose "Configuring Pool $($Node.Nodename)"

    # ----- Create Snapshot for Pool
    Try { 
        $MasterImageVM = Get-VM -Name $Node.MasterImage -ErrorAction Stop

        $SnapShot = $MasterImageVM | New-Snapshot -Name "$($MasterImageVM.Name)-$(Get-Date -Format yyyyMMMdd-HHmm)"
    }
    Catch {
        $ExceptionMessage = $_.Exception.Message
        $ExceptionType = $_.Exception.GetType().Fullname
        Throw "Build-HVLinkedClonePoole : Problem creating Master Image Snapshot.`n`n     $ExceptionMessage`n`n $ExceptionType"
    }

    # ----- Create AD Groups that are Entitled to use the VDI Pool
    #Foreach ( $E in $EntitledGroup ) {

        $Group = @"
            if ( Get-ADGroup -Identity $($Node.EntitledGroup) -ErrorAction SilentlyContinue ) {
                Write-Output "Creating Group"

                New-ADGroup -Name $($Node.EntitledGroup)
            }
            Else {
                Write-Output "Group already exists"
            }
"@

        Invoke-VMScript -VM $NOde.DomainController -GuestCredential $DomainAdmin -ScriptText $Group
    #}


    # ----- Create Folder for Linked Clones
    if ( -Not ( Get-Folder -Name $Node.PoolVMFolder ) ) {
        Write-Verbose Creating Folder

        New-Folder -Name $Node.PoolVMFolder -Location VDI

    }
    Else {
        Write-Verbose "Folder Already Exists"
    }

    if ( $Node.ResourcePool -eq 'Resources' ) {
        Write-Verbose 'Default Pool'

        $Node.ResourcePool = $Node.ESXHost
    }

    Write-Verbose "Checking if Pool exists : $($Node.PoolName)"

    if ( -Not (Get-HVPool -PoolName $Node.PoolName -ErrorAction SilentlyContinue ) ) {
        Write-Verbose "Creating Pool"

        New-HVPool -LinkedClone `
            -PoolName $Node.PoolName `
            -UserAssignment FLOATING `
            -GlobalEntitlement $Node.EntitledGroup `
            -ParentVM $MasterImageVM.Name `
            -SnapshotVM $SnapShot.name `
            -VmFolder $Node.PoolVMFolder `
            -HostOrCluster $Node.ESXHost `
            -ResourcePool $Node.ResourcePool `
            -Datastores $Node.PoolDataStore `
            -NamingMethod PATTERN `
            -PoolDisplayName $Node.PoolName `
            -EnableProvisioning $True `
            -NamingPattern $Node.PoolNamePattern `
            -MinReady $Node.PoolMin `
            -MaximumCount $Node.PoolMax `
            -SpareCount $Node.PoolSpare `
            -ProvisioningTime UP_FRONT `
            -SysPrepName $Node.PoolOSCustomization `
            -CustType QUICK_PREP `
            -NetBiosName $Node.DomainNetBiosName `
            -DomainAdmin $DomainAdmin.UserName `
            -AdContainer $Node.PoolContainer `
            -enableHTMLAccess `
            -deleteOrRefreshMachineAfterLogoff DELETE `
            -RedirectWindowsProfile $false
    }
    Else {
        Write-Verbose "Pool already exists"
    }
}

