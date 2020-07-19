
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
    Import-DSCResource -moduleName NetworkingDSC
    Import-DSCResource -ModuleName xWindowsUpdate
    Import-DscResource -ModuleName xSystemSecurity
    Import-DSCResource -ModuleName xTimeZone

    Node $AllNodes.Where{$_.Role -eq "SQL"}.Nodename             
    { 

        NetIPInterface DisableDhcpE0
        {
            InterfaceAlias = 'Ethernet0'
            AddressFamily  = 'IPv4'
            Dhcp           = 'Disabled'
        }

        IPAddress NewIPv4AddressE0
        {
            IPAddress      = $Node.IPAddress
            InterfaceAlias = 'Ethernet0'
            AddressFamily  = 'IPV4'
        }

        DefaultGatewayAddress SetDefaultGatewayE0
        {
            Address        = $Node.DefaultGateway
            InterfaceAlias = 'Ethernet0'
            AddressFamily  = 'IPv4'
        }

         DNSServerAddress DNSE0 {
            InterfaceAlias = 'Ethernet0'
            AddressFamily = 'IPv4'
            Address = $Node.DNSServer
        }

        xTimeZone EST {
            IsSingleInstance = 'Yes'
            TimeZone = 'Eastern Standard Time'
        }

        xIEEsc IESec {
            UserRole = 'Administrators'
            IsEnabled = $False
        }

        xComputer SetName { 
            Name = $Node.NodeName 
            DomainName = $Node.DomainName
            Credential = $DomainCred
            DependsOn = "[DNSServerAddress]DNSE0"
        }

  #      xWindowsUpdateAgent Updates {
  #          IsSingleInstance = 'Yes'
  #          Source = 'MicrosoftUpdate'
  #          Category = 'Security'
  #          UpdateNow = $True
  #          DependsOn = '[xComputer]SetName'
  #      }

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

        Package SSMS {
             Name = 'SSMS'
             Path = "C:\temp\SSMS-Setup-ENU.exe"
             ProductId = '83660798-3DA3-4197-B48A-D2F6FC52CCF5'
             Arguments = "/Quiet /log 'c:\temp\ssmssetup.log' SSMSInstallRoot='c:\Program Files(x86)\Microsoft SQL Server Management Studio 18'"
             PsDscRunAsCredential = $DomainCred
  #           DependsOn = '[xWindowsUpdateAgent]Updates'
            DependsON = '[SqlSetup]InstallDefaultInstance'
        }
    }

}
           
            
 

