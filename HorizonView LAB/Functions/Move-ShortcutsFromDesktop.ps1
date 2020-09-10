 

        # ------------------------------------------------------------------------
        # Move-shortcutsfromdesktop
        #
        # moves the shortcuts on the desktop to the correct dated folder
        #-------------------------------------------------------------------------

        Param (
            [String]$UserDesktop = "c:\temp",

            [String]$Destination = 'p:\links'
        )

        #-------------------------------------------------------------------------
        # Main
        #-------------------------------------------------------------------------

        write-Host "Processing $UserDesktop"

        Write-Output "does copy to path exist?"
        # ----- Check if the P: drive exists.  If not then do not process...
        if (  (Test-Path -Path $Destination)  -eq $False ) { exit }

        # ----- Get year and date
        $Date = (Get-Date -Format "yyyy - MMM").ToUpper()

        # ----- Check if folder exists
        if ( Get-ChildItem -Path $Destination -Filter $Date ) {
		        # ----- Do Nothing
	        }
	        else {
		        md "$Destination\$Date"
        }

        # ----- Move .lnk files
        Get-Item -path "$UserDesktop\*.url" | foreach {
	        Write-Host "$Destination\$Date\$($_.Name)"
	        if ( Test-Path "$Destination\$Date\$($_.Name)" ) {
        	#		Write-Host $_.name -ForegroundColor red
			        $_ | Rename-Item -NewName "$($_.BaseName)($(Get-Random -Maximum 100))$($_.Extension)" -PassThru | Move-Item -Destination "$Destination\$Date"
		        }
		        else {
        #			Write-Host $_.Name -ForegroundColor green
			        $_ | Move-Item -Destination "$Destination\$Date"
	        }
        }
    