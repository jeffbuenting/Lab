configuration New-HVThinAppMachine     
{             
            
 

    Import-DscResource –ModuleName 'PSDesiredStateConfiguration' 
    Import-DscResource -ModuleName ComputerManagementDSC  
    Import-DSCResource -moduleName NetworkingDSC

    Node $AllNodes.Where{$_.Role -eq "ThinApp"}.Nodename             
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
            DependsOn = "[NetIPInterface]DisableDhcpE0"
        }

        DefaultGatewayAddress SetDefaultGatewayE0
        {
            Address        = $Node.DefaultGateway
            InterfaceAlias = 'Ethernet0'
            AddressFamily  = 'IPv4'
            DependsOn = "[IPAddress]NewIPv4AddressE0"
        }

         DNSServerAddress DNSE0 {
            InterfaceAlias = 'Ethernet0'
            AddressFamily = 'IPv4'
            Address = $Node.DNSServer
            DependsOn = "[DefaultGatewayAddress]SetDefaultGatewayE0"
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

         RemoteDesktopAdmin EnableRDP {
            IsSingleInstance   = 'yes'
            Ensure             = 'Present'
            UserAuthentication = 'NonSecure'
         }

        Computer SetName { 
            Name = $Node.NodeName 
        }
  
        PowerShellExecutionPolicy ExecutionPolicy
        {
            ExecutionPolicyScope = 'LocalMachine'
            ExecutionPolicy      = 'Unrestricted'
        }

        Script SleepSettings {
            GetScript = { & powercfg.exe /? }
            SetScript = {
                Powercfg /Change monitor-timeout-ac 60
                Powercfg /Change monitor-timeout-dc 0
                Powercfg /Change standby-timeout-ac 0
                Powercfg /Change standby-timeout-dc 0
            }
            TestScript = { $False }
        }

        File Scripts {
            Ensure = 'Present'
            Type = 'Directory'
            DestinationPath = 'c:\Scripts'
            DependsOn = '[PowerShellExecutionPolicy]ExecutionPolicy'
        }

        # https://communities.vmware.com/thread/516322
        Package Thinapp {
            Ensure      = "Present"  
            Path        = '\\192.168.1.23\Source\VMware\VMware-ThinApp-Enterprise-5.2.6-14449759.exe'
            Name        = "ThinApp"
            #Arguments   = "/install /quiet /norestart /log c:\temp\ThinappInstall.log"
            Arguments   = "/install /quiet /norestart /log c:\temp\ThinappInstall.log /LicenseKey=x /LicenseDisplayName=Elektro"
            ProductId   = "7B411EA9-02EF-4B98-BA77-B98C61DE2062"
        }
    }

} 