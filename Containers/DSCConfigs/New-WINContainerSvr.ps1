
configuration New-WINContainerSVR            
{             
   param             
    (        
        [PSCredential]$DomainAdmin            
    )             
    
    Import-DscResource –ModuleName 'PSDesiredStateConfiguration'
    Import-DscResource -ModuleName ComputerManagementDSC
    Import-DSCResource -moduleName NetworkingDSC
    Import-DSCResource -ModuleName xWindowsUpdate
    Import-DscResource -ModuleName xSystemSecurity
    Import-DSCResource -ModuleName xTimeZone

    Node $AllNodes.Where{$_.Role -eq "WinContainer"}.Nodename             
    { 


        NetIPInterface DisableDhcpE0
        {
            InterfaceAlias = 'Ethernet0 3'
            AddressFamily  = 'IPv4'
            Dhcp           = 'Disabled'
        }

        IPAddress NewIPv4AddressE0
        {
            IPAddress      = $Node.IPAddress
            InterfaceAlias = 'Ethernet0 3'
            AddressFamily  = 'IPV4'
            DependsOn = "[NetIPInterface]DisableDhcpE0"
        }

        DefaultGatewayAddress SetDefaultGatewayE0
        {
            Address        = $Node.DefaultGateway
            InterfaceAlias = 'Ethernet0 3'
            AddressFamily  = 'IPv4'
            DependsOn = "[IPAddress]NewIPv4AddressE0"
        }

         DNSServerAddress DNSE0 {
            InterfaceAlias = 'Ethernet0 3'
            AddressFamily = 'IPv4'
            Address = $Node.DNSServer
            DependsOn = "[DefaultGatewayAddress]SetDefaultGatewayE0"
        }

        xTimeZone EST {
            IsSingleInstance = 'Yes'
            TimeZone = 'Eastern Standard Time'
        }

        xIEEsc IESec {
            UserRole = 'Administrators'
            IsEnabled = $False
        }

        Computer SetName { 
            Name = $Node.NodeName 
            DomainName = $Node.DomainName
            Credential = $DomainAdmin
            DependsOn = "[DNSServerAddress]DNSE0","[xTimeZone]EST"
        }

        RemoteDesktopAdmin RDP {
            IsSingleInstance   = 'yes'
            Ensure             = 'Present'
            UserAuthentication = 'NonSecure'
        }

        # ----- TODO: Eventually need to figure out what other firewall ports to enable.  For now disabling firewall
        FirewallProfile DisableDomainFirewallProfile
        {
            Name = 'Domain'
            Enabled = 'False'
        }

        FirewallProfile DisablePrivateFirewallProfile
        {
            Name = 'Private'
            Enabled = 'False'
        }

        FirewallProfile DisablePublicFirewallProfile
        {
            Name = 'Public'
            Enabled = 'False'
        }

 #       Firewall 'Remote Desktop - User Mode (TCP-In)'
 #       {
 #           Name                  = 'Remote Desktop - User Mode (TCP-In)'
 #           Ensure                = 'Present'
 #           Enabled               = 'True'
 #       }
 #
 #       Firewall 'Remote Desktop - User Mode (UDP-In)'
 #       {
 #           Name                  = 'Remote Desktop - User Mode (UDP-In)'
 #           Ensure                = 'Present'
 #           Enabled               = 'True'
 #       }




        # ----- https://blog.sixeyed.com/getting-started-with-docker-on-windows-server-2019/

        WindowsFeature Containers
        {
             Name = 'Containers'
             Ensure = 'Present'
             DependsOn = "[Computer]SetName"
        }

        Script DockerMsftProvider {
            GetScript = { Get-Module -Name DockerMsftProviderer }
            SetScript = { Install-Module -Name DockerMsftProvider }
            TestScript = {
                $Module = Get-Module -Name DockerMsftProvider -ErrorAction SilentlyContinue 
                if ( $Module ) { $True } Else { $False }
            }
            DependsOn = "[WindowsFeature]Containers"
        }
       
        Script Docker {
            GetScript = { Get-Package -Name Docker }
            SetScript = { Install-Package -Name Docker -ProviderName DockerMsftProvider -Force  }
            TestScript = {
                #$True
                $Package = Get-Package -Name Docker -ErrorAction SIlentlyContinue
                if ( $Package ) { $True } Else { $False }
            }
            DependsOn = "[Script]DockerMsftProvider"
        }

        Service DockerService {
            Name = 'Docker'
            StartupType = 'Automatic'
            State = 'Running'
            DependsOn = "[Script]Docker"
        }

        # ----- Env DSC resource doesn't seem to be work for all users.  so using a script resource
        # https://codingbee.net/powershell/powershell-make-a-permanent-change-to-the-path-environment-variable
        Script DockerPath {
            GetScript = { (Get-ItemProperty -Path 'Registry::HKEY_LOCAL_MACHINE\System\CurrentControlSet\Control\Session Manager\Environment' -Name PATH).path }
            SetScript = { 
                $oldpath = (Get-ItemProperty -Path 'Registry::HKEY_LOCAL_MACHINE\System\CurrentControlSet\Control\Session Manager\Environment' -Name PATH).path
                $newpath = “$oldpath;C:\Program Files\Docker”
                Set-ItemProperty -Path 'Registry::HKEY_LOCAL_MACHINE\System\CurrentControlSet\Control\Session Manager\Environment' -Name PATH -Value $newPath
            }
            TestScript = {
                $oldpath = (Get-ItemProperty -Path 'Registry::HKEY_LOCAL_MACHINE\System\CurrentControlSet\Control\Session Manager\Environment' -Name PATH).path
                if ( $OldPath -notcontains 'C:\Program Files\Docker' ) { $False } Else { $True }
            }
            DependsOn = '[Service]DockerService'
        }

        # ----- Create or Join swarm if configured
        Script DockerSwarm {
            GetScript = { docker node ls }

            TestScript = {
                if (  $Node.SwarmName ) {
                    Write-Verbose "server Should be part of a swarm ...."
 
                    $SwarmNodes = docker node ls
                    if ( $SwarmNodes | Select-String -Pattern $Node.NodeName -Quiet ) {
                        Write-Verbose "... and it is."

                        $True
                    }
                    Else {
                        Write-Verbose "... and it is not."

                        $False
                    }    
                }
                Else {
                    Write-Verbose "Server will not be part of a swarm"
                    $True
                }
            }

            SetScript = {
                # ----- check if swarm has been created.  check share for existing information.  if not files exist then swam needs to be init.  otherwise use that info in the files to join swarm.
                if ( -not (Test-Path -Path $($NonNode.Source)\Configs\$($Node.SwarmName)) ) {
                    # ----- Swarm has not been initialized
                    docker swarm init --advertise-addr $Node.IPAddress

                    # ----- Create share and the join files
                    New-Item -Path $($NonNode.Source)\Configs\$($Node.SwarmName) -ItemType Directory

                    # ----- docker swarm join-token outputs more than the needed command.  line 2 is all we need
                    ( docker swarm join-token manager )[2] | ConverTo-SecureString | out-file $($NonNode.Source)\Configs\$($Node.SwarmName)\SwarmManagerJoin.txt
                    ( docker swarm join-token worker )[2] | ConverTo-SecureString | out-file $($NonNode.Source)\Configs\$($Node.SwarmName)\SwarmWorkerJoin.txt
                }
                Else {
                    # ----- Swarm initialized join swarm
                    if ( $Node.SwarmRole -eq 'Manager' ) {
                        $CMD = Get-Content -Path $($NonNode.Source)\Configs\$($Node.SwarmName)\SwarmManagerJoin.txt | ConvertFrom-SecureString
                    }
                    Else {
                        $CMD = Get-Content -Path $($NonNode.Source)\Configs\$($Node.SwarmName)\SwarmWorkerJoin.txt | ConvertFrom-SecureString 
                    }
    
                    Invoke-Command -ScriptBlock $CMD
                }
            }
        }
  
    }
 
}
           
            
 
 
 