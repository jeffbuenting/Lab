
configuration New-ViewConnectionServer       
{             
   param             
    (                     
           
    )             
    
    Import-DscResource –ModuleName 'PSDesiredStateConfiguration' 
    Import-DscResource -ModuleName xComputerManagement  
    Import-DSCResource -moduleName NetworkingDSC

    Node $AllNodes.Where{$_.Role -eq "ViewConnectionServer"}.Nodename             
    { 


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



    }
}