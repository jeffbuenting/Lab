# ----- First Domain Controller Data         
$ConfigData = @{             
    AllNodes = @(             
        @{             
            Nodename = "KW-SQL1"             
            Role = "SQL"             
            OSCustomization = 'WIN 2016 Sysprep'
            DomainName = 'kings-wood.local'
            IPAddress = '192.168.1.52'
            SubnetMask = '255.255.255.0'
            DNSServer = '192.168.1.50'
            DefaultGateway = '192.168.1.1'  
            ResourcePool = 'Lab'     
            SWitch = 'vSwitch0'
            PortGroup = '192.168.1.x'    
            RetryCount = 20              
            RetryIntervalSec = 30            
            PSDscAllowDomainUser = $True
            PsDscAllowPlainTextPassword = $true 
            VMTemplate = "WIN2016Template" 
            ESXHost = '192.168.1.15'   
            SQLISO = '[LocalHDD] ISO/SQL/SQLServer2019-x64-ENU.iso' 
            Source = '\\192.168.1.166\Source'
            #OU = 'cn=Managed Service Accounts,dc=kings-wood,dc=local'
            OU =  'OU=ServiceAcct,dc=kings-wood,dc=local'
        }            
    )             
}  
