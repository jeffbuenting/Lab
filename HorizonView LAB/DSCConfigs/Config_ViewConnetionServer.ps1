# ----- First Domain Controller Data         
$ConfigData = @{             
    AllNodes = @(             
        @{             
            Nodename = "KW-HorConn01"             
            Role = "ViewConnectionServer"           
            ResourcePool = 'Management'  
            IPAddress = '192.168.1.17/24'
            DefaultGateway = '192.168.1.1' 
            # ----- Note the quotes.  We use this in Set-DNSClientServer
            DNSServer = """10.10.10.10""","""192.168.1.1"""         
            SWitch = 'vSwitch0'
            PortGroup = '192.168.1.x' 
            DomainName = 'kings-wood.local'
            RetryCount = 20              
            RetryIntervalSec = 30            
            PSDscAllowDomainUser = $True
            PsDscAllowPlainTextPassword = $true 
            VMTemplate = "WIN2016Template" 
            ESXHost = '192.168.1.15'          
        }            
    )             
}  
