
# ----- Configure DHCP Settings
$DHCPServer = 'KW-DC1'

$VM = Get-VM -Name $DHCPServer

Invoke-VMScript -vm $VM -ScriptType Powershell -ScriptText 'Add-DhcpServerv4Reservation -ScopeId 10.10.10.0 -IPAddress 10.10.10.90 -ClientId "00-50-56-9f-67-fc" -Description "ESX90"' -GuestCredential $DomainAdmin

$CMD = @'
if ( -Not ( Get-DhcpServerv4OptionValue -ScopeId 10.10.10.0 -OptionID 66 -ErrorAction SilentlyContinue ) ) {
    Set-DhcpServerv4OptionValue  -ScopeId 10.10.10.0  -OptionId 66 -Value "10.10.10.1"
}

if ( -Not ( Get-DhcpServerv4OptionValue -ScopeId 10.10.10.0 -OptionID 67 -ErrorAction SilentlyContinue ) ) {
    Set-DhcpServerv4OptionValue  -ScopeId 10.10.10.0  -OptionId 67 -Value "undionly.kpxe.vmw-hardwired"
}
'@


Invoke-VMScript -vm $VM -ScriptType Powershell -GuestCredential $DomainAdmin -ScriptText $CMD