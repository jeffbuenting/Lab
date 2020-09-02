# -------------------------------------------------------------------------------------
# Creates a new master image optimized for VDI
#--------------------------------------------------------------------------------------

param (

    # ----- DSC Mofs
    [Parameter (Mandatory = $True) ]
    [String]$DSCModulePath,

    [Parameter (Mandatory = $True) ]
    [PSCredential]$LocalAdmin,

    [Parameter (Mandatory = $True) ]
    [PSCredential]$ShareDriveCred,

    [int]$Timeout = '900'
)

$MOFPath = "$PSScriptRoot\MOF"

Try {
    # ----- Dot source configs and DSC scripts
    Write-Verbose "Dot sourcing scripts"

    # ----- Load the Config Data
    . "$PSScriptRoot\DSCConfigs\Config_ViewMasterVM.ps1"

    # ----- Create the Config
    . "$PSScriptRoot\DSCConfigs\New-ViewMasterVM.ps1"

    # ----- Dot source LCM config (same for all scripts)
    . "$((Get-item -Path 'C:\Scripts\Lab\HorizonView LAB').Parent.FullName)\DSCConfigs\LCMConfig.ps1" `
}
Catch {
    $ExceptionMessage = $_.Exception.Message
    $ExceptionType = $_.Exception.GetType().Fullname
    Throw "NEw-HVMasterVM : Error dot sourcing DSC files.`n`n     $ExceptionMessage`n`n $ExceptionType"
}


# ----- Build the MOF files for both the LCM and DSC script
# ----- Build the Config MOF
Write-Verbose "Building DSC MOF"
if ( -Not (Test-Path $MofPath) ) { New-Item -ItemType Directory -Path $MOFPath | Out-Null }

try {
    Write-Verbose "LCM Mof"
    LCMConfig -OutputPath $MOFPath -ErrorAction Stop | write-Verbose

    Write-Verbose "$Filename MOF"
    New-ViewMasterVM -ConfigurationData $ConfigData `
        -LocalAdmin $LocalAdmin `
        -SharedriveCred $ShareDriveCred `
        -OutputPath $MOFPath `
        -ErrorAction Stop | Write-Verbose
}
Catch {
    $ExceptionMessage = $_.Exception.Message
    $ExceptionType = $_.Exception.GetType().Fullname
    Throw "NEw-HVMasterVM : There was a problem building the MOF.`n`n     $ExceptionMessage`n`n $ExceptionType"
}


Write-Verbose "Building MasterImage"

$DSCConfig = "$PSScriptRoot\DSCConfigs\Config_ViewMasterVM.ps1"

$MasterImageVM = Config-LabVM -ConfigData $ConfigData `
    -DSCModulePath $DSCModulePath `
    -DSCResource 'NetworkingDSC','ComputerManagementDSC' `
    -LocalAdmin $LocalAdmin `
    -Timeout 1900 `
    -Verbose


## ----- Because I want to only maintain one master image and customize via scripts during the provisioning phase for each pool these scripts need to be copied to the master image
#$IPAddress = $MasterImageVM.Guest.IpAddress | Select-String -Pattern "\b(?:(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\b"
#
#Write-Verbose "IPAddress = $IPaddress"
#
#Try {
#    Write-Verbose "Set execution policy"
#
#    Invoke-VMScript -vm $MasterImageVM -GuestCredential $LocalAdmin -ScriptText "Set-ExecutionPolicy -ExecutionPolicy Unrestricted" -ErrorAction Stop
#}
#Catch {
#    $ExceptionMessage = $_.Exception.Message
#    $ExceptionType = $_.Exception.GetType().Fullname
#    Throw "New-HVMasterVM : Problem setting execution policy`n`n     $ExceptionMessage`n`n $ExceptionType"
#}

#Try {
#    Write-Verbose "Checking if Scripts directory exists"
#
#    $CMD = "if ( -Not (Test-Path ""c:\Scripts"") ) { New-Item -ItemType Directory -Path ""c:\Scripts"" }"
#    Invoke-VMScript -vm $MasterImageVM -GuestCredential $LocalAdmin -ScriptText $CMD -ErrorAction Stop
#}
#Catch {
#    $ExceptionMessage = $_.Exception.Message
#    $ExceptionType = $_.Exception.GetType().Fullname
#    Throw "New-HVMasterVM : Error creating c:\temp on remote VM`n`n     $ExceptionMessage`n`n $ExceptionType"
#}

## ----- Remove the drive if it exists
#Write-Verbose "Mapping RemoteDrive to \\$IPAddress\c$"
#if ( Get-PSDrive -Name RemoteDrive -ErrorAction SilentlyContinue ) { Remove-PSDrive -Name RemoteDrive }
#
#Try {
#    New-PSDrive -Name RemoteDrive -PSProvider FileSystem -Root "\\$IPAddress\c$" -Credential $LocalAdmin -ErrorAction stop
#}
#Catch {
#    $ExceptionMessage = $_.Exception.Message
#    $ExceptionType = $_.Exception.GetType().Fullname
#    Throw "New-HVMasterVM : Map Drive failed.`n`n     $ExceptionMessage`n`n $ExceptionType"
#}
#
#Copy-Item -Path $PSScriptRoot\Function\New-VDIMapDrive.ps1 -Destination RemoteDrive:\Scripts\New-VDIMapDrive.ps1

# ----- Return some info for use in the parent
Write-Output $MasterImageVM



