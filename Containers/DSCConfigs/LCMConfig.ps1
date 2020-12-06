[DSCLocalConfigurationManager()]
Configuration LCMConfig
{
   
    Node LCMConfig
    {
        Settings
        {
            RefreshMode = 'Push'
            ActionAfterReboot = 'ContinueConfiguration'            
            ConfigurationMode = 'ApplyOnly'            
            RebootNodeIfNeeded = $true 
        } 
    }
}