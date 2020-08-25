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

$DSCConfig = "$PSScriptRoot\DSCConfigs\Config_ViewMasterVM.ps1"

$MasterImageVM = Config-LabVM -DSCConfig $DSCConfig `
    -DSCVMScript $PSScriptRoot\DSCConfigs\New-ViewMasterVM.ps1 `
    -LCMConfig "$((Get-item -Path 'C:\Scripts\Lab\HorizonView LAB').Parent.FullName)\DSCConfigs\LCMConfig.ps1" `
    -MOFPath "$PSScriptRoot\MOF" `
    -DSCModulePath $DSCModulePath `
    -DSCResource 'xComputerManagement','NetworkingDSC','xSystemSecurity','xtimezone' `
    -LocalAdmin $LocalAdmin `
    -Timeout 1900 `
    -Verbose


# ----- Because I want to only maintain one master image and customize via scripts during the provisioning phase for each pool these scripts need to be copied to the master image
$IPAddress = $MasterImageVM.Guest.IpAddress | Select-String -Pattern "\b(?:(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\b"

Write-Verbose "IPAddress = $IPaddress"

Try {
    Write-Verbose "Checking if Scripts directory exists"

    $CMD = "if ( -Not (Test-Path ""c:\Scripts"") ) { New-Item -ItemType Directory -Path ""c:\Scripts"" }"
    Invoke-VMScript -vm $MasterImageVM -GuestCredential $LocalAdmin -ScriptText $CMD -ErrorAction Stop
}
Catch {
    $ExceptionMessage = $_.Exception.Message
    $ExceptionType = $_.Exception.GetType().Fullname
    Throw "New-HVMasterVM : Error creating c:\temp on remote VM`n`n     $ExceptionMessage`n`n $ExceptionType"
}

# ----- Remove the drive if it exists
Write-Verbose "Mapping RemoteDrive to \\$IPAddress\c$"
if ( Get-PSDrive -Name RemoteDrive -ErrorAction SilentlyContinue ) { Remove-PSDrive -Name RemoteDrive }

Try {
    New-PSDrive -Name RemoteDrive -PSProvider FileSystem -Root "\\$IPAddress\c$" -Credential $LocalAdmin -ErrorAction stop
}
Catch {
    $ExceptionMessage = $_.Exception.Message
    $ExceptionType = $_.Exception.GetType().Fullname
    Throw "New-HVMasterVM : Map Drive failed.`n`n     $ExceptionMessage`n`n $ExceptionType"
}

Copy-Item -Path $PSScriptRoot\Function\New-VDIMapDrive.ps1 -Destination RemoteDrive:\Scripts\New-VDIMapDrive.ps1

# ----- Return some info for use in the parent
Write-Output $MasterImageVM



