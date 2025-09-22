#!/usr/bin/pwsh

<#
.SYNOPSIS
Group files by name

.DESCRIPTION
Group video files following a specific naming convention by their name

.PARAMETER Path
Specifies a path to one or more locations to search for video files

.PARAMETER MarkedPath
Specifies a path to one or more locations to search for video files that will be marked

.PARAMETER SortBy
Specify the property by which to sort the grouped files

.PARAMETER Descending
Sort the grouped files in descending order instead of ascending order

.EXAMPLE
Group-Files.ps1 -Path C:\Videos -MarkedPath C:\VideoArchive -SortBy Size

#>

[CmdletBinding()]
param (
    [Parameter(Mandatory, Position=0, ValueFromPipeline)]
    [string[]]$Path,

    [Parameter()]
    [string[]]$MarkedPath,

    [PSDefaultValue()]
    [string]$ExifTool = 'exiftool',

    [PSDefaultValue()]
    [Int32]$MinCount = 2,

    [PSDefaultValue()]
    [ValidateSet('Count', 'Mark', 'Name', 'Rating', 'Size')]
    [String[]]$SortBy = "Count",

    [switch]$Descending
)

begin {
    $ErrorActionPreference = 'Stop'

    filter Normalize-FileName {
        $_ `
        <# Remove filename suffix as well as timestamp and station suffix if present #> `
        -replace '(_\d{4}_(\d{2}_){2}\d{4}_.*)?\.\w+$', '' `
        <# Remove season and episode information #> `
        -replace '(^|[\W_])S\d+E\d+($|[\W_])', '$1$2' `
        <# Normalize all word separators to a single space #> `
        -replace '[\s-_]+', ' ' `
        <# Remove any non-word characters except whitespace #> `
        -replace '[^\w\s]', ''
    }

    function Get-Files {
        [CmdletBinding()]
        param (
            [Parameter(Mandatory, Position=0, ValueFromPipeline)]
            [string[]]$Path,

            [switch]$Mark,
            [switch]$GetRating
        )

        process {
            foreach ($file in (Get-ChildItem -File $Path)) {
                if ($GetRating) {
                    $rating = [int](& $ExifTool -s3 -Rating -- $file.FullName)
                }

                [PSCustomObject]@{
                    File = $file
                    Mark = $Mark
                    Rating = If ($GetRating -and $rating) { $rating } else { 0 }
                }
            }
        }
    }

    $sort_parameters = @{
        Property = $SortBy
        Descending = $Descending
    }

    $files = Get-Files -Path $MarkedPath -Mark -GetRating
}

process
{
    $files += Get-Files -Path $Path
}

end {
    $files | Group-Object -Property @{Expression={ $_.File.Name | Normalize-FileName }} |
        Where-Object -Property Count -ge $MinCount |
        ForEach-Object {
            [PSCustomObject]@{
                Mark = $true -in $_.Group.Mark
                Rating = [int]($_.Group.Rating | Measure-Object -Maximum).Maximum
                Name = $_.Name
                Count = $_.Count
                Size = [int](($_.Group.File | Measure-Object -Property Length -Sum).Sum)
            }

        } |
        Sort-Object @sort_parameters
}
