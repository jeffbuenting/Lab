
configuration New-LABDomain             
{             
   param             
    (                     
        [Parameter(Mandatory = $true)]             
        [pscredential]$safemodeAdministratorCred, 
                    
        [Parameter(Mandatory = $true)]            
        [pscredential]$domainCred            
    )             
    
    Import-DscResource –ModuleName 'PSDesiredStateConfiguration'
    Import-DscResource -ModuleName xActiveDirectory 
    Import-DscResource -ModuleName xComputerManagement  

    Node $AllNodes.Where{$_.Role -eq "Primary DC"}.Nodename             
    { 

        LocalConfigurationManager 
        {
            ActionAfterReboot = 'ContinueConfiguration'            
            ConfigurationMode = 'ApplyOnly'            
            RebootNodeIfNeeded = $true  
        }

        xComputer SetName { 
            Name = $Node.NodeName 
        }
    }

}
           
            
 

