# ----- First Domain Controller Data         
$ConfigData = @{             
    AllNodes = @(             
        @{             
            Nodename = "KW-Router1"             
            Role = "TFTP"   
            TFTPRoot = 'c:\tftp'  
            RetryCount = 20              
            RetryIntervalSec = 30            
            PSDscAllowDomainUser = $True
            PsDscAllowPlainTextPassword = $true         
        }            
    )             
}  
