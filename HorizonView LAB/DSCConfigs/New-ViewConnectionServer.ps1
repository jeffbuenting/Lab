﻿
configuration New-ViewConnectionServer       
{             
   param             
    (                     
        [PSCredential]$DomainAdmin       
    )             
    
    Import-DscResource –ModuleName 'PSDesiredStateConfiguration' 
    Import-DscResource -ModuleName xComputerManagement  
    Import-DSCResource -moduleName NetworkingDSC

    Node $AllNodes.Where{$_.Role -eq "ViewConnectionServer"}.Nodename             
    { 


        NetIPInterface DisableDhcpE1
        {
            InterfaceAlias = 'Ethernet0'
            AddressFamily  = 'IPv4'
            Dhcp           = 'Disabled'
        }


        IPAddress NewIPv4AddressE1
        {
            IPAddress      = $Node.IPAddress
            InterfaceAlias = 'Ethernet0'
            AddressFamily  = 'IPV4'
        }

        DefaultGatewayAddress SetDefaultGatewayE1
        {
            Address        = $Node.DefaultGateway
            InterfaceAlias = 'Ethernet0'
            AddressFamily  = 'IPv4'
        }

    #    DnsServerAddress DNSE1
    #    {
    #        #Address        = $Node.DNSServer
    #        Address        = @(
    #            '10.10.10.10'
    #        )
    #        InterfaceAlias = 'Ethernet0'
    #        AddressFamily  = 'IPv4'
    #        Validate       = $true
    #    }

        xComputer SetName { 
            Name = $Node.NodeName 
            DomainName = $Node.DomainName
            Credential = $DomainAdmin
        }




    }
}