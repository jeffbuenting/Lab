Param (
    [String]$Path,

    [String]$UserName,

    [String]$Password
)

$MapDrive = @"
    $Cred = New-Object System.Management.Automation.PSCredential ($UserName, $(ConvertTo-SecureString $Password -AsPlainText -Force))

    New-PSDrive -Name p -PSProvider FileSystem -Root $Path -Credential $Cred -Persist -ErrorAction stop
"@

$MapDrive | Out-File -FilePath c:\scripts\mapdrive.ps1