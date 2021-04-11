
configuration New-ViewConnectionServer       
{             
  param             
    (                     
        [PSCredential]$DomainAdmin       
    )             
    
    Import-DscResource –ModuleName 'PSDesiredStateConfiguration' 
    Import-DscResource -ModuleName xComputerManagement  
    Import-DSCResource -moduleName NetworkingDSC
    Import-DSCResource -ModuleName xTimeZone
    Import-DscResource -ModuleName xSystemSecurity

    Node $AllNodes.Where{$_.Role -eq "ViewConnectionServer"}.Nodename             
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
        }

 #       # ----- Install Connection server
 #       # -----https://thevirtualist.org/automated-installation-vmware-view-components/
 #       # -----  C:\temp\VMware-Horizon-Connection-Server-x86_64-7.12.0-15770369.exe /s /v "/qn /l c:\temp\viewinstall.log VDM_SERVER_INSTANCE_TYPE=1 INSTALLDIR=""C:\View"" FWCHOICE=1 VDM_SERVER_RECOVERY_PWD=mini VDM_SERVER_RECOVERY_PWD_REMINDER=""yep"""
 #       Package HorizonView {
 #           Ensure      = "Present"  
 #           Path        = "C:\temp\VMware-Horizon-Connection-Server-x86_64-7.12.0-15770369.exe"
 #           Name        = "VMware View Connection Server 7.12"
 #           ProductId   = "BA8F6334-CB3D-42C2-A6FF-C4A90A3314B7"
 #           Arguments   =  '/s /v "/qn /l c:\temp\viewinstall.log VDM_SERVER_INSTANCE_TYPE=1 INSTALLDIR=""C:\View"" FWCHOICE=1 VDM_SERVER_RECOVERY_PWD=mini VDM_SERVER_RECOVERY_PWD_REMINDER=""yep"""'
 #       }

    }
} 