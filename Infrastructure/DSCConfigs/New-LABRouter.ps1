
configuration New-LABRouter        
{             
   param             
    (                     
           
    )             
    
    Import-DscResource –ModuleName 'PSDesiredStateConfiguration' 
    Import-DscResource -ModuleName xComputerManagement  
    Import-DSCResource -moduleName NetworkingDSC
    Import-DscResource -ModuleName xSystemSecurity
    Import-DSCResource -ModuleName xTimeZone

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

        DNSServerAddress DNSE0 {
            InterfaceAlias = 'Ethernet0'
            AddressFamily = 'IPv4'
            Address = $Node.ExternalDNSServer
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

   #     DefaultGatewayAddress SetDefaultGatewayE1
   #     {
   #         Address        = $Node.DefaultGateway
   #         InterfaceAlias = 'Ethernet1'
   #         AddressFamily  = 'IPv4'
   #     }

        xComputer SetName { 
            Name = $Node.NodeName 
        }

        xTimeZone EST {
            IsSingleInstance = 'Yes'
            TimeZone = 'Eastern Standard Time'
        }

        xIEEsc IESec {
            UserRole = 'Administrators'
            IsEnabled = $False
        }

        # ----- Routing setup and configure
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

        # ----- We need to configure RRAS.  Simple cmdlet to complete.  wrapping in script resource
        # https://docs.microsoft.com/en-us/powershell/scripting/dsc/reference/resources/windows/scriptresource?view=powershell-7
        # https://docs.microsoft.com/en-us/powershell/module/remoteaccess/install-remoteaccess?view=win10-ps
 #       Script ConfigRouting {
 #           GetScript = { @{ Result = (Get-RemoteAccess) } }
 #           
 #           TestScript = {
 #               $RRAS = Get-RemoteAccess
 #               
 #               if ( $RRAS.RoutingStatus -eq 'Installed' ) {
 #                   $True
 #               }
 #               Else {
 #                   $False
 #               }
 #           }
 #           
 #           SetScript = { Install-RemoteAccess -VpnType RoutingOnly }
 #
 #           DependsOn = "[WindowsFeature]Routing"
 #
 #       }
    }
}