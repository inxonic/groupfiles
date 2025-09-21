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

param (
    [Parameter(Mandatory, Position=0)]
    [string[]]$Path,

    [Parameter()]
    [string[]]$MarkedPath,

    [PSDefaultValue()]
    [Int32]$MinCount = 2,

    [PSDefaultValue()]
    [ValidateSet('Count', 'Mark', 'Size')]
    [String[]]$SortBy = "Count",

    [switch]$Descending
)

$sort_parameters = @{
    Property = $SortBy
    Descending = $Descending
}

$files = Get-ChildItem $Path | Select-Object -Property @{n='File'; e={$_}}, @{n='Mark'; e={$false}}
$files += Get-ChildItem $MarkedPath | Select-Object -Property @{n='File'; e={$_}}, @{n='Mark'; e={$true}}

$files |
    Group-Object -Property @{
        Expression={
            $_.File.Name `
                -replace '(_\d{4}_(\d{2}_){2}\d{4}_.*)?\.\w+$', '' `
                -replace '(^|[\W_])S\d+E\d+($|[\W_])', '$1$2' `
                -replace '[\s-_]+', ' ' `
                -replace '[^\w\s]', ''
        }
    } |
    Where-Object -Property Count -ge $MinCount |
    Select-Object -Property Count, Name,
        @{n='Size'; e={(($_.Group.File | Measure-Object -Property Size -Sum).Sum)/1MB}},
        @{n='Mark'; e={$true -in $_.Group.Mark }} |
    Sort-Object @sort_parameters
