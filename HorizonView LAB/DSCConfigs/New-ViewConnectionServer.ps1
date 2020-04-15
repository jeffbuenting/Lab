
configuration New-ViewConnectionServer       
{             
   param             
    (                     
        [PSCredential]$DomainAdmin       
    )             
    
    Import-DscResource –ModuleName 'PSDesiredStateConfiguration' 
    Import-DscResource -ModuleName xComputerManagement  
    Import-DSCResource -moduleName NetworkingDSC
    Import-DSCResource -moduleName computermanagementdsc

    Node $AllNodes.Where{$_.Role -eq "ViewConnectionServer"}.Nodename             
    { 


        NetIPInterface DisableDhcpE1
        {
            InterfaceAlias = 'Ethernet0'
            AddressFamily  = 'IPv4'
            Dhcp           = 'Disabled'
        }


        IPAddress NewIPv4AddressE1
        {
            IPAddress      = $Node.IPAddress
            InterfaceAlias = 'Ethernet0'
            AddressFamily  = 'IPV4'
        }

        DefaultGatewayAddress SetDefaultGatewayE1
        {
            Address        = $Node.DefaultGateway
            InterfaceAlias = 'Ethernet0'
            AddressFamily  = 'IPv4'
        }

    # ----- DNS is set via powershell prior to running DSC because this does not seem to work.
    #    DnsServerAddress DNSE1
    #    {
    #        #Address        = $Node.DNSServer
    #        Address        = @(
    #            '10.10.10.10'
    #        )
    #        InterfaceAlias = 'Ethernet0'
    #        AddressFamily  = 'IPv4'
    #        Validate       = $true
    #    }

        xComputer SetName { 
            Name = $Node.NodeName 
            DomainName = $Node.DomainName
            Credential = $DomainAdmin
        }

        IEEnhancedSecurityConfiguration DisableESCAdmin {
            Enabled = $False
            Role = "Administrators"
        }


        # ----- Install Connection server
        # -----https://thevirtualist.org/automated-installation-vmware-view-components/
        # -----  C:\temp\VMware-Horizon-Connection-Server-x86_64-7.12.0-15770369.exe /s /v "/qn /l c:\temp\viewinstall.log VDM_SERVER_INSTANCE_TYPE=1 INSTALLDIR=""C:\View"" FWCHOICE=1 VDM_SERVER_RECOVERY_PWD=mini VDM_SERVER_RECOVERY_PWD_REMINDER=""yep"""
        Package HorizonView {
            Ensure      = "Present"  
            Path        = "C:\temp\VMware-Horizon-Connection-Server-x86_64-7.12.0-15770369.exe"
            Name        = "VMware View Connection Server 7.12"
            ProductId   = "BA8F6334-CB3D-42C2-A6FF-C4A90A3314B7"
            Arguments   =  '/s /v "/qn /l c:\temp\viewinstall.log VDM_SERVER_INSTANCE_TYPE=1 INSTALLDIR=""C:\View"" FWCHOICE=1 VDM_SERVER_RECOVERY_PWD=mini VDM_SERVER_RECOVERY_PWD_REMINDER=""yep"""'
        }

    }
}