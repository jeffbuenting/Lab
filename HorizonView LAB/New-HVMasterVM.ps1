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

# ----- Install Horizon Agent on Master Image
# ----- We need the config data 
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


$IPAddress = $MasterImageVM.Guest.IPAddress[0]

# ----- We need to copy some files to the VM.
# ----- Remove the drive if it exists
Write-Verbose "Mapping RemoteDrive to \\$IPAddress\c$"
if ( Get-PSDrive -Name RemoteDrive -ErrorAction SilentlyContinue | out-Null ) { Remove-PSDrive -Name RemoteDrive | out-Null }

Try {
    New-PSDrive -Name RemoteDrive -PSProvider FileSystem -Root "\\$IPAddress\c$" -Credential $LocalAdmin -ErrorAction stop | Write-Verbose
}
Catch {
    $ExceptionMessage = $_.Exception.Message
    $ExceptionType = $_.Exception.GetType().Fullname
    Throw "Config-LabVM : Map Drive failed.`n`n     $ExceptionMessage`n`n $ExceptionType"
}

Copy-ItemIfNotThere -Path $ConfigData.AllNodes.HorizonAgent -Destination "RemoteDrive:\temp"

$FileName = (Get-Item -Path $ConfigData.AllNodes.HorizonAgent)

Write-Verbose "Start VM if need be"
$MasterImageVM = Get-VM -Name $MasterImageVM.Name

if ( $MasterImageVM.Powerstate -ne 'PoweredOn' ) { Start-VM -VM $MasterImageVM | Wait-Tools }

Write-Verbose "installing VMWare Horizon View agent"

$CMD = @"
if ( -Not ( Get-CIMInstance -Class WIN32_Product -Filter 'Name = "VMware Horizon 7 Connection Server"' ) ) {
    & 'C:\temp\$FileName' /s /v "/qn /l c:\temp\viewagentinstall.log VDM_VC_MANAGED_AGENT=1"

    write-Output "Installed Horizon Agent"
}
Else {
    Write-Output "Horizon agent already installed"
}
"@

$Result = Invoke-VMScript -VM $MasterImageVM -GuestCredential $LocalAdmin -ScriptText $CMD
Write-Verbose $Result

# ----- Return some info for use in the parent
Write-Output $MasterImageVM



