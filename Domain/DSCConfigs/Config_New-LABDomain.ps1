# ----- First Domain Controller Data         
$ConfigData = @{             
    AllNodes = @(             
        @{             
            Nodename = "KW-DC1"             
            Role = "Primary DC"       
            OSCustomization = 'WIN 2016 Sysprep'      
            DomainName = 'kings-wood.local'
            IPAddress = '192.168.1.50'
            SubnetMask = '255.255.255.0'
            DefaultGateway = '192.168.1.1'
            DNSForwarder = '192.168.1.1' 
            ResourcePool = 'Lab'     
            SWitch = 'vSwitch0'
            PortGroup = '192.168.1.x'    
            RetryCount = 20              
            RetryIntervalSec = 30            
            PSDscAllowDomainUser = $True
            PsDscAllowPlainTextPassword = $true 
            VMTemplate = "WIN2016Template" 
            ESXHost = '192.168.1.15'  
                   
        }            
    )             
}  
