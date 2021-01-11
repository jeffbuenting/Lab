
configuration New-WINContainerSVR            
{             
   param             
    (        
        [PSCredential]$DomainAdmin,
        
        [String]$IPAddress,
        
        [PSCredential]$SourceAcct         
    )             
    
    Import-DscResource –ModuleName 'PSDesiredStateConfiguration'
    Import-DscResource -ModuleName ComputerManagementDSC
    Import-DSCResource -moduleName NetworkingDSC
    Import-DSCResource -ModuleName xWindowsUpdate
    Import-DscResource -ModuleName xSystemSecurity
    Import-DSCResource -ModuleName xTimeZone

    Node $AllNodes.Where{$_.Role -eq "WinContainer"}.Nodename             
    { 

        if ( $IPAddress -ne $Node.IPAddress ) {
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
            DependsOn = "[xTimeZone]EST"
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
                # ----- basically if the folder exists docker is installed
                if ( test-path 'C:\Program Files\Docker\' ) { $True } Else { $False }
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
        # inspiration : https://github.com/pscripted/cDSCDockerSwarm
        # ----- because the DSC MOF is converted to a string, it can't read the variables passed.  So we need to make the actual scriptblock a string (remember to escape and such)
        # https://social.technet.microsoft.com/Forums/en-US/2eb97d67-f1fb-4857-8840-de9c4cb9cae0/dsc-configuration-data-for-script-resources?forum=winserverpowershell
        Script DockerSwarm {
            GetScript = @" 
                & 'C:\Program Files\Docker\docker.exe' info  
"@

            TestScript = @"
                Write-Verbose "SwarmName = $($Node.SwarmName)"

                
                if ( '$($Node.SwarmName)' ) {
                    Write-Verbose "server Should be part of a swarm ...." 

                    `$info = . "c:\program files\docker\docker.exe" info -f '{{ json . }}' | ConvertFrom-Json
                    if ( `$info.swarm.localnodestate -eq 'inactive' ) {
                        Write-Verbose "... and it is not."

                        `$False
                    }
                    Else {
                        Write-Verbose "... and it is."

                        `$True
                    }
                }
                Else {
                    Write-Verbose "Server will not be part of a swarm."
                    `$True
                }
"@

            SetScript = @"
                # ----- Can't use PSCredential so need to recreate in 
                `$ShareCred = New-Object System.Management.Automation.PSCredential ('$($SourceAcct.UserName)', `$(ConvertTo-SecureString '$($SourceAcct.GetNetworkCredential().Password)' -AsPlainText -Force))

                # ----- Map source drive
                Write-Verbose "Mapping to source config share."
                if ( -NOT ( Get-PSDrive -Name ConfigDrive -ErrorAction SilentlyContinue )) {
                    New-PSDrive -Name ConfigDrive -PSProvider FileSystem -Root "$($ConfigData.NonNode.Source)" -Credential `$ShareCred
                }

                # ----- check if swarm has been created.  check share for existing information.  if not files exist then swam needs to be init.  otherwise use that info in the files to join swarm.
                Write-Verbose "Checking if the config path exists: ConfigDrive:\Configs\$($Node.SwarmName)"
                
                if ( -not (Test-Path -Path 'ConfigDrive:\Configs\$($Node.SwarmName)') ) {
                    Write-Verbose "It does not, so the swarm does not exist yet."

                    # ----- Swarm has not been initialized
                    Write-Verbose "Swarm initialization."
                    . "c:\program files\docker\docker.exe" swarm init --advertise-addr $($Node.IPAddress)
       
                    # ----- Create share and the join files
                    Write-Verbose "Create Config files"
                    if ( -Not ( Test-Path  -Path ConfigDrive:\Configs\$($Node.SwarmName) ) ) { 
                        Write-Verbose "Config Path does not exits.  Creating it."

                            New-Item -Path ConfigDrive:\Configs\$($Node.SwarmName) -ItemType Directory -ErrorAction SilentlyContinue

                    }

                    Write-Verbose "Saving join commands."
                    `$JoinCMD = . "c:\program files\docker\docker.exe" swarm join-token manager
                    `$JoinCMD[2] | ConvertTo-SecureString -AsPlainText -Force | out-file 'ConfigDrive:\Configs\$($Node.SwarmName)\SwarmManagerJoin.txt'

                    `$JoinCMD = . "c:\program files\docker\docker.exe" swarm join-token worker
                    `$joinCMD[2] | ConvertTo-SecureString  -AsPlainText -Force | out-file 'ConfigDrive:\Configs\$($Node.SwarmName)\SwarmWorkerJoin.txt'
                
                }
                Else {
                    Write-Verbose "It does, so the swarm exists.  Joining..."

                    # ----- Swarm initialized join swarm
                    if ( $($Node.SwarmRole) -eq 'Manager' ) {
                        Write-Verbose "... as Manager."
       
                        `$CMD = "Get-Content -Path ConfigDrive:\Configs\$($Node.SwarmName)\SwarmManagerJoin.txt | ConvertFrom-SecureString"
                    }
                    Else {
                        Write-Verbose "... as Worker."
       
                        `$CMD = "Get-Content -Path ConfigDrive:\Configs\$($Node.SwarmName)\SwarmWorkerJoin.txt | ConvertFrom-SecureString"
                    }

                    Invoke-Command -ScriptBlock { `$CMD }

                    Remove-PSDrive ConfigDrive
                }               
"@
            DependsOn = "[Script]DockerPath"
        }
  
    }
 
}
           
            
 
 
 