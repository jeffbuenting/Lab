  
$ConfigData = @{             
    AllNodes = @(             
        @{             
            Nodename = "KW-WCont01"             
            Role = "WinContainer"             
            OSCustomization = 'WIN 2019 Sysprep'
            DomainName = 'kings-wood.local'
            IPAddress = '192.168.1.60'
            SubnetMask = '255.255.255.0'
            DNSServer = '192.168.1.50'
            DefaultGateway = '192.168.1.1'    
            SWitch = 'vSwitch0'
            PortGroup = '192.168.1.x'    
            RetryCount = 20              
            RetryIntervalSec = 30            
            PSDscAllowDomainUser = $True
            PsDscAllowPlainTextPassword = $true 
            VMTemplate = "WIN2019STD_T" 
            ESXHost = '192.168.1.14'   
            Source = '\\192.168.1.166\Source'
            DataStore = 'NFS-Drobo'
        }            
    )             
}  
