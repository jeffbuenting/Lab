
configuration New-WINContainerSVR            
{             
   param             
    (        
        [PSCredential]$DomainAdmin            
    )             
    
    Import-DscResource –ModuleName 'PSDesiredStateConfiguration'
    Import-DscResource -ModuleName xComputerManagement
    Import-DSCResource -moduleName NetworkingDSC
    Import-DSCResource -ModuleName xWindowsUpdate
    Import-DscResource -ModuleName xSystemSecurity
    Import-DSCResource -ModuleName xTimeZone

    Node $AllNodes.Where{$_.Role -eq "WinContainer"}.Nodename             
    { 

        NetIPInterface DisableDhcpE0
        {
            InterfaceAlias = 'Ethernet0'
            AddressFamily  = 'IPv4'
            Dhcp           = 'Disabled'
        }

        IPAddress NewIPv4AddressE0
        {
            IPAddress      = $Node.IPAddress
            InterfaceAlias = 'Ethernet0'
            AddressFamily  = 'IPV4'
            DependsOn = "[NetIPInterface]DisableDhcpE0"
        }

        DefaultGatewayAddress SetDefaultGatewayE0
        {
            Address        = $Node.DefaultGateway
            InterfaceAlias = 'Ethernet0'
            AddressFamily  = 'IPv4'
            DependsOn = "[IPAddress]NewIPv4AddressE0"
        }

         DNSServerAddress DNSE0 {
            InterfaceAlias = 'Ethernet0'
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

        xComputer SetName { 
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

        # ----- https://blog.sixeyed.com/getting-started-with-docker-on-windows-server-2019/

        WindowsFeature Containers
        {
             Name = 'Containers'
             Ensure = 'Present'
             DependsOn = "[xComputer]SetName"
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
                $True
     #           $Package = Get-Package -Name Docker 
     #           if ( $Package ) { $True } Else { $False }
            }
            DependsOn = "[Script]DockerMsftProvider"
        }

        Service DockerService {
            Name = 'Docker'
            StartupType = 'Automatic'
            State = 'Running'
            DependsOn = "[Script]Docker"
        }
    }
 
}
           
            
 
 
 