$ConfigData = @{             
    AllNodes = @(             
        @{             
            Nodename = "WIN10MA"               
            Role = 'MasterImage'             
            OSCustomization = 'WIN 10 Sysprep'
            DomainName = 'kings-wood.local'
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
