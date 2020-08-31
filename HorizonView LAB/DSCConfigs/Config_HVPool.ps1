$ConfigData = @{             
    AllNodes = @(             
        @{             
            Nodename = "SurfP"               
            Role = 'HVPool'  
            MasterImage = 'WIN10MA'
            PoolVMFolder = "VDI"
            ResourcePool = 'Resources'
            ESXHost = '192.168.1.15'
            PoolDataStore = 'NFS-Drobo'
            PoolNamePattern = "KW-SurfP"
            PoolMin = 1
            PoolMax = 2
            PoolSpare = 1
            PoolOSCustomization = 'WIN 10 VDI'
            DomainController = 'KW-DC1'
            DomainNetBiosName = 'kings-wood'
            PoolParentOU = 'OU=VDI,DC=kings-wood,DC=local'
            PoolContainer = "OU=SurfPPool,OU=VDI"
            EntitledGroup = "SurfP_Users"
            RetryCount = 20              
            RetryIntervalSec = 30            
            PSDscAllowDomainUser = $True
            PsDscAllowPlainTextPassword = $true  
        }  
        
      #  @{             
      #      Nodename = "DtoD"               
      #      Role = 'HVPool'  
      #      MasterImage = 'WIN10MA'
      #      PoolVMFolder = "VDI"
      #      ResourcePool = 'Resources'
      #      ESXHost = '192.168.1.15'
      #      PoolDataStore = 'NFS-Drobo'
      #      PoolNamePattern = "KW-DtoD"
      #      PoolMin = 1
      #      PoolMax = 2
      #      PoolSpare = 1
      #      PoolOSCustomization = 'WIN 10 VDI'
      #      DomainController = 'KW-DC1'
      #      DomainNetBiosName = 'kings-wood'
      #      PoolParentOU = 'OU=VDI,DC=kings-wood,DC=local'
      #      PoolContainer = "OU=DtoDPool,OU=VDI"
      #      EntitledGroup = "DtoD_Users"
      #      RetryCount = 20              
      #      RetryIntervalSec = 30            
      #      PSDscAllowDomainUser = $True
      #      PsDscAllowPlainTextPassword = $true  
      #  }           
    )             
}  