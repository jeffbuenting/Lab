
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
        # ----- VMs in my environment are loosing network when they reboot.  Turns out this is an issue with how MS, VMTools, and Cisco handle ARP retrys.  Two ways to fix this.
        # -----     1. disable ARP retrys at each Cisco switch.
        # -----     2. Disably in Windows registry.  https://communities.vmware.com/t5/VMware-vCenter-Discussions/no-network-connectivity-to-vm-after-restart/m-p/470597
        Registry ArpRetryCount {
            Ensure      = "Present"  
            Key         = "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters"
            ValueName   = "ArpRetryCount"
            ValueData   = "0"
        }

        NetIPInterface DisableDhcpE0
        {
            InterfaceAlias = 'Ethernet0'
            AddressFamily  = 'IPv4'
            Dhcp           = 'Disabled'
            DependsOn      = '[Registry]ArpRetryCount'
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
           
            
 
 
 