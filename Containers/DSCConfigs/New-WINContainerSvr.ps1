
configuration New-WINContainerSVR            
{             
   param             
    (        
        [PSCredential]$DomainAdmin            
    )             
    
    Import-DscResource –ModuleName 'PSDesiredStateConfiguration'
    Import-DscResource -ModuleName ComputerManagementDSC
    Import-DSCResource -moduleName NetworkingDSC
    Import-DSCResource -ModuleName xWindowsUpdate
    Import-DscResource -ModuleName xSystemSecurity
    Import-DSCResource -ModuleName xTimeZone

    Node $AllNodes.Where{$_.Role -eq "WinContainer"}.Nodename             
    { 


        NetIPInterface DisableDhcpE0
        {
            InterfaceAlias = 'Ethernet0 3'
            AddressFamily  = 'IPv4'
            Dhcp           = 'Disabled'
        }

        IPAddress NewIPv4AddressE0
        {
            IPAddress      = $Node.IPAddress
            InterfaceAlias = 'Ethernet0 3'
            AddressFamily  = 'IPV4'
            DependsOn = "[NetIPInterface]DisableDhcpE0"
        }

        DefaultGatewayAddress SetDefaultGatewayE0
        {
            Address        = $Node.DefaultGateway
            InterfaceAlias = 'Ethernet0 3'
            AddressFamily  = 'IPv4'
            DependsOn = "[IPAddress]NewIPv4AddressE0"
        }

         DNSServerAddress DNSE0 {
            InterfaceAlias = 'Ethernet0 3'
            AddressFamily = 'IPv4'
            Address = $Node.DNSServer
            DependsOn = "[DefaultGatewayAddress]SetDefaultGatewayE0"
        }

        xTimeZone EST {
            IsSingleInstance = 'Yes'
            TimeZone = 'Eastern Standard Time'
        }

        xIEEsc IESec {
            UserRole = 'Administrators'
            IsEnabled = $False
        }

        Computer SetName { 
            Name = $Node.NodeName 
            DomainName = $Node.DomainName
            Credential = $DomainAdmin
            DependsOn = "[DNSServerAddress]DNSE0","[xTimeZone]EST"
        }

  #      xWindowsUpdateAgent Updates {
  #          IsSingleInstance = 'Yes'
  #          Source = 'MicrosoftUpdate'
  #          Category = 'Security'
  #          UpdateNow = $True
  #          DependsOn = '[xComputer]SetName'
  #      }

        RemoteDesktopAdmin RDP {
            IsSingleInstance   = 'yes'
            Ensure             = 'Present'
            UserAuthentication = 'NonSecure'
        }

        Firewall 'Remote Desktop - User Mode (TCP-In)'
        {
            Name                  = 'Remote Desktop - User Mode (TCP-In)'
            Ensure                = 'Present'
            Enabled               = 'True'
        }

        Firewall 'Remote Desktop - User Mode (UDP-In)'
        {
            Name                  = 'Remote Desktop - User Mode (UDP-In)'
            Ensure                = 'Present'
            Enabled               = 'True'
        }

        # ----- https://blog.sixeyed.com/getting-started-with-docker-on-windows-server-2019/

        WindowsFeature Containers
        {
             Name = 'Containers'
             Ensure = 'Present'
             DependsOn = "[Computer]SetName"
        }

        Script DockerMsftProvider {
            GetScript = { Get-Module -Name DockerMsftProviderer }
            SetScript = { Install-Module -Name DockerMsftProvider }
            TestScript = {
                $Module = Get-Module -Name DockerMsftProvider -ErrorAction SilentlyContinue 
                if ( $Module ) { $True } Else { $False }
            }
            DependsOn = "[WindowsFeature]Containers"
        }
       
        Script Docker {
            GetScript = { Get-Package -Name Docker }
            SetScript = { Install-Package -Name Docker -ProviderName DockerMsftProvider -Force  }
            TestScript = {
                #$True
                $Package = Get-Package -Name Docker -ErrorAction SIlentlyContinue
                if ( $Package ) { $True } Else { $False }
            }
            DependsOn = "[Script]DockerMsftProvider"
        }

        Service DockerService {
            Name = 'Docker'
            StartupType = 'Automatic'
            State = 'Running'
            DependsOn = "[Script]Docker"
        }

        # ----- Env DSC resource doesn't seem to be work for all users.  so using a script resource
        # https://codingbee.net/powershell/powershell-make-a-permanent-change-to-the-path-environment-variable
        Script DockerPath {
            GetScript = { (Get-ItemProperty -Path 'Registry::HKEY_LOCAL_MACHINE\System\CurrentControlSet\Control\Session Manager\Environment' -Name PATH).path }
            SetScript = { 
                $oldpath = (Get-ItemProperty -Path 'Registry::HKEY_LOCAL_MACHINE\System\CurrentControlSet\Control\Session Manager\Environment' -Name PATH).path
                $newpath = “$oldpath;C:\Program Files\Docker”
                Set-ItemProperty -Path 'Registry::HKEY_LOCAL_MACHINE\System\CurrentControlSet\Control\Session Manager\Environment' -Name PATH -Value $newPath
            }
            TestScript = {
                $oldpath = (Get-ItemProperty -Path 'Registry::HKEY_LOCAL_MACHINE\System\CurrentControlSet\Control\Session Manager\Environment' -Name PATH).path
                if ( $OldPath -notcontains 'C:\Program Files\Docker' ) { $False } Else { $True }
            }
            DependsOn = '[Service]DockerService'
        }

  #      Environment DockerPath 
  #      {
  #          Name = 'Path'
  #          Path = $True
  #          Value = 'C:\Program Files\Docker'
  #          DependsOn = '[Service]DockerService'
  #      }

        # https://docs.docker.com/compose/install/
        Script DockerCompose {
            GetScript = { docker-compose -v }
            TestScript = {
                if ( (docker-compose -v ) ) { $True } Else { $False }
            }
            SetScript = {
                [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
                Invoke-WebRequest "https://github.com/docker/compose/releases/download/1.27.4/docker-compose-Windows-x86_64.exe" -UseBasicParsing -OutFile $Env:ProgramFiles\Docker\docker-compose.exe
            }
            DependsOn = '[Service]DockerService'
        }
    }
 
}
           
            
 
 
 