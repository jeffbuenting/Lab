
configuration New-LABTFTPServer             
{                        
    
    Import-DscResource –ModuleName 'PSDesiredStateConfiguration'
    Import-DSCResource -ModuleName NetworkingDsc

    Node $AllNodes.Where{$_.Role -eq "TFTP"}.Nodename             
    { 

        WindowsFeature TFTP
        {
            Ensure = "Present"
            Name = "WDS-Transport"
        }

        WindowsFeature WDSTools
        {
            Ensure = "Present"
            Name = "WDS-adminpack"
        }

        File CreatreRootFolder {
            Type = 'Directory'
            DestinationPath = $Node.TFTPRoot
            Ensure = "Present"
        }

        Registry RootFolder {

            Ensure = "Present"
            Key = "HKLM:\SYSTEM\CurrentControlSet\services\WDSServer\Providers\WDSTFTP\RootFolder"
            ValueName = "Enabled"
            ValueData = $Node.TFTPRoot
            ValueType = "String" 
        }

        Service "WDSServer(TFTP)"
        {
            Name = 'WDSServer'
            StartupType = 'Automatic'
            State = 'Running'
        }

        Firewall AddFirewallRule
        {
            Name                  = 'TFTP Inbound UDP 69'
            DisplayName           = 'TFTP Allow inbound UDP 69'
            Ensure                = 'Present'
            Enabled               = 'True'
            Profile               = ('Domain', 'Private','Public')
            Direction             = 'Inbound'
            RemotePort            = ('69')
            LocalPort             = ('69')
            Protocol              = 'UDP'
            Description           = 'TFTP Inbound UDP 69'
        }
         
    }

}
           
            
 

