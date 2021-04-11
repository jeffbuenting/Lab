
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

        File Scripts {
            Ensure = 'Present'
            Type = 'Directory'
            DestinationPath = 'c:\Scripts'
            DependsOn = '[PowerShellExecutionPolicy]ExecutionPolicy'
        }

 #      # ----- Because I can't use an expression in a Using stement
 #      $UName = $ShareDriveCred.UserName
 #      $PW = $ShareDriveCred.GetNetworkCredential().Password
 #      $Path = $Node.Share

        Script MappDrive {
            GetScript = { @{ Result = (Get-Content C:\scripts\New-VDIMappedDrive.ps1) } }
            TestScript = { Test-Path "C:\scripts\New-VDIMappedDrive.ps1" }
            SetScript = {
                "Param (" | Out-File -FilePath c:\scripts\New-VDIMappedDrive.ps1
                "     [String]`$UserName," | Out-File -FilePath c:\scripts\New-VDIMappedDrive.ps1 -Append
                "     [String]`$Password," | Out-File -FilePath c:\scripts\New-VDIMappedDrive.ps1 -Append
                "     [String]`$Path" | Out-File -FilePath c:\scripts\New-VDIMappedDrive.ps1 -Append
                ")" | Out-File -FilePath c:\scripts\New-VDIMappedDrive.ps1 -Append
                """Begin mapping drive to $Path"" | Out-File -FilePath c:\scripts\New-VDIMappedDrive.log" | Out-File -FilePath c:\scripts\New-VDIMappedDrive.ps1 -Append
                "`$Cred = New-Object System.Management.Automation.PSCredential (""`$UserName"", `$(ConvertTo-SecureString `$Password -AsPlainText -Force))" | Out-File -FilePath c:\scripts\New-VDIMappedDrive.ps1 -append
                "try {" | Out-File -FilePath c:\scripts\New-VDIMappedDrive.ps1 -Append
                "     New-PSDrive -Name P -PSProvider FileSystem -Root `$Path -Credential `$Cred -Persist -Scope Global -ErrorAction stop" | Out-File -FilePath c:\scripts\New-VDIMappedDrive.ps1 -Append
                "}" | Out-File -FilePath c:\scripts\New-VDIMappedDrive.ps1 -Append
                "Catch {" | Out-File -FilePath c:\scripts\New-VDIMappedDrive.ps1 -Append
                "     ""Error : $($_.Exception.Message)"" | Out-File -FilePath c:\scripts\New-VDIMappedDrive.log" | Out-File -FilePath c:\scripts\New-VDIMappedDrive.ps1 -Append
                "}" | Out-File -FilePath c:\scripts\New-VDIMappedDrive.ps1 -Append
            }
            DependsOn = '[File]Scripts'
        }

        # ----- Move-Shortcut script
        File Scripts {
            Ensure = 'Present'
            Type = 'File'
            SourcePath = $Node.MoveShortcutScript
            DestinationPath = 'c:\Scripts'
            DependsOn = '[File]Scripts'
        }

        # ----- Remove Hi wizard
        Registry Hi {
            Key = 'HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System'
            ValueName = 'EnableFirstLogonAnimation'
            ValueData = 0
            ValueType = 'Dword' 
            Ensure = 'Present'
        }

        # ----- Optimize Image
        # https://docs.microsoft.com/en-us/windows-server/remote/remote-desktop-services/rds_vdi-recommendations-1909
        # https://github.com/The-Virtual-Desktop-Team/Virtual-Desktop-Optimization-Tool

        File OptimzeCode {
            Ensure = 'Present'
            Type = 'File'
            SourcePath = "$($Node.Source)\Virtual-Desktop-Optimization-Tool-master"
            DestinationPath = 'c:\Optimize'
            Recurse = $True
            DependsOn = '[PowerShellExecutionPolicy]ExecutionPolicy'
        }

        Script MappDrive {
            GetScript = { @{ Result = (Get-Content c:\optimized\Win10_VirtualDesktop_Optimize.ps1) } }
            TestScript = { $False }
            SetScript = {
                .\Win10_VirtualDesktop_Optimize.ps1 -WindowsVersion 1909 -Verbose
            }
            DependsOn = '[File]OptimzeCode'
        }



   #     Registry RunOnce {
   #         Key = 'HKEY_LOCAL_MACHINE\Software\Microsoft\Windows\CurrentVersion\Run'
   #         ValueName = 'Set-VDIDesktop'
   #         ValueData = 'Powershell.exe -command c:\scripts\Set-VDIDesktop.ps1 -Noexit'
   #         ValueType = 'String' 
   #         Ensure = 'Present'
   #     }

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

        Service VMWareLogonMonitor
        {
            Name        = "vmlm"
            StartupType = "Automatic"
            State       = "Running"
            DependsOn   = '[Package]HorizonView'
        }


        # ----- VMWare OSOT
        File VOSOT {
            Ensure = 'Present'
            Type = 'File'
            SourcePath = "$($Node.Source)\VMWare\VMWareOSOT"
            DestinationPath = 'c:\Optimize\VMwareOSOT'
            Recurse = $True
            DependsOn = '[PowerShellExecutionPolicy]ExecutionPolicy'
        }

        # ----- VOSOT Template
        File VOSOTTemplate {
            Ensure = 'Present'
            Type = 'File'
            SourcePath = $Node.VOSOTTemplate
            DestinationPath = 'c:\Optimize\VMwareOSOT'
            DependsOn = '[PowerShellExecutionPolicy]ExecutionPolicy'
        }

        Script RunVOSOT {
            GetScript = { @{ Result = $True } }
            TestScript = { $False }
            SetScript = {
                Start-Process -FilePath c:\Optimize\VMwareOSOT\VMwareOSOptimizationTool.exe -ArgumentList "-v -o -t c:\Optimize\VMwareOSOT\VMwareOSOptimizationTool.exe.config c:\Optimize\VMwareOSOT\$($Node.VOSOTTemplate)" -passthru -wait -NoNewWindow
            }
            DependsOn = '[File]VOSOTTemplate','[File]VOSOT'
        }


        
  #      xUAC EnableUAC {
  #          Setting = 'AlwaysNotify'
  #      }



    }
} 