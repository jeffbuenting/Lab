
configuration New-ViewMasterVM      
{             
  param             
    (                     
        [PSCredential]$LocalAdmin      
    )             
 

    Import-DscResource –ModuleName 'PSDesiredStateConfiguration' 
    Import-DscResource -ModuleName xComputerManagement  
    Import-DSCResource -moduleName NetworkingDSC
    Import-DSCResource -ModuleName xTimeZone
    Import-DscResource -ModuleName xSystemSecurity

    Node $AllNodes.Where{$_.Role -eq "MasterImage"}.Nodename             
    { 


         DNSServerAddress DNSE0 {
            InterfaceAlias = 'Ethernet0'
            AddressFamily = 'IPv4'
            Address = $Node.DNSServer
        }

        xTimeZone EST {
            IsSingleInstance = 'Yes'
            TimeZone = 'Eastern Standard Time'
        }
  
        xIEEsc IESecAdmin {
            UserRole = 'Administrators'
            IsEnabled = $False
        }

        xIEEsc IESecUsers {
            UserRole = 'Users'
            IsEnabled = $False
        }

        xComputer SetName { 
            Name = $Node.NodeName 
        }

        Registry Hi {
            Key = 'HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System'
            ValueName = 'EnableFirstLogonAnimation'
            ValueData = 0
            ValueType = 'Dword' 
            Ensure = 'Absent'
        }

        Package HorizonView {
            Ensure      = "Present"  
            #Path        = "C:\temp\VMware-Horizon-Agent-x86_64-7.12.0-15805436.exe"
            Path        = $Node.HorizonAgent
            Credential  = $LocalAdmin
            Name        = "VMware Horizon Agent"
            ProductId   = "0C94FB1A-6358-47FC-A3AE-3CA4F6C72C5E"
            Arguments   = '/s /v "/qn /l c:\temp\viewagentinstall.log VDM_VC_MANAGED_AGENT=1"'
            PSDSCRunAsCredential = $LocalAdmin
            DependsOn   = '[xComputer]SetName'

        }

        
  #      xUAC EnableUAC {
  #          Setting = 'AlwaysNotify'
  #      }



    }
} 