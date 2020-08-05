$ConfigData = @{             
    AllNodes = @(             
        @{             
            Nodename = "WIN10MA"               
            Role = 'MasterImage'             
            OSCustomization = 'WIN 2016 Sysprep'
            DomainName = 'kings-wood.local'
            ResourcePool = 'LAB'                      
            SWitch = 'vSwitch0'
            PortGroup = '192.168.1.x'  
            RetryCount = 20              
            RetryIntervalSec = 30            
            PSDscAllowDomainUser = $True
            PsDscAllowPlainTextPassword = $true 
            ISO = "'[LocalHDD] ISO/Windows/WIN 10 ENT.iso'" 
            ESXHost = '192.168.1.15'    
            Source = '\\192.168.1.166\Source'
            OU = 'OU=VMWare Service Accounts,DC=kings-wood,DC=local' 

        }            
    )             
}  
