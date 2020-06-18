
configuration New-LABDHCP             
{                        
    
    Import-DscResource –ModuleName 'PSDesiredStateConfiguration'
    Import-DscResource -ModuleName xDHCPServer

    Node $AllNodes.Where{$_.Role -eq "DHCP"}.Nodename             
    { 

        WindowsFeature DHCP
        {
            Ensure = "Present"
            Name = "DHCP"
        }

        WindowsFeature DHCPTools
        {
            Ensure = "Present"
            Name = "RSAT-DHCP"
        }

        xDhcpServerAuthorization Authorize
        {
            Ensure = "Present"
        }

        xDHCPServerScope LabScope
        {
            Ensure = "Present"
            ScopeID = $Node.ScopeID
            IPStartRange = $Node.IPStartRange
            IPEndRange = $Node.IPEndRange
            Name = $Node.ScopeName
            SubnetMask = $Node.SubnetMask
            LeaseDuration = $Node.LeaseDuration
            State = "Active"
            AddressFamily = 'IPv4'
        }
 
         # Setting scope gateway
         DhcpScopeOptionValue scopeOptionGateway
         {
             OptionId = 3
             Value = $Node.DefaultGateway
             ScopeId =   $Node.ScopeId
             VendorClass = ''
             UserClass   = ''
             AddressFamily = 'IPv4'
         }
  
         # Setting scope DNS servers
         DhcpScopeOptionValue scopeOptionDNS
         {
             OptionId = 6
             Value = $Node.DNS
             ScopeId =   $Node.ScopeID
             VendorClass = ''
             UserClass   = ''
             AddressFamily = 'IPv4'
         }
  
         # Setting scope DNS domain name
         DhcpScopeOptionValue scopeOptionDNSDomainName
         {
             OptionId = 15
             Value = $Node.DomainName
             ScopeId =   $Node.ScopeID
             VendorClass = ''
             UserClass   = ''
             AddressFamily = 'IPv4'
         }

        
         
    }

}
           
            
 

