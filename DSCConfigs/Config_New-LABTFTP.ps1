# ----- First Domain Controller Data         
$ConfigData = @{             
    AllNodes = @(             
        @{             
            Nodename = "KW-Router1"             
            Role = "TFTP"   
            TFTPRoot = 'c:\tftp'
            IPRange = '10.10.10.0/24'  
            RetryCount = 20              
            RetryIntervalSec = 30            
            PSDscAllowDomainUser = $True
            PsDscAllowPlainTextPassword = $true         
        }            
    )             
}  
