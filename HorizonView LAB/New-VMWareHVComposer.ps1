﻿<#
    .SYNOPSIS
        Install Composer service
    
#>


param (
    [Parameter (Mandatory = $True)]
    [String]$ComputerName,

    [Parameter (Mandatory = $True) ]
    [PSCredential]$DomainAdminn,

    [Parameter (Mandatory = $True) ]
    [PSCredential]$ComposerServiceAcct,

    [Parameter (Mandatory = $True) ]
    [String]$ADServer

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

## ----- Create Composer user
#if ( -Not ([bool](get-aduser -server $ADServer -Filter {SamAccountName -eq "$($ComposerServiceAcct.UserName)"} -Credential $DomainAdmin) ) ) {
#    Write-Verbose "Creating vCenter AD User for Connection Server"
#
#    New-ADUser -Server $ADServer -Credential $DomainAdmin -Name $ComposerServiceAcct.UserName -Description "ComposerService" -Path ServiceAcct -AccountPassword $ComposerServic.Password -Enabled $True
#}

# ----- Create SQL DB for the Composer Service
Write-Verbose "Creating DB for the COmposer Servce : $ComposerDB"


$CreateDB = @"
    import-module sqlserver

    if ( -Not (Get-SQLDatabase -Name $ComposerDB -ServerInstance $ComputerName -ErrorAction SilentlyContinue) ) {
        Write-Output 'Creating DB'
        # create object and database  
        invoke-sqlcmd -Query "CREATE DATABASE $ComposerDB" 
    }
    Else {
        Write-Output 'DB already exists'
    }
"@

Invoke-VMScript -VM $VM -GuestCredential $DomainAdmin -scripttext $CreateDB 

# ----- Create role and add Composer user to role
$DBRole = @"
    import-module sqlserver

    # ----- Add Login to SQL 
    if ( -not ( Get-SQLLogin -Name $($ComposerServiceAcct.UserName) -ServerInstance $ComputerName -ErrorAction SilentlyContinue) ) {
        Write-Output ""Add login $($ComposerServiceAcct.UserName)""
        Add-SQLLogin -ServerInstance $ComputerName -LoginName $($ComposerServiceAcct.UserName) -LoginType WindowsUser
    }
    Else {
        Write-Output 'Login already exists'
    }

    # ----- Add login to DB
    `$DB = Get-SQLDatabase -ServerInstance $ComputerName -Name $ComposerDB
    if ( -not ( `$DB.Users.Contains( '$($ComposerServiceAcct.UserName)') ) ) {
        Write-Output ""Add login to DB $($ComposerServiceAcct.UserName)""
        `$User = New-Object ('Microsoft.SqlServer.Management.Smo.User') (`$DB, '$($ComposerServiceAcct.UserName)')
        `$user.Login = '$($ComposerServiceAcct.UserName)'
        `$user.Create()
    }
    Else {
        Write-Output 'Login already exists'
    }

    # ----- Create Role
    `$DB = Get-SQLDatabase -ServerInstance $ComputerName -Name $ComposerDB

    if ( -Not (`$DB.Roles['VCMP_ADMIN_ROLE']) ) {
        Write-Output 'Creating Role'
        `$Role = New-Object -TypeName "Microsoft.SqlServer.Management.SMO.DatabaseRole" (`$DB, 'VCMP_ADMIN_ROLE')
        `$Role.Create()
    }
    Else {
        Write-Output 'Role already exists'
    }

    # ----- Add login to role
    `$DB = Get-SQLDatabase -ServerInstance $ComputerName -Name $ComposerDB

   if ( (`$DB.Roles['VCMP_ADMIN_ROLE']).EnumMembers() -notContains '$($ComposerServiceAcct.username)' ) {
       Write-Output 'Adding user to role'
  
      # Add-RoleMember -DB $ComposerDB -RoleName 'VCMP_ADMIN_ROLE' -MemberName $($ComposerServiceAcct.username)
  
      (`$DB.Roles['VCMP_ADMIN_ROLE']).AddMember( '$($ComposerServiceAcct.username)')

   }
   Else {
       Write-Output 'Login already a member of role'
   }


"@

Invoke-VMScript -VM $VM -GuestCredential $DomainAdmin -scripttext $DBRole 



# ----- Cleanup
