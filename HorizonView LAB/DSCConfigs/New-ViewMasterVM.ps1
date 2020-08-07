
configuration New-ViewMasterVM      
{             
  param             
    (                     
 #       [PSCredential]$DomainAdmin       
    )             
    
    Import-DscResource –ModuleName 'PSDesiredStateConfiguration' 
    Import-DscResource -ModuleName xComputerManagement  
    Import-DSCResource -moduleName NetworkingDSC
    Import-DSCResource -ModuleName xTimeZone
    Import-DscResource -ModuleName xSystemSecurity

    Node $AllNodes.Where{$_.Role -eq "MasterImage"}.Nodename             
    { 


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

        xIEEsc IESec {
            UserRole = 'Users'
            IsEnabled = $False
        }


        xComputer SetName { 
            Name = $Node.NodeName 
        }



    }
} 