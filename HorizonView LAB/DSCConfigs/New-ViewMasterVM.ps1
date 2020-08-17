
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
        }

        xTimeZone EST {
            IsSingleInstance = 'Yes'
            TimeZone = 'Eastern Standard Time'
        }
  
        xIEEsc IESecAdmin {
            UserRole = 'Administrators'
            IsEnabled = $False
        }

        xIEEsc IESecUsers {
            UserRole = 'Users'
            IsEnabled = $False
        }


        xComputer SetName { 
            Name = $Node.NodeName 
        }

        
  #      xUAC EnableUAC {
  #          Setting = 'AlwaysNotify'
  #      }



    }
} 