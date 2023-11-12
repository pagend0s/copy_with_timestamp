cls
SLEEP 2
$ti_sta = "1.0"
Write-Host ("{0}{1}" -f (' ' * (([Math]::Max(0, $Host.UI.RawUI.BufferSize.Width / 2) - [Math]::Floor($Null.Length / 2)))), "WELCOME TO COPY WITH TIMESTAMP version: " ) -ForegroundColor Green -NoNewline; Write-Host "$ti_sta" -ForegroundColor yellow
$month = 0
$day = 1
$year = 2
###################
#1)	SELECT SOURCE #
###################
Function Select-Folder-SRC
{
	param([string]$Description="Select SOURCE Folder",[string]$RootFolder="c:\Users\")

	[System.Reflection.Assembly]::LoadWithPartialName("System.windows.forms") | Out-Null 
	$objForm = New-Object System.Windows.Forms.FolderBrowserDialog
	$Description = "SET THE SOURCE"
	$objForm.SelectedPath  = $RootFolder
	$objForm.Description = $Description
	$Show = $objForm.ShowDialog()
	If ($Show -eq "OK")
		{
			Return $objForm.SelectedPath
	    }
	Else
		{
		    Write-Error "Operation cancelled by user."
		}
}

do
	{
		SLEEP 2
		write-Host ""
		Write-Host "Select SOURCE Folder" -ForegroundColor GREEN
		SLEEP 2
		$SRC_Select_Folder = Select-Folder-SRC
		SLEEP 1
		write-Host ""
		if ($SRC_Select_Folder -eq $null)
			{
				write-Host ""
				write-Host "SOURCE CAN'T BE EMPTY!!!" -ForegroundColor RED
			}
		if ($SRC_Select_Folder -ne $null)
			{
			do
				{
					sleep 1
					write-Host ""
					[string]$s = $(Write-Host "Is the SOURCE correct ?" -ForegroundColor green) + $(Write-Host "$SRC_Select_Folder" -ForegroundColor YELLOW) + $(Write-Host "IF SO, TYPE: yes IF NOT TYPE: no --> and hit ENTER" -ForegroundColor green; Read-Host)
						if ( $s -eq "yes" )
							{
							}
						elseif ( $s -eq "no" )
							{
								write-Host ""
								write-Host "CHOOSE ANOTHER SOURCE" -ForegroundColor GREEN
								SLEEP 1
								$SRC_Select_Folder = $null						
							}
				}until (( $s -eq "yes" ) -or ($s -eq "no"))
			}
		
	}while($SRC_Select_Folder -eq $null)

$fullpath = $SRC_Select_Folder

############
#END SRC   #
############


###################
#2)	SELECT DEST   #
###################

Function Select-Folder-DST
{
	param([string]$Description="Select DESTINATION Folder",[string]$RootFolder="c:\Users\")

	[System.Reflection.Assembly]::LoadWithPartialName("System.windows.forms") | Out-Null 
	$objForm = New-Object System.Windows.Forms.FolderBrowserDialog
	$Description = "SET THE DESTINATION"
	$objForm.SelectedPath  = $RootFolder
	$objForm.Description = $Description
	$Show = $objForm.ShowDialog()
	If ($Show -eq "OK")
		{
			Return $objForm.SelectedPath
	    }
	Else
		{
		    Write-Error "Operation cancelled by user."
		}
}

do
	{
		write-Host ""
		Write-Host "SELECT DESTINATION" -ForegroundColor GREEN
		SLEEP 2
		$DEST_Select_Folder =  Select-Folder-DST
		SLEEP 1
		write-Host ""
		if ($DEST_Select_Folder -eq $null)
			{
				write-Host ""
				write-Host "DESTINATION CAN'T BE EMPTY!!!" -ForegroundColor RED
			}
		if ($DEST_Select_Folder -ne $null)
			{
			do
				{
					write-Host ""
					sleep 1
					[string]$s = $(Write-Host "Is the DESTINATION correct ?" -ForegroundColor green) + $(Write-Host "$DEST_Select_Folder" -ForegroundColor YELLOW) + $(Write-Host "IF SO, TYPE: yes IF NOT TYPE: no --> and hit ENTER" -ForegroundColor green; Read-Host)
						if ( $s -eq "yes" )
							{
							}
						elseif ( $s -eq "no" )
							{
								write-Host ""
								write-Host "CHOOSE ANOTHER DESTINATION" -ForegroundColor GREEN
								SLEEP 1
								$DEST_Select_Folder = $null						
							}
				}until (( $s -eq "yes" ) -or ($s -eq "no"))
			}
		
	}while($DEST_Select_Folder -eq $null)
	
$dest_folder = $DEST_Select_Folder

#############
#END DEST   #
#############
SLEEP 2
Write-Host "Gathering file list" -ForegroundColor Green
$file_src = gci $fullpath -Recurse | %{ $_.FullName }
$b = 1

#####################
#MAIN COPY PROGRESS #
#####################
SLEEP 2
Write-Host "COPYING IN PROGRESS. THIS MAY TAKE SOME TIME DEPENDING ON THE NUMBER AND WEIGHT OF THE FILES" -ForegroundColor Green
SLEEP 2
foreach ( $file in $file_src)
    {
        $file_propertys = Get-ItemProperty $file | %{ $_.LastWriteTime } | % {($_ -split "\s+")[0]}
        $file_time = $file_propertys.Split("/")
        $file_time_year = $file_time[2]
        $file_time_day = $file_time[1]
        $file_time_month = $file_time[0]
        #YEAR
		$a = 1
        if ( Test-Path -Path "$dest_folder\$file_time_year" )
            {
                if ( Test-Path -Path "$dest_folder\$file_time_year\$file_time_month" )
                    {
						if ( Test-Path -Path "$dest_folder\$file_time_year\$file_time_month\$file" )
							{
								$a++
								Copy-Item $file -Destination  "$dest_folder\$file_time_year\$file_time_month\$a_$file" -ErrorAction SilentlyContinue
							}
						else
							{	
								Copy-Item $file -Destination  "$dest_folder\$file_time_year\$file_time_month" -ErrorAction SilentlyContinue
							}
                    }
                else
                    {
                        New-Item -ItemType "directory" -Path "$dest_folder\$file_time_year\$file_time_month" | Out-Null
                        Copy-Item $file -Destination  "$dest_folder\$file_time_year\$file_time_month" -ErrorAction SilentlyContinue
                    }
            }
        else
            {
                New-Item -ItemType "directory" -Path "$dest_folder\$file_time_year" | Out-Null
                
                if ( Test-Path -Path "$dest_folder\$file_time_year\$file_time_month" )
                    {
                        Copy-Item $file -Destination  "$dest_folder\$file_time_year\$file_time_month" -ErrorAction SilentlyContinue
                    }
                else
                    {
                        New-Item -ItemType "directory" -Path "$dest_folder\$file_time_year\$file_time_month" | Out-Null
                        Copy-Item $file -Destination  "$dest_folder\$file_time_year\$file_time_month" -ErrorAction SilentlyContinue
                    }

            }
	$b++	
   
    }
SLEEP 2
write-host "Copied: $b - Files" -ForegroundColor Green
SLEEP 2
write-host "The sorting and copying process is complete. !!!!" -ForegroundColor Green
SLEEP 2
Start explorer.exe "$dest_folder\" 