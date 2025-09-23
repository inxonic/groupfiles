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
Specifies the property by which to sort the grouped files

.PARAMETER Descending
Sort the grouped files in descending order instead of ascending order

.PARAMETER MinCount
Only return groups containing at least a specific number of files

.PARAMETER MinRating
Only return groups containing a marked file with at least a specific rating

.PARAMETER CacheRating
Cache the file ratings per directory

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
    [Int32]$MinRating,

    [PSDefaultValue()]
    [ValidateSet('Count', 'Mark', 'Name', 'Rating', 'Size')]
    [String[]]$SortBy = "Count",

    [switch]$Descending,
    [switch]$CacheRating
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
            $rating = @{}

            if ($GetRating) {
                $ratings_file = Join-Path $Path '.Group-Files.ratings.json'

                if (-not $CacheRating -or -not (Test-Path -PathType Leaf $ratings_file))
                {
                    & $ExifTool -charset filename=utf8 -json -SharedUserRating $Path >$ratings_file 2>/dev/null
                }
                Get-Content $ratings_file |
                    ConvertFrom-Json |
                    ForEach-Object {
                        $rating[($_.SourceFile | Split-Path -Leaf)] = $_.SharedUserRating
                    }
            }

            foreach ($file in (Get-ChildItem -File $Path)) {
                [PSCustomObject]@{
                    File = $file
                    Mark = $Mark
                    Rating = $rating[$file.Name]
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
        ForEach-Object {
            if ($_.Count -ge $MinCount) {
                $rating = [int]($_.Group.Rating | Measure-Object -Maximum).Maximum
                if (-not $MinRating -or $rating -ge $MinRating) {
                    [PSCustomObject]@{
                        Mark = $true -in $_.Group.Mark
                        Rating = $rating
                        Name = $_.Name
                        Count = $_.Count
                        Size = [int](($_.Group.File | Measure-Object -Property Length -Sum).Sum)
                    }
                }
            }

        } |
        Sort-Object @sort_parameters
}
