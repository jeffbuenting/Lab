# ----- First Domain Controller Data         
$ConfigData = @{             
    AllNodes = @(             
        @{             
            Nodename = "KW-Router1"             
            Role = "Router"           
            ResourcePool = 'Lab'  
            OSCustomization = 'WIN 2016 Sysprep'
            IPAddress = '10.10.10.1/24'
            DefaultGateway = '10.10.10.1'       
            SWitch = 'vSwitch1'
            PortGroup = 'LAB - 10.10.10.x' 
            ExternalIPAddress = '192.168.1.10/24'
            ExternalDefaultGateway = '192.168.1.1' 
            ExternalSwitch = 'VSwitch0'   
            ExternalPortGroup = '192.168.1.x'
            RetryCount = 20              
            RetryIntervalSec = 30            
            PSDscAllowDomainUser = $True
            PsDscAllowPlainTextPassword = $true 
            VMTemplate = "WIN2016Template" 
            ESXHost = '192.168.1.15'          
        }            
    )             
}  
