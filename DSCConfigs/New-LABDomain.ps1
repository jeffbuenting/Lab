
configuration New-LABDomain             
{             
   param             
    (                     
        [Parameter(Mandatory = $true)]             
        [pscredential]$safemodeAdministratorCred, 
                    
        [Parameter(Mandatory = $true)]            
        [pscredential]$domainCred            
    )             
    
    Import-DscResource –ModuleName 'PSDesiredStateConfiguration'
    Import-DscResource -ModuleName xActiveDirectory 
    Import-DscResource -ModuleName xComputerManagement  
#    Import-DSCResource -moduleName NetworkingDSC

    Node $AllNodes.Where{$_.Role -eq "Primary DC"}.Nodename             
    { 

#        NetIPInterface DisableDhcp
#        {
#            InterfaceAlias = 'Ethernet'
#            AddressFamily  = 'IPv4'
#            Dhcp           = 'Disabled'
#        }
#
#
#        IPAddress NewIPv4Address
#        {
#            IPAddress      = $Node.IPAddress
#            InterfaceAlias = 'Ethernet'
#            AddressFamily  = 'IPV4'
#        }
#
#        DefaultGatewayAddress SetDefaultGateway
#        {
#            Address        = $Node.DefaultGateway
#            InterfaceAlias = 'Ethernet'
#            AddressFamily  = 'IPv4'
#        }

        xComputer SetName { 
            Name = $Node.NodeName 
        }

        

        File ADFiles            
        {            
            DestinationPath = 'C:\NTDS'            
            Type = 'Directory'            
            Ensure = 'Present'            
        }            
                    
        WindowsFeature ADDSInstall             
        {             
            Ensure = "Present"             
            Name = "AD-Domain-Services"             
        }            
            
        # Optional GUI tools            
        WindowsFeature ADDSTools            
        {             
            Ensure = "Present"             
            Name = "RSAT-ADDS"             
        }            
            
        # No slash at end of folder paths            
        xADDomain FirstDS             
        {             
            DomainName = $Node.DomainName             
            DomainAdministratorCredential = $domainCred             
            SafemodeAdministratorPassword = $safemodeAdministratorCred            
            DatabasePath = 'C:\NTDS'            
            LogPath = 'C:\NTDS'            
            DependsOn = "[WindowsFeature]ADDSInstall","[File]ADFiles"            
        }            
    }

}
           
            
 

