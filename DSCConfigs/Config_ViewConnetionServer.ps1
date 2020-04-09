# ----- First Domain Controller Data         
$ConfigData = @{             
    AllNodes = @(             
        @{             
            Nodename = "KW-ViewConnection01"             
            Role = "ViewConnectionServer"           
            ResourcePool = 'Maintenance'  
            IPAddress = '192.168.1.17/24'
            DefaultGateway = '192.168.1.1'       
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
