<#
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


# https://docs.vmware.com/en/VMware-Horizon-7/7.2/com.vmware.horizon-view.installation.doc/GUID-4CF63F93-8AEC-4840-9EEF-2D60F3E6C6D1.html
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

# ----- Create VCMP_ADMIN role and add Composer user to role
Write-Verbose "Create and Config VCMP_ADMIN_ROLE on $ComposerDB"

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

    # ----- Grant Permissions
    Invoke-Sqlcmd -ServerInstance $ComputerName -Database $ComposerDB -Query "GRANT ALTER,REFERENCES,INSERT ON SCHEMA::dbo TO VCMP_ADMIN_ROLE"
    Invoke-Sqlcmd -ServerInstance $ComputerName -Database $ComposerDB -Query "GRANT CREATE TABLE,CREATE VIEW,CREATE PROCEDURE TO VCMP_ADMIN_ROLE"

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

# ----- Create VCMP_USER role and add Composer user to role
Write-Verbose "Create and Config VCMP_USER_ROLE on $ComposerDB"

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

    if ( -Not (`$DB.Roles['VCMP_USER_ROLE']) ) {
        Write-Output 'Creating Role'
        `$Role = New-Object -TypeName "Microsoft.SqlServer.Management.SMO.DatabaseRole" (`$DB, 'VCMP_USER_ROLE')
        `$Role.Create()
    }
    Else {
        Write-Output 'Role already exists'
    }

    # ----- Grant Permissions
    Invoke-Sqlcmd -ServerInstance $ComputerName -Database $ComposerDB -Query "GRANT SELECT,INSERT,zDELEZTE,UPDATE,EXECUTE ON SCHEMA::dbo TO VCMP_USER_ROLE"

    # ----- Add login to role
    `$DB = Get-SQLDatabase -ServerInstance $ComputerName -Name $ComposerDB

   if ( (`$DB.Roles['VCMP_USER_ROLE']).EnumMembers() -notContains '$($ComposerServiceAcct.username)' ) {
       Write-Output 'Adding user to role'
  
      # Add-RoleMember -DB $ComposerDB -RoleName 'VCMP_ADMIN_ROLE' -MemberName $($ComposerServiceAcct.username)
  
      (`$DB.Roles['VCMP_USER_ROLE']).AddMember( '$($ComposerServiceAcct.username)')

   }
   Else {
       Write-Output 'Login already a member of role'
   }


"@

Invoke-VMScript -VM $VM -GuestCredential $DomainAdmin -scripttext $DBRole 

# ----- Create VCMP_ADMIN role and add Composer user to role
Write-Verbose "Create and Config VCMP_ADMIN_ROLE on MSDB"

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
    `$DB = Get-SQLDatabase -ServerInstance $ComputerName -Name MSDB
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
    `$DB = Get-SQLDatabase -ServerInstance $ComputerName -Name MSDB

    if ( -Not (`$DB.Roles['VCMP_ADMIN_ROLE']) ) {
        Write-Output 'Creating Role'
        `$Role = New-Object -TypeName "Microsoft.SqlServer.Management.SMO.DatabaseRole" (`$DB, 'VCMP_ADMIN_ROLE')
        `$Role.Create()
    }
    Else {
        Write-Output 'Role already exists'
    }

    # ----- Grant Permissions
    Invoke-Sqlcmd -ServerInstance $ComputerName -Database MSDB -Query 'GRANT SELECT ON dbo.syscategories TO VCMP_ADMIN_ROLE'
    Invoke-Sqlcmd -ServerInstance $ComputerName -Database MSDB -Query 'GRANT SELECT ON dbo.sysjobsteps TO VCMP_ADMIN_ROLE'
    Invoke-Sqlcmd -ServerInstance $ComputerName -Database MSDB -Query 'GRANT SELECT ON dbo.sysjobs TO VCMP_ADMIN_ROLE'
    Invoke-Sqlcmd -ServerInstance $ComputerName -Database MSDB -Query 'GRANT EXECUTE ON dbo.sp_add_job TO VCMP_ADMIN_ROLE'
    Invoke-Sqlcmd -ServerInstance $ComputerName -Database MSDB -Query 'GRANT EXECUTE ON dbo.sp_delete_job TO VCMP_ADMIN_ROLE'
    Invoke-Sqlcmd -ServerInstance $ComputerName -Database MSDB -Query 'GRANT EXECUTE ON dbo.sp_add_jobstep TO VCMP_ADMIN_ROLE'
    Invoke-Sqlcmd -ServerInstance $ComputerName -Database MSDB -Query 'GRANT EXECUTE ON dbo.sp_update_job TO VCMP_ADMIN_ROLE'
    Invoke-Sqlcmd -ServerInstance $ComputerName -Database MSDB -Query 'GRANT EXECUTE ON dbo.sp_add_jobserver TO VCMP_ADMIN_ROLE'
    Invoke-Sqlcmd -ServerInstance $ComputerName -Database MSDB -Query 'GRANT EXECUTE ON dbo.sp_add_jobschedule TO VCMP_ADMIN_ROLE'
    Invoke-Sqlcmd -ServerInstance $ComputerName -Database MSDB -Query 'GRANT EXECUTE ON dbo.sp_add_category TO VCMP_ADMIN_ROLE'

    # ----- Add login to role
    `$DB = Get-SQLDatabase -ServerInstance $ComputerName -Name MSDB

   if ( (`$DB.Roles['VCMP_ADMIN_ROLE']).EnumMembers() -notContains '$($ComposerServiceAcct.username)' ) {
       Write-Output 'Adding user to role'
  
      # Add-RoleMember -DB MSDB -RoleName 'VCMP_ADMIN_ROLE' -MemberName $($ComposerServiceAcct.username)
  
      (`$DB.Roles['VCMP_ADMIN_ROLE']).AddMember( '$($ComposerServiceAcct.username)')

   }
   Else {
       Write-Output 'Login already a member of role'
   }


"@

Invoke-VMScript -VM $VM -GuestCredential $DomainAdmin -scripttext $DBRole 


# ----- Create ODBC
# https://docs.vmware.com/en/VMware-Horizon-7/7.2/com.vmware.horizon-view.installation.doc/GUID-3E3CF460-1653-4D1A-AAEB-7C4BE575A054.html
Write-Verbose "Creating ODBC Connector"

Invoke-VMScript -vm $VM -GuestCredential $DomainAdminn -ScriptText "Add-OdbcDsn -Name ViewComposer -DriverName 'SQL Server Native Client 11.0' -DsnType System -SetPropertyValue @('Server=kw-sql','Trusted_Connection=Yes','Database=$ComposerDB') "


# ----- Install the Composer Service
# http://myvirtualcloud.net/vmware-view-composer-silent-install/




# ----- Cleanup
