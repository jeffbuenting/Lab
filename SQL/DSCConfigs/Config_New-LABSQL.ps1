# ----- First Domain Controller Data         
$ConfigData = @{             
    AllNodes = @(             
        @{             
            Nodename = "KW-SQL1"             
            Role = "SQL"             
            OSCustomization = 'WIN 2016 Sysprep'
            DomainName = 'kings-wood.local'
            IPAddress = '10.10.10.30'
            SubnetMask = '255.255.255.0'
            DNSServer = '10.10.10.10'
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
            SQLISO = '[LocalHDD] ISO/SQL/SQLServer2019-x64-ENU.iso' 
            Source = '\\192.168.1.166\Source'
            #OU = 'cn=Managed Service Accounts,dc=kings-wood,dc=local'
            OU =  'cn=Userskw,dc=kings-wood,dc=local'
        }            
    )             
}  
