Function New-LABVM {

    [cmdletBinding()]
    param (
         [Parameter (Position = 0,Mandatory = $True,ParameterSetName = 'Template')]
         [Parameter (Position = 0,Mandatory = $True,ParameterSetName = 'ISO')]
         [String]$VMName,
  
         [Parameter (Position = 1, Mandatory = $True,ParameterSetName = 'Template')]
         [Parameter (Position = 1,Mandatory = $True,ParameterSetName = 'ISO')]
         [String]$ESXHost,
     
         [Parameter (ParameterSetName = 'Template')]
         [String]$Template,

 #        [Parameter (ParameterSetName = 'ISO')]
 #        [String]$ISO,

         [Parameter (ParameterSetName = 'Template')]
         [Parameter (ParameterSetName = 'ISO')]
         [String]$DataStore,

         [Parameter (ParameterSetName = 'Template')]
         [Parameter (ParameterSetName = 'ISO')]
         [String]$ResourcePool,

         [Parameter (ParameterSetName = 'Template')]
         [Parameter (ParameterSetName = 'ISO')]
         [String]$Location,
  
         [Parameter (Mandatory = $True,ParameterSetName = 'Template')]
         [String]$OSCustomization,
  
         [Parameter (Mandatory = $True,ParameterSetName = 'Template')]
         [Parameter (Mandatory = $True,ParameterSetName = 'ISO')]
         [String]$VMSwitch,
  
         [Parameter (Mandatory = $True,ParameterSetName = 'Template')]
         [Parameter (Mandatory = $True,ParameterSetName = 'ISO')]
         [String]$PortGroup,
  
         [Parameter (ParameterSetName = 'Template')]
         [Parameter (ParameterSetName = 'ISO')]
         [String]$CPU = 2,
  
         [Parameter (ParameterSetName = 'Template')]
         [Parameter (ParameterSetName = 'ISO')]
         [String]$Memory = 2,
  
         [Parameter (Mandatory = $True,ParameterSetName = 'Template')]
         [PSCredential]$LocalAdmin,
  
         [Parameter (ParameterSetName = 'Template')]
         [Parameter (ParameterSetName = 'ISO')]
         [Int]$Timeout = 900,

         [Parameter (ParameterSetName = 'Template')]
         [Parameter (ParameterSetName = 'ISO')]
         [switch]$NoDHCP

    )

    DynamicParam     {
        if ( $NoDHCP ) {
            
            # ----- IPAddress
            $IPAddressAttribute = New-Object System.Management.Automation.ParameterAttribute
            $IPAddressAttribute.ParameterSetName = 'Template'
            $IPAddressAttribute.ParameterSetName = 'ISO'
            $IPAddressAttribute.Mandatory = $true
            
            $attributeCollection = new-object System.Collections.ObjectModel.Collection[System.Attribute]
            $attributeCollection.Add($IPAddressAttribute)
            
            $IPAddressParam = New-Object System.Management.Automation.RuntimeDefinedParameter('IPAddress', [Int16], $attributeCollection)
 
            #expose the name of our parameter
            $paramDictionary = New-Object System.Management.Automation.RuntimeDefinedParameterDictionary
            $paramDictionary.Add('IPAddress', $IPAddressParam)
            
            # ----- SubnetMask
            $SubnetMaskAttribute = New-Object System.Management.Automation.ParameterAttribute
            $SubnetMaskAttribute.ParameterSetName = 'Template'
            $SubnetMaskAttribute.ParameterSetName = 'ISO'
            $SubnetMaskAttribute.Mandatory = $true
            
            $attributeCollection = new-object System.Collections.ObjectModel.Collection[System.Attribute]
            $attributeCollection.Add($SubnetMaskAttribute)
            
            $SubnetMaskParam = New-Object System.Management.Automation.RuntimeDefinedParameter('SubnetMask', [Int16], $attributeCollection)
 
            #expose the name of our parameter
            $paramDictionary = New-Object System.Management.Automation.RuntimeDefinedParameterDictionary
            $paramDictionary.Add('SubnetMask', $SubnetMaskParam)
            
            # ----- DefaultGateway
            $DefaultGatewayAttribute = New-Object System.Management.Automation.ParameterAttribute
            $DefaultGatewayAttribute.ParameterSetName = 'Template'
            $DefaultGatewayAttribute.ParameterSetName = 'ISO'
            $DefaultGatewayAttribute.Mandatory = $true
            
            $attributeCollection = new-object System.Collections.ObjectModel.Collection[System.Attribute]
            $attributeCollection.Add($DefaultGatewayAttribute)
            
            $DefaultGatewayParam = New-Object System.Management.Automation.RuntimeDefinedParameter('DefaultGateway', [Int16], $attributeCollection)
 
            #expose the name of our parameter
            $paramDictionary = New-Object System.Management.Automation.RuntimeDefinedParameterDictionary
            $paramDictionary.Add('DefaultGateway', $DefaultGatewayParam)

            # ----- DNSServer
            $DNSServerAttribute = New-Object System.Management.Automation.ParameterAttribute
            $DNSServerAttribute.ParameterSetName = 'Template'
            $DNSServerAttribute.ParameterSetName = 'ISO'
            $DNSServerAttribute.Mandatory = $true
            
            $attributeCollection = new-object System.Collections.ObjectModel.Collection[System.Attribute]
            $attributeCollection.Add($DNSServerAttribute)
            
            $DNSServerParam = New-Object System.Management.Automation.RuntimeDefinedParameter('DNSServer', [Int16], $attributeCollection)
 
            #expose the name of our parameter
            $paramDictionary = New-Object System.Management.Automation.RuntimeDefinedParameterDictionary
            $paramDictionary.Add('DNSServer', $DNSServerParam)

            
            return $paramDictionary  

        }
    }

    Process {

        Try {
            # ----- Create the VM.  In this case we are building from a VM Template.  But this could be modified to be from an ISO.
            if ( -Not ( Get-VM -Name $VMName -ErrorAction SilentlyContinue ) ) {
            
                Write-Verbose "Creating VM"
        #        Write-Verbose "ParameterSetName = $($PSCmdlet.ParameterSetName)"
                    

                        Write-Verbose "Building with Template"

                        # ----- Resource and Location are not required.  Need to account for this if someones environment does not use them.
                        if ( $ResourcePool -and -not $Location ) { $Location = $ResourcePool }

                        if ( -Not $ResourcePool ) {
                            $task = New-VM -Name $VMName -Template $Template -vmhost $ESXHost -Datastore $DataStore -Location $Location -OSCustomizationSpec $OSCustomization -ErrorAction Stop -RunAsync
                        }
                        Else {
                            $task = New-VM -Name $VMName -Template $Template -vmhost $ESXHost -Datastore $DataStore -ResourcePool $ResourcePool -Location $Location -OSCustomizationSpec $OSCustomization -ErrorAction Stop -RunAsync
                        }
                        Write-Verbose "waiting for new-vm to complete"
  
                        Write-Verbose "Task State = $($Task.State )"
                        while ( $Task.state -ne 'Success' ) {
                            Start-Sleep -Seconds 15
  
                            Write-Verbose "Still waiting for new-vm to complete"
  
                            $Task = Get-Task -Id $Task.Id -Verbose:$False
                            Write-Verbose "Task State = $($Task.State)"
                        }

                        write-verbose "VM done"

    
                
            }
            Else {
                Write-Verbose "VM already exists.  Continuing to configuration"
            }    

        }
        Catch {
            $ExceptionMessage = $_.Exception.Message
            $ExceptionType = $_.Exception.GetType().Fullname
            Throw "New-LABVM : Error building the VM.`n`n     $ExceptionMessage`n`n $ExceptionType"
        }

        $VM = Get-VM -Name $VMName 

        $Reboot = $False

        Try {
 
            # ----- Attach the VM to the portgroup
            $VMNIC = Get-NetworkAdapter -VM $VM -ErrorAction Stop

            if ( $VMNIC.NetworkName -ne $PortGroup ) {
                Write-verbose "Attaching NIC to correct network : $PortGroup"

                $VPortgroup = Get-VirtualPortGroup -VMHost $ESXHost -VirtualSwitch $VMSwitch -Name $PortGroup -ErrorAction Stop 

                Get-NetworkAdapter -vm $VM -ErrorAction Stop | Set-NetworkAdapter -Portgroup $VPortgroup -Confirm:$False -ErrorAction Stop
                $Reboot = $True
            }
            Else {
                Write-Verbose "NIC already attached to $PortGroup"
            }

            if ( ($VM.NUMCPU -ne $CPU) -or ($VM.MemoryGB -ne $Memory) ) {
                Write-Verbose "Modifying CPU and memory"

                Set-VM -VM $VM -NumCpu $CPU -MemoryGB $Memory -confirm:$False
                $Reboot = $True
            }
            Else {
                Write-Verbose "CPU and Memory set correctly"
            }
     
            if ( $VM.PowerState -eq 'PoweredOff') {

                        Write-Verbose "Starting VM and wait for VM Tools to start."
                        $VM = Start-VM -VM $VM -ErrorAction Stop | Wait-Tools
  
                        Write-Verbose "Waiting for OS Custumizations to complete after the VM has powered on."
                        wait-vmwareoscustomization -vm $VM -Timeout $Timeout -Verbose:$IsVerbose
  
                        Wait-Tools -VM $VM

            }
            Else {
                if ( $Reboot ) {
                    Write-Verbose "Restarting VM"

                    Restart-VM -VM $VM -Confirm:$False | Wait-Tools
                }
                Else {
                    Write-Verbose "Restart not needed"
                }
            }
 
            Write-Verbose "Getting VM INfo"
            # ----- reget the VM info.  passing the info via the start-vm cmd is not working it would seem.
            $VM = Get-VM -Name $VMName -ErrorAction Stop
 
            # ----- Sometimes the VM hostname and IPAddress to be correct does not get filled in.  Waiting for a bit and trying again.
            $Timeout = 10
 
            $Trys = 0
            Do  {
                Write-Verbose "Pausing ..."
                Sleep -Seconds 60
 
                $VM = Get-VM -Name $VMName -ErrorAction Stop
 
                $Trys++
 
                Write-Verbose "HostName = $($VM.Guest.HostName)"
                Write-Verbose "IP = $($VM.Guest.IPAddress)"
                Write-Verbose "Trys = $Trys of $Timeout"
            } while ( ( -Not $VM.Guest.HostName ) -and ( $VM.Guest.IPAddress[0] -notmatch '\d{1,3].\d{1,3].\d{1,3].\d{1,3]}') -and ($Trys -lt $Timeout ) )
 
            if ( $Trys -eq $Timeout ) { Throw "New-LABVM : TimeOut getting VM info" }
 
            # ----- and because we don't have a DHCP server on this network we need to apply an IP
            if ( $NoDHCP ) {
                Write-Verbose "Assigning Static IP because we don't have DHCP"
                $netsh = “c:\windows\system32\netsh.exe interface ip set address name=""Ethernet0"" static $IPAddress $SubnetMask $DefaultGateway"
                Invoke-VMScript –VM $VM  -GuestCredential $LocalAdmin -ScriptType bat -ScriptText $netsh -ErrorAction Stop
 
                # ----- Set DNS
                Write-Verbose "DNS -------------------------------------"
                $DNS = "c:\windows\system32\netsh.exe interface ipv4 set dns name=""Ethernet0"" static $DNSServer"
                Invoke-VMScript –VM $VM  -GuestCredential $LocalAdmin -ScriptType bat -ScriptText $DNS -ErrorAction Stop
            }
        }
        Catch {
            $ExceptionMessage = $_.Exception.Message
            $ExceptionType = $_.Exception.GetType().Fullname
            Throw "New-LABVM : Error Configuring the VM.`n`n     $ExceptionMessage`n`n $ExceptionType"
        }

        Write-Verbose "VM Created and Configured"
    }
}