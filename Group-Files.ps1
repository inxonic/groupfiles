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

.PARAMETER GetRating
Retrieve SharedUserRating for marked files and return the highest value per group

.PARAMETER MinCount
Only return groups containing at least a specific number of files

.PARAMETER MinRating
Only return groups containing a marked file with at least a specific rating

.EXAMPLE
Group-Files.ps1 -Path C:\Videos -MarkedPath C:\VideoArchive -SortBy Size

#>

[CmdletBinding()]
param (
    [Parameter(Mandatory, Position = 0, ValueFromPipeline)]
    [string[]]$Path,

    [Parameter()]
    [string[]]$MarkedPath,

    [PSDefaultValue()]
    [string]$ExifTool = 'exiftool',

    [PSDefaultValue()]
    [Int32]$MinCount = 2,

    [Parameter()]
    [Int32]$MinRating,

    [PSDefaultValue()]
    [ValidateSet('Count', 'Mark', 'Name', 'Rating', 'Size')]
    [String[]]$SortBy = "Count",

    [switch]$GetRating,
    [switch]$Descending
)

begin {
    $ErrorActionPreference = 'Stop'

    [Console]::OutputEncoding = [System.Text.Encoding]::UTF8
    $PSDefaultParameterValues['*:Encoding'] = 'utf8'

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
            [Parameter(Mandatory, Position = 0, ValueFromPipeline)]
            [string[]]$Path,

            [switch]$Mark,
            [switch]$GetRating
        )

        process {
            foreach ($file in (Get-ChildItem -File $Path)) {
                [PSCustomObject]@{
                    File   = $file
                    Mark   = $Mark
                    Rating = $null
                }
            }
        }
    }

    $sort_parameters = @{
        Property   = $SortBy
        Descending = $Descending
    }

    $files = Get-Files -Path $MarkedPath -Mark -GetRating
}

process {
    $files += Get-Files -Path $Path
}

end {
    $groups = $files | Group-Object -Property @{Expression = { $_.File.Name | Normalize-FileName } } |
        Where-Object -Property Count -GE $MinCount

    if ($GetRating) {
        $ratings = @{}
        $groups.Group | Where-Object -Property Mark -EQ $true | ForEach-Object { $_.File.FullName } |
            & $ExifTool -charset filename=utf8 -json -SharedUserRating -@ - 2>$null |
            ConvertFrom-Json | ForEach-Object {
                $ratings[$_.SourceFile] = $_.SharedUserRating
            }

        $groups.Group | Where-Object -Property Mark -EQ $true | ForEach-Object {
            $_.Rating = $ratings[$_.File.FullName -replace '\\', '/']
        }
    }

    $groups |
        ForEach-Object {
            $rating = if ($GetRating) {
                [int]($_.Group.Rating | Measure-Object -Maximum).Maximum
            }
            else { $null }

            if (-not $MinRating -or $rating -ge $MinRating) {
                [PSCustomObject]@{
                    Mark   = $true -in $_.Group.Mark
                    Rating = $rating
                    Name   = $_.Name
                    Count  = $_.Count
                    Size   = [int](($_.Group.File | Measure-Object -Property Length -Sum).Sum / 1MB)
                }
            }

        } |
        Sort-Object @sort_parameters
}
