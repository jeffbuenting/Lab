$ConfigData = @{             
    AllNodes = @(             
        @{             
            Nodename = "KW-HVThinApp"               
            Role = 'ThinApp' 
            VMTemplate = 'WIN10_UACDisabled_Template'            
            OSCustomization = 'WIN 10 Workgroup'
            CPU = 4
            MemoryGB = 4
            IPAddress = '192.168.1.59'
    #        DefaultGateway = '192.168.1.1'
            DNSServer = '192.168.1.1'
            DomainName = 'kings-wood.local'
            Datastore = 'NFS-Drobo'
       #     ResourcePool = 'Resources' 
            VMFolder = 'Lab'                     
            SWitch = 'vSwitch0'
            PortGroup = '192.168.1.x'  
            RetryCount = 20              
            RetryIntervalSec = 30            
            PSDscAllowDomainUser = $True
            PsDscAllowPlainTextPassword = $true  
            ESXHost = '192.168.1.14'    
            Source = '\\192.168.1.166\Source'
            
        }            
    )             
}  