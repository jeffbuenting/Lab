$hvServer = $HV
$services=  $hvServer.ExtensionData

# Create required objects

$spec=new-object VMware.Hv.VirtualCenterSpec
$spec.serverspec=new-object vmware.hv.serverspec
$spec.viewComposerData=new-object VMware.Hv.virtualcenterViewComposerData

$spec.Certificateoverride=new-object vmware.hv.CertificateThumbprint
$spec.limits=new-object VMware.Hv.VirtualCenterConcurrentOperationLimits
$spec.storageAcceleratorData=new-object VMware.Hv.virtualcenterStorageAcceleratorData

# vCenter Server specs

$spec.ServerSpec.servername="192.168.1.16"        # Required, fqdn for the vCenter server
$spec.ServerSpec.port=443                                 # Required
$spec.ServerSpec.usessl=$true                             # Required
$spec.ServerSpec.username="administrator@vsphere.local"   # Required user@domain
$vcpassword=read-host "vCenter User password?" -assecurestring
$temppw = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($vcPassword)
$PlainvcPassword = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($temppw)
$vcencPassword = New-Object VMware.Hv.SecureString
$enc = [system.Text.Encoding]::UTF8
$vcencPassword.Utf8String = $enc.GetBytes($PlainvcPassword)
$spec.ServerSpec.password=$vcencPassword
$spec.ServerSpec.servertype="VIRTUAL_CENTER"

# Description & Displayname, neither is required to be set

#$spec.description="description"              # Not Required
#$spec.displayname="virtualcenterdisplayname" # Not Required
$spec.CertificateOverride=($services.Certificate.Certificate_Validate($spec.serverspec)).thumbprint
$spec.CertificateOverride.SslCertThumbprint=($services.Certificate.Certificate_Validate($spec.serverspec)).certificate
$spec.CertificateOverride.sslCertThumbprintAlgorithm = "DER_BASE64_PEM"


# Limits
# Only change when you want to change the default values. It is required to set these in the spec

$spec.limits.vcProvisioningLimit=20
$spec.Limits.VcPowerOperationsLimit=50
$spec.limits.ViewComposerProvisioningLimit=12
$spec.Limits.ViewComposerMaintenanceLimit=20
$spec.Limits.InstantCloneEngineProvisioningLimit=20

# Storage Accelerator data

$spec.StorageAcceleratorData.enabled=$false
#$spec.StorageAcceleratorData.DefaultCacheSizeMB=1024   # Not Required

# Cmposer
# most can be left empty but they need to be set otherwise you'll get a xml error

$spec.ViewComposerData.viewcomposertype="STANDALONE"  # DISABLED for none, LOCAL_TO_VC for installed with the vcenter and STANDALONE for s standalone composer


if ($spec.ViewComposerData.viewcomposertype -ne "DISABLED"){
    $spec.ViewComposerData.ServerSpec=new-object vmware.hv.serverspec
    $spec.ViewComposerData.CertificateOverride=new-object VMware.Hv.CertificateThumbprint
    $cmppassword=read-host "Composer user password?" -assecurestring
    $temppw = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($cmpPassword)
    $PlaincmpPassword = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($temppw)
    $cmpencPassword = New-Object VMware.Hv.SecureString
    $enc = [system.Text.Encoding]::UTF8
    $cmpencPassword.Utf8String = $enc.GetBytes($PlaincmpPassword)
    $spec.ViewComposerData.ServerSpec.password=$cmpencPassword
    $spec.ViewComposerData.ServerSpec.servername="pod2cmp1.loft.lab"
    $spec.ViewComposerData.ServerSpec.port=18443
    $spec.ViewComposerData.ServerSpec.usessl=$true
    $spec.ViewComposerData.ServerSpec.username="m_wouter@loft.lab"
    $spec.ViewComposerData.ServerSpec.servertype="VIEW_COMPOSER"

    $spec.ViewComposerData.CertificateOverride=($services.Certificate.Certificate_Validate($spec.ViewComposerData.ServerSpec)).thumbprint
    $spec.ViewComposerData.CertificateOverride.sslCertThumbprint = ($services.Certificate.Certificate_Validate($spec.ViewComposerData.ServerSpec)).certificate
    $spec.ViewComposerData.CertificateOverride.sslCertThumbprintAlgorithm = "DER_BASE64_PEM"
}


# Disk reclamation, this is required to be set to either $false or $true
$spec.SeSparseReclamationEnabled=$false 

# This will create the connection
$services.VirtualCenter.VirtualCenter_Create($spec)