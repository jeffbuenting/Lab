$ConfigData = @{             
    AllNodes = @(             
        @{             
            Nodename = "WIN10MA"               
            Role = 'MasterImage'  
            VMTemplate = 'WIN10_UACDisabled_Template'           
            OSCustomization = 'WIN 10 Sysprep'
            CPU = 4
            MemoryGB = 4
            DomainName = 'kings-wood.local'
            DNSServer = '192.168.1.50'
            ResourcePool = 'LAB' 
            VMFolder = 'MasterImages'                     
            SWitch = 'vSwitch0'
            PortGroup = '192.168.1.x'  
            RetryCount = 20              
            RetryIntervalSec = 30            
            PSDscAllowDomainUser = $True
            PsDscAllowPlainTextPassword = $true  
            ESXHost = '192.168.1.15'    
            Source = '\\192.168.1.166\Source'


        }            
    )             
}  
