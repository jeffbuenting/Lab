
configuration New-LABSQL            
{             
   param             
    (                    
        [Parameter(Mandatory = $true)]            
        [pscredential]$domainCred,
        
        [Parameter(Mandatory = $true)]            
        [pscredential]$SQLSvcAccount,
        
        [Parameter(Mandatory = $true)]            
        [pscredential]$SAAccount    
    )             
    
    Import-DscResource –ModuleName 'PSDesiredStateConfiguration'
    Import-DscResource -ModuleName xComputerManagement
    Import-DSCResource -ModuleName SqlServerDsc  
    Import-DSCResource -ModuleName ccdromdriveletter

    Node $AllNodes.Where{$_.Role -eq "SQL"}.Nodename             
    { 

        xComputer SetName { 
            Name = $Node.NodeName 
            DomainName = $Node.DomainName
            Credential = $DomainCred
        }

        WindowsFeature 'NetFramework45'
        {
             Name = 'Net-Framework-45-Core'
             Ensure = 'Present'
        }

        ccdromdriveletter CDROMDrive
        {
            DriveLetter = 'R'
            Ensure = 'Present'
        }

        SqlSetup 'InstallDefaultInstance'
        {
            InstanceName        = 'MSSQLSERVER'
            Features            = 'SQLENGINE'
            SourcePath          = 'R:\'
            SQLSysAdminAccounts = @('Administrators')
            SQLSvcAccount       = $SQLSvcAccount
            SecurityMode        = 'SQL'
            SAPwd               = $SAAccount
            DependsOn           = '[WindowsFeature]NetFramework45','[ccdromdriveletter]CDROMDrive'
        }
    }

}
           
            
 

