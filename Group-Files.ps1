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
    [ValidateSet('Count', 'Mark', 'Name', 'Size')]
    [String[]]$SortBy = "Count",

    [switch]$Descending
)

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

$sort_parameters = @{
    Property = $SortBy
    Descending = $Descending
}

(Get-ChildItem $Path | Select-Object -Property @{n='File'; e={ $_ }}, @{n='Mark'; e={ $false }}) +
    (Get-ChildItem $MarkedPath | Select-Object -Property @{n='File'; e={ $_ }}, @{n='Mark'; e={ $true }}) |
    Group-Object -Property @{Expression={ $_.File.Name | Normalize-FileName }} |
    Where-Object -Property Count -ge $MinCount |
    Select-Object -Property Count, Name,
        @{n='Size'; e={ (($_.Group.File | Measure-Object -Property Size -Sum).Sum) / 1MB }},
        @{n='Mark'; e={ $true -in $_.Group.Mark }} |
    Sort-Object @sort_parameters
