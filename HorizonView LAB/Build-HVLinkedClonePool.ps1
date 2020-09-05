<#
    .SYNOPSYS
        Creates a and configures a VDI Pool
#>

[CmdletBinding()]
Param (
    [Parameter (Mandatory = $True) ]
    [String]$DSCConfig,

    [Parameter (Mandatory = $True) ]
    [PSCredential]$DomainAdmin
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

    if ( -Not (Get-HVPool -PoolName $Node.NodeName -ErrorAction SilentlyContinue ) ) {
        Write-Verbose "Pool does not exist"

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

        Write-Verbose "Checking for AD Group : $($Node.EntitledGroup) and OU : $($Node.NodeName)Pool"

        $Group = @"
            `$OU = Get-ADOrganizationalUnit -Filter { Name -eq '$($Node.NodeName)Pool'} -ErrorAction SilentlyContinue
            if ( -Not ( `$OU ) ) { 
                Write-Output "Creating OU"

                New-ADOrganizationalUnit -Name $($Node.NodeName)Pool -Path '$($Node.PoolParentOU)'
            }
            Else {
                Write-Output "OU already Exists"
            }

            `$GN = '$(($Node.EntitledGroup -split '\\')[1])'
            `$G = Get-ADGroup -Identity `$GN -ErrorAction SilentlyContinue
            if ( -not ( `$G ) ) {
                Write-Output "Creating Group"

                New-ADGroup -Name `$GN -GroupScope DomainLocal
            }
            Else {
                Write-Output "Group already exists"
            }
"@

            $Result = Invoke-VMScript -VM $NOde.DomainController -GuestCredential $DomainAdmin -ScriptText $Group

            Write-Verbose $Result
        #}


        # ----- Create Folder for Linked Clones
        if ( -Not ( Get-Folder -Name $Node.PoolVMFolder ) ) {
            Write-Verbose Creating Folder

            New-Folder -Name $Node.PoolVMFolder 

        }
        Else {
            Write-Verbose "Folder Already Exists"
        }

        if ( $Node.ResourcePool -eq 'Resources' ) {
            Write-Verbose 'Default Pool'

            $Node.ResourcePool = $Node.ESXHost
        }

        Write-Verbose "Creating Pool"

        New-HVPool -LinkedClone `
            -PoolName $Node.NodeName `
            -UserAssignment FLOATING `
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
            -CustType   QUICK_PREP `
            -NetBiosName $Node.DomainNetBiosName `
            -DomainAdmin $DomainAdmin.UserName `
            -AdContainer $Node.PoolContainer `
            -enableHTMLAccess $True `
            -deleteOrRefreshMachineAfterLogoff DELETE `
            -RedirectWindowsProfile $false

        New-HVEntitlement -ResourceName $Node.Nodename -User $Node.EntitledGroup -Type Group

    }
    Else {
        Write-Verbose "Pool already exists"
    }
}

