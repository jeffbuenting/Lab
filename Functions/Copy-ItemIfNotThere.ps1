Function Copy-ItemIfNotThere {

    [CmdletBinding()]
    Param (
        [Parameter ( Position = 0, Mandatory = $True ) ]
        [String]$Path,

        [Parameter ( Position = 1, Mandatory = $True ) ]
        [String]$Destination,

        [Switch]$Recurse
    )

    Try {
        Write-Verbose "Copy if the file does not exist.  File/Folder = $Path to Dest = $Destination"

        # ----- extract file/folder name
        $Name = (Get-Item -Path $Path).Name

        if ( -Not (Test-Path -Path $Destination\$Name ) ) {
            Write-Verbose "Copying..."

            copy-item -path $Path -Destination $Destination -Recurse:$Recurse -ErrorAction Stop
        }
        Else {
            Write-Verbose "Already exists"
        }

    }
    Catch {
        $ExceptionMessage = $_.Exception.Message
        $ExceptionType = $_.Exception.GetType().Fullname
        Throw "Copy-ItemIfNotTHere : Error Copying $Path.`n`n     $ExceptionMessage`n`n $ExceptionType"
    }
}