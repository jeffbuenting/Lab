
configuration New-LABTFTPServer             
{                        
    
    Import-DscResource –ModuleName 'PSDesiredStateConfiguration'
    Import-DSCResource -ModuleName NetworkingDsc

    Node $AllNodes.Where{$_.Role -eq "TFTP"}.Nodename             
    { 

        Package SolarWindsTFTP
        {
            Ensure = "Present"
            Name = 'SolarWinds TFTP Server'
            Path = "c:\temp\tftpinstaller.msi"
            ProductId = "470DF489-BA3A-410B-B902-11E287D81BC6"
        }



  #      WindowsFeature TFTP
  #      {
  #          Ensure = "Present"
  #          Name = "WDS-Transport"
  #      }
  #
  #      WindowsFeature WDSTools
  #      {
  #          Ensure = "Present"
  #          Name = "WDS-adminpack"
  #      }
  #
  #      File CreatreRootFolder {
  #          Type = 'Directory'
  #          DestinationPath = $Node.TFTPRoot
  #          Ensure = "Present"
  #      }
  #
  #      Registry TFTPRootFolder {
  #
  #          Ensure = "Present"
  #          Key = "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\services\WDSServer\Providers\WDSTFTP"
  #          ValueName = "RootFolder"
  #          ValueData = $Node.TFTPRoot
  #          ValueType = "String" 
  #      }
  #
  #      Service "WDSServer(TFTP)"
  #      {
  #          Name = 'WDSServer'
  #          StartupType = 'Automatic'
  #          State = 'Running'
  #      }
  #
  #      Firewall AddFirewallRule
  #      {
  #          Name                  = 'TFTP Inbound UDP 69'
  #          DisplayName           = 'TFTP Allow inbound UDP 69'
  #          Ensure                = 'Present'
  #          Enabled               = 'True'
  #          Profile               = ('Domain', 'Private','Public')
  #          Direction             = 'Inbound'
  #          RemotePort            = ('69')
  #          LocalPort             = ('69')
  #          Protocol              = 'UDP'
  #          Description           = 'TFTP Inbound UDP 69'
  #          RemoteAddress         = $Node.IPRange
  #      }
  #       
    }

}
           
            
 

