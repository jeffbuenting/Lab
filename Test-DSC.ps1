

# ----- Load the Config Data
. c:\scripts\lab\containers\DSCConfigs\Config_WINContainerSvr2.ps1

. c:\scripts\lab\containers\DSCConfigs\New-WINContainerSvr.ps1

# ----- Dot source LCM config (same for all scripts)
. "$((Get-item -Path 'C:\Scripts\Lab\Containers').Parent.FullName)\DSCConfigs\LCMConfig.ps1"



    New-WINContainerSvr -ConfigurationData $ConfigData `
        -DomainAdmin $DomainAdmin `
        -IPAddress 192.168.1.64 `
        -SourceAcct $ShareDriveCred `
        -OutputPath c:\scripts\lab\containers\MOF `
        -ErrorAction Stop

if ( -NOT ( Get-PSDrive -Name RemoteDrive -ErrorAction SilentlyContinue )) {
    New-PSDrive -Name RemoteDrive -PSProvider FileSystem -Root "\\192.168.1.64\c$" -Credential $LocalAdmin
}

Copy-Item -Path "c:\scripts\lab\containers\mof\KW-WCont04.mof" -Destination RemoteDrive:\temp\localhost.mof -ErrorAction Stop -Force
