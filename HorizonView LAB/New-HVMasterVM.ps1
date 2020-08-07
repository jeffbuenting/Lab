﻿# -------------------------------------------------------------------------------------
# Creates a new master image optimized for VDI
#--------------------------------------------------------------------------------------

param (
    [Parameter (Mandatory=$True)]
    [String]$VMName,

    [int]$Timeout = '900'
)


# ----- Dot source configs and DSC scripts
Write-Verbose "Dot sourcing scripts"

# ----- Load the Config Data
. $PSScriptRoot\DSCConfigs\Config_ViewMasterVM.ps1

Try {
    # ----- Create the VM. 

    New-LABVM -VMName $ConfigData.AllNodes.NodeName `
        -ESXHost $ConfigData.AllNodes.ESXHost `
        -ISO $ConfigData.AllNodes.ISO `
        -ResourcePool $ConfigData.AllNodes.ResourcePool `
        -VMSwitch $ConfigData.AllNodes.Switch `
        -PortGroup $ConfigData.AllNodes.Portgroup `
        -CPU 4 `
        -Memory 4 `
        -Timeout $Timeout `
        -ErrorAction Stop `
        -Verbose
}
Catch {
    $ExceptionMessage = $_.Exception.Message
    $ExceptionType = $_.Exception.GetType().Fullname
    Throw "Problem creating the VM.`n`n     $ExceptionMessage`n`n $ExceptionType"
}