$ConfigData = @{             
    AllNodes = @(             
        @{             
            Nodename = "KW-HorConn01"               
            Role = 'ViewConnectionServer'             
            OSCustomization = 'WIN 2016 Sysprep'
            DomainName = 'kings-wood.local'
            IPAddress = '192.168.1.17/24'
            SubnetMask = '255.255.255.0'
            DNSServer = "192.168.1.50"
            DefaultGateway = '192.168.1.1' 
            ResourcePool = 'LAB'                      
            SWitch = 'vSwitch0'
            PortGroup = '192.168.1.x'  
            RetryCount = 20              
            RetryIntervalSec = 30            
            PSDscAllowDomainUser = $True
            PsDscAllowPlainTextPassword = $true 
            VMTemplate = "WIN2016Template" 
            ESXHost = '192.168.1.15'    
            Source = '\\192.168.1.166\Source'
            OU = 'OU=VMWare Service Accounts,DC=kings-wood,DC=local' 
            VCSA = '192.168.1.16' 
            VCSAViewRole = 'View Service Account'
            EventDBName = 'ViewEvents'
            SQLServer = 'kw-sql1'
        }            
    )             
}  
