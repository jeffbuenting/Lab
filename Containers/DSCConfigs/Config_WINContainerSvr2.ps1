﻿  
$ConfigData = @{            
 
    AllNodes = @(    
        @{
            Nodename = '*'
            DomainName = 'kings-wood.local'
            SubnetMask = '255.255.255.0'
            DNSServer = '192.168.1.50'
            DefaultGateway = '192.168.1.1'        
            RetryCount = 20              
            RetryIntervalSec = 30            
            PSDscAllowDomainUser = $True
            PsDscAllowPlainTextPassword = $true   
        }
                 
        @{             
            Nodename = "KW-WCont04"             
            Role = "WinContainer"             
            IPAddress = '192.168.1.64' 
            SwarmName = 'KWSwarm02'
            SwarmRole = 'Manager'        
        }  
        
  #      @{             
  #          Nodename = "KW-WCont05"             
  #          Role = "WinContainer"             
  #          IPAddress = '192.168.1.65'
  #          SwarmName = 'KWSwarm02'
  #          SwarmRole = 'Manager'
  #      } 
        
              
    )
   
    NonNode = @{
        OSCustomization = 'WIN 2019 Sysprep'
        SWitch = 'vSwitch0'
        PortGroup = '192.168.1.x'
        VMTemplate = "WIN2019STD_T" 
        ESXHost = '192.168.1.14'   
        Source = '\\192.168.1.23\Source'
        DataStore = 'NFS-Drobo'
    }         
}  