#https://vdc-download.vmware.com/vmwb-repository/dcr-public/3bef9659-5a4d-4d48-a32b-ce82f11eaaec/40484997-036d-49d2-96c3-b20f7db3c503/do-types-landing.html
#https://www.retouw.nl/vsphere/adding-vcenter-server-to-horizon-view-using-the-apis/

#$Global:hvServices = $hvServer.ExtensionData

$vcService = New-Object VMware.Hv.VirtualCenterService
$certService = New-Object VMware.Hv.CertificateService
$vcSpecHelper = $vcService.getVirtualCenterSpecHelper()

$vcPassword = New-Object VMware.Hv.SecureString
$enc = [system.Text.Encoding]::UTF8
$vcPassword.Utf8String = $enc.GetBytes('Branman1!')

$serverSpec = $vcSpecHelper.getDataObject().serverSpec
$serverSpec.serverName = '192.168.1.17'
$serverSpec.port = 443
$serverSpec.useSSL = $true
$serverSpec.userName = 'administrator@vsphere.local'
$serverSpec.password = $vcPassword
$serverSpec.serverType = $certService.getServerSpecHelper().SERVER_TYPE_VIRTUAL_CENTER

#$certData = $certService.Certificate_Validate($HV.ExtensionData, $serverSpec)
#$certificateOverride = New-Object VMware.Hv.CertificateThumbprint
#$certificateOverride.sslCertThumbprint = $certData.thumbprint.sslCertThumbprint
#$certificateOverride.sslCertThumbprintAlgorithm = $certData.thumbprint.sslCertThumbprintAlgorithm

#$vcSpecHelper.getDataObject().CertificateOverride = $certificateOverride

# Make service call
$vcId = $vcService.VirtualCenter_Create($HV.ExtensionData, $vcSpecHelper.getDataObject())
