
configuration New-ViewMasterVM      
{             
  param             
    (                     
        [PSCredential]$LocalAdmin,
        
        [PSCredential]$ShareDriveCred   
    )             
 

    Import-DscResource –ModuleName 'PSDesiredStateConfiguration' 
    Import-DscResource -ModuleName ComputerManagementDSC  
    Import-DSCResource -moduleName NetworkingDSC

    Node $AllNodes.Where{$_.Role -eq "MasterImage"}.Nodename             
    { 


         DNSServerAddress DNSE0 {
            InterfaceAlias = 'Ethernet0'
            AddressFamily = 'IPv4'
            Address = $Node.DNSServer
        }

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

        Computer SetName { 
            Name = $Node.NodeName 
        }

        PowerShellExecutionPolicy ExecutionPolicy
        {
            ExecutionPolicyScope = 'LocalMachine'
            ExecutionPolicy      = 'Unrestricted'
        }

        Script SetupScript {
            GetScript = { @{ Result = (Get-Content C:\scripts\Set-VDIDesktop.ps1) } }
            TestScript = { Test-Path "C:\scripts\Set-VDIDesktop.ps1" }
            SetScript = {
                $MapDrive = @"
                    $Cred = New-Object System.Management.Automation.PSCredential ($ShareDriveCred.UserName, $(ConvertTo-SecureString $ShareDriveCred.GetNetworkCredentials().Password -AsPlainText -Force))

                    New-PSDrive -Name p -PSProvider FileSystem -Root $Path -Credential $Cred -Persist -ErrorAction stop
"@

                    $MapDrive | Out-File -FilePath c:\scripts\Set-VDIDesktop.ps1
            }
            DependsOn = '[PowerShellExecutionPolicy]ExecutionPolicy'
        }

        # ----- Remove Hi wizard
        Registry Hi {
            Key = 'HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System'
            ValueName = 'EnableFirstLogonAnimation'
            ValueData = 0
            ValueType = 'Dword' 
            Ensure = 'Absent'
        }

        Registry RunOnce {
            Key = 'HKEY_LOCAL_MACHINE\Software\Microsoft\Windows\CurrentVersion\Run'
            ValueName = 'Set-VDIDesktop'
            ValueData = 'Powershell.exe -command c:\scripts\Set-VDIDesktop.ps1 '
            ValueType = 'String' 
            Ensure = 'Present'
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
            DependsOn   = '[Computer]SetName'

        }

        
  #      xUAC EnableUAC {
  #          Setting = 'AlwaysNotify'
  #      }



    }
} 