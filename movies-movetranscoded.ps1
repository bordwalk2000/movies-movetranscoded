param(
    [Parameter(
        Mandatory = $true,
        Position = 0,
        HelpMessage = "Path to the location of transcoded movie folders ready to be moved."
    )]
    [ValidateNotNullOrEmpty()]
    [string] $TranscodedFiles,

    [Parameter(
        Mandatory = $false,
        HelpMessage = "Skip folders that have LastWriteTime set to less than this many hours ago."
    )]
    [string] $HoursLastWrite = 20
)

# Looked at fixed volumes to see if they contain a folder named "Movies" on the root of drive
$MovieDirectoryLocations = Get-Volume
| Where-Object { $_.DriveType -eq 'Fixed' -and (Test-Path "$($_.DriveLetter):\Movies") }
| Select-Object @{label = "MovieDirectories"; Expression = { "$($_.DriveLetter):\Movies" } }

# Looks at the folders in each one of the Movies directories and figures out their ascii values.
$MovieFolders = Get-ChildItem -Path $MovieDirectoryLocations.MovieDirectories
| Select-Object @{label = "Name"; Expression = { $_.Name.ToUpper() } }, FullName,
@{label = "minascii"; Expression = { [int[]][char[]]($_.Name).ToUpper().replace('-', '')[0] } },
@{label = "maxascii"; Expression = { [int[]][char[]]($_.Name).ToUpper().replace('-', '')[1] } }
| Sort-Object Name
Write-Verbose "Found Movies Folder Lists"
Write-Verbose ($MovieFolders | Out-String)

# Grabs folders located in the transcoded folder that contain files and those files haven't been modified in X many hours.
$Transcoded = Get-ChildItem $TranscodedFiles -Directory
| Where-Object { $_.GetFiles().Count -ne 0 }
| Where-Object {
    (Get-ChildItem $_.FullName -File -Recurse
    | Where-Object {
        $_.LastWriteTime -gt (Get-Date).AddHours(-$HoursLastWrite)
    }) -eq $null
}
Write-Verbose "$($Transcoded.count) Movies Found"
Write-Verbose ($Transcoded.Name | Out-String)

# Process each one of those folders to remove empty folders and move them to correct Movies folder location.
foreach ($Movie in $Transcoded) {
    Write-Verbose "Processing $($Movie.Name)"

    # Remove Empty Folders
    Write-Verbose "Removing Empty Folders"
    Get-ChildItem -Path $Movie -recurse
    | Where-Object { $_.PSIsContainer -and @(Get-ChildItem -Lit $_.Fullname -r | Where-Object { !$_.PSIsContainer }).Length -eq 0 }
    | Remove-Item -Recurse

    # Move Movie Folders
    foreach ($Directory in $MovieFolders) {
        if (([int]$Movie.Name.ToUpper()[0] -ge $Directory.minascii) -and ([int]$Movie.Name.ToUpper()[0] -le $Directory.maxascii)) {
            Write-Verbose "Moving $($Movie.Name) to $($Directory.FullName)"
            Move-Item -Path $Movie.FullName -Destination $Directory.FullName -ErrorAction Continue
        }
    }
}