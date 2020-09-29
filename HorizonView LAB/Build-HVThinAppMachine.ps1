﻿
[CmdletBinding()]
Param (
    [Parameter (Mandatory = $True) ]
    [String]$DSCModulePath,

    [Parameter ( Mandatory = $True )]
    [PSCredential]$LocalAdmin,

    [int]$Timeout = '900'



)


$VerbosePreference = 'Continue'

$IsVerbose = $False
if ( $VerbosePreference -eq 'Continue' ) { $IsVerbose = $True }

# ----- Dot source configs and DSC scripts
Write-Verbose "Dot sourcing scripts"

# ----- Load the Config Data
. $PSScriptRoot\DSCConfigs\Config_HVThinAppMachine.ps1

. $PSScriptRoot\DSCConfigs\New-HVThinAppMachine.ps1

# ----- Dot source LCM config (same for all scripts)
. "$((Get-item -Path 'C:\Scripts\Lab\HorizonView LAB').Parent.FullName)\DSCConfigs\LCMConfig.ps1"

# ----- Build the MOF files for both the LCM and DSC script
# ----- Build the Config MOF
Write-Verbose "Building DSC MOF"
if ( -Not (Test-Path "$PSScriptRoot\MOF") ) { New-Item -ItemType Directory -Path "$PSScriptRoot\MOF" }

try {
    LCMConfig -OutputPath $PSSCriptRoot\MOF -ErrorAction Stop

    New-HVThinAppMachine -ConfigurationData $ConfigData `
        -OutputPath $PSScriptRoot\MOF `
        -ErrorAction Stop
}
Catch {
    $ExceptionMessage = $_.Exception.Message
    $ExceptionType = $_.Exception.GetType().Fullname
    Throw "Build-HVTHimAppMachine : There was a problem building the MOF.`n`n     $ExceptionMessage`n`n $ExceptionType"
}


$DSCConfig = "$PSScriptRoot\DSCConfigs\Config_HVTHimAppMachine.ps1"

Config-LabVM -ConfigData $ConfigData `
    -DSCModulePath $DSCModulePath `
    -DSCResource 'NetworkingDSC','ComputerManagementDSC' `
    -MofPath $PSScriptRoot\MOF `
    -LocalAdmin $LocalAdmin `
    -Timeout $Timeout `
    -Verbose



