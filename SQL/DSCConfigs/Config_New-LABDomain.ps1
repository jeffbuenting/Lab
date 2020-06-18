# ----- First Domain Controller Data         
$ConfigData = @{             
    AllNodes = @(             
        @{             
            Nodename = "KW-SQL1"             
            Role = "SQL"             
            DomainName = 'kings-wood.local'
            IPAddress = '10.10.10.30'
            SubnetMask = '255.255.255.0'
            DefaultGateway = '10.10.10.1'  
            ResourcePool = 'Lab'     
            SWitch = 'vSwitch1'
            PortGroup = 'LAB - 10.10.10.x'     
            RetryCount = 20              
            RetryIntervalSec = 30            
            PSDscAllowDomainUser = $True
            PsDscAllowPlainTextPassword = $true 
            VMTemplate = "WIN2016Template" 
            ESXHost = '192.168.1.15'          
        }            
    )             
}  
