$ConfigData = @{             
    AllNodes = @(             
        @{             
            Nodename = "SurfP"               
            Role = 'HVPool'  
            PoolVMFolder = $PoolName
            ESXHost = '192.168.1.15'
            PoolDataStore = 'NFS-Drobo'
            PoolNamePattern = 'KW-SurfP'
            PoolMin = 1
            PoolMax = 2
            PoolSpare = 1
            PoolOSCustomization = 'WIN 10 VDI'
            DomainController = 'KW-DC1'
            DomainNetBiosName = 'kings-wood'
            PoolContainer = "OU=$($ConfigData.AllNodes.NodeName),OU=VDI"
            RetryCount = 20              
            RetryIntervalSec = 30            
            PSDscAllowDomainUser = $True
            PsDscAllowPlainTextPassword = $true  
        }            
    )             
}  