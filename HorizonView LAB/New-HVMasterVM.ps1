# -------------------------------------------------------------------------------------
# Creates a new master image optimized for VDI
#--------------------------------------------------------------------------------------

param (

    # ----- DSC Mofs
    [Parameter (Mandatory = $True) ]
    [String]$DSCModulePath,

    [Parameter (Mandatory = $True) ]
    [PSCredential]$LocalAdmin,

    [int]$Timeout = '900'
)

Write-Verbose "Building MasterImage"

$MasterImage = Config-LabVM -DSCConfig $PSScriptRoot\DSCConfigs\Config_ViewMasterVM.ps1 `
    -DSCVMScript $PSScriptRoot\DSCConfigs\New-ViewMasterVM.ps1 `
    -LCMConfig "$((Get-item -Path 'C:\Scripts\Lab\HorizonView LAB').Parent.FullName)\DSCConfigs\LCMConfig.ps1" `
    -MOFPath "$PSScriptRoot\MOF" `
    -DSCModulePath $DSCModulePath `
    -DSCResource 'xComputerManagement','NetworkingDSC','xSystemSecurity','xtimezone' `
    -LocalAdmin $LocalAdmin `
    -Timeout 1900 `
    -Verbose


# ----- Return some info for use in the parent
Write-Output $MasterImage



