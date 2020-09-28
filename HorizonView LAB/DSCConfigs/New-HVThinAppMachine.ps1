configuration New-HVThinAppMachine     
{             
            
 

    Import-DscResource –ModuleName 'PSDesiredStateConfiguration' 
    Import-DscResource -ModuleName ComputerManagementDSC  
    Import-DSCResource -moduleName NetworkingDSC

    Node $AllNodes.Where{$_.Role -eq "ThinApp"}.Nodename             
    { 

        TimeZone EST {
            IsSingleInstance = 'Yes'
            TimeZone = 'Eastern Standard Time'
        }
  
        IEEnhancedSecurityConfiguration IESecAdmin {
            Role = 'Administrators'
            Enabled = $False
            SuppressRestart = $True
        }

        IEEnhancedSecurityConfiguration IESecUsers {
            Role = 'Users'
            Enabled = $False
            SuppressRestart = $True
        }

         RemoteDesktopAdmin EnableRDP {
            IsSingleInstance   = 'yes'
            Ensure             = 'Present'
            UserAuthentication = 'NonSecure'
         }

  ##      Computer SetName { 
  #          Name = $Node.NodeName 
  #      }
  #
        PowerShellExecutionPolicy ExecutionPolicy
        {
            ExecutionPolicyScope = 'LocalMachine'
            ExecutionPolicy      = 'Unrestricted'
        }

        File Scripts {
            Ensure = 'Present'
            Type = 'Directory'
            DestinationPath = 'c:\Scripts'
            DependsOn = '[PowerShellExecutionPolicy]ExecutionPolicy'
        }
    }

} 