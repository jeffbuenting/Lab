
configuration New-LABRouter        
{             
   param             
    (                     
           
    )             
    
    Import-DscResource –ModuleName 'PSDesiredStateConfiguration' 
    Import-DscResource -ModuleName xComputerManagement  
    Import-DSCResource -moduleName NetworkingDSC

    Node $AllNodes.Where{$_.Role -eq "Router"}.Nodename             
    { 

        NetIPInterface DisableDhcpE0
        {
            InterfaceAlias = 'Ethernet0'
            AddressFamily  = 'IPv4'
            Dhcp           = 'Disabled'
        }


        IPAddress NewIPv4AddressE0
        {
            IPAddress      = $Node.ExternalIPAddress
            InterfaceAlias = 'Ethernet0'
            AddressFamily  = 'IPV4'
        }

        DefaultGatewayAddress SetDefaultGatewayE0
        {
            Address        = $Node.ExternalDefaultGateway
            InterfaceAlias = 'Ethernet0'
            AddressFamily  = 'IPv4'
        }

        NetIPInterface DisableDhcpE1
        {
            InterfaceAlias = 'Ethernet1'
            AddressFamily  = 'IPv4'
            Dhcp           = 'Disabled'
        }


        IPAddress NewIPv4AddressE1
        {
            IPAddress      = $Node.IPAddress
            InterfaceAlias = 'Ethernet1'
            AddressFamily  = 'IPV4'
        }

        DefaultGatewayAddress SetDefaultGatewayE1
        {
            Address        = $Node.DefaultGateway
            InterfaceAlias = 'Ethernet1'
            AddressFamily  = 'IPv4'
        }

        xComputer SetName { 
            Name = $Node.NodeName 
        }

        WindowsFeature Routing
        {
            Ensure = "Present"
            Name = "Routing"
        }

        WindowsFeature RSAT-Tools
        {
            Name = 'RSAT-RemoteAccess'
            Ensure = 'Present'
            IncludeAllSubFeature = $True
        }
    }
}