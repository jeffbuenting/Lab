# ----- First Domain Controller Data         
$ConfigData = @{             
    AllNodes = @(             
        @{             
            Nodename = "KW-DC1"             
            Role = "DHCP"     
            ScopeName = "LAB - 10.10.10.x"
            ScopeID = "10.10.10.0"
            IPStartRange = '10.10.10.100'
            IPEndRange = '10.10.10.254'
            SubnetMask = '255.255.255.0'
            DNS = '10.10.10.10'
            DefaultGateway = '10.10.10.1'
            DomainName = 'kings-wood.local'   
            LeaseDuration = '12:0:0'
            RetryCount = 20              
            RetryIntervalSec = 30            
            PSDscAllowDomainUser = $True
            PsDscAllowPlainTextPassword = $true         
        }            
    )             
}  
