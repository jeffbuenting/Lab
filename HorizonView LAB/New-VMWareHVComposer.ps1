<#
    .SYNOPSIS
        Install Composer service
    
#>


param (
    [Parameter (Mandatory = $True)]
    [String]$ComputerName,

    [String]$SQLServer = $ComputerName,

    [Parameter (Mandatory = $True) ]
    [PSCredential]$DomainAdminn

)

$ComposerDB = "ComposerDB"

Try {
    $VM = Get-VM -Name $SQLServer -ErrorAction Stop
}
Catch {
    $ExceptionMessage = $_.Exception.Message
    $ExceptionType = $_.Exception.GetType().Fullname
    Throw "New-VMWareHVComposer : Can't get VM.`n`n     $ExceptionMessage`n`n $ExceptionType"
}

# ----- Create SQL DB for the Composer Service
Write-Verbose "Creating DB for the COmposer Servce : $ComposerDB"


#$CreateDB = @"
#    # create object and database  
#  #  $db = New-Object -TypeName Microsoft.SqlServer.Management.Smo.Database -Argumentlist $SQLServer, $ComposerDB 
#
# #   write-output ""$($DB | Out-string)""
#    #$db.Create()  
#"@

$CreateDB = @"
    $db = 'Hello'
"@

Invoke-VMScript -VM $VM -GuestCredential $DomainAdmin -scripttext $CreateDB 



# ----- Cleanup
