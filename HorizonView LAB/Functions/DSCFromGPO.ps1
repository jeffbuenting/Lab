
Configuration DSCFromGPO
{

	Import-DSCResource -ModuleName 'PSDesiredStateConfiguration'
	Import-DSCResource -ModuleName 'AuditPolicyDSC'
	Import-DSCResource -ModuleName 'SecurityPolicyDSC'
	# Module Not Found: Import-DSCResource -ModuleName 'PowerShellAccessControl'
	Node localhost
	{
         Registry 'Registry(XML): HKLM:\Software\Microsoft\Windows\CurrentVersion\Run\New-VDIMappedDrive'
         {
              ValueName = 'New-VDIMappedDrive'
              ValueType = 'String'
              Key = 'HKLM:\Software\Microsoft\Windows\CurrentVersion\Run'
              ValueData = 

         }

	}
}
DSCFromGPO -OutputPath 'c:\scripts\lab'
