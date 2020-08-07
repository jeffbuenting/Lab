# -------------------------------------------------------------------------------------
# Creates a new master image optimized for VDI
#--------------------------------------------------------------------------------------

param (
 #   [Parameter (Mandatory=$True)]
 #   [String]$VMName,

    [int]$Timeout = '900'
)



Config-LabVM -DSCConfig $PSScriptRoot\DSCConfigs\Config_ViewMasterVM.ps1 `
    -DSCScript . $PSScriptRoot\DSCConfigs\New-ViewMasterVM.ps1 `
    -LCMConfig . "$((Get-item -Path 'C:\Scripts\Lab\HorizonView LAB').Parent.FullName)\DSCConfigs\LCMConfig.ps1" `
    -MOFPath "$PSScriptRoot\MOF" `
    -LocalAdmin $LocalAdmin `
    -DSCModulePath $DSCModulePath `
    -DSCResource $DSCResource `
    -Verbose








