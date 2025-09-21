#!/usr/bin/pwsh

<#
.SYNOPSIS
Group files by name

.DESCRIPTION
Group video files following a specific naming convention by their name

.PARAMETER Path
Specifies a path to one or more locations to search for video files

.EXAMPLE
Group-Files.ps1 -Path C:\Videos

#>

param (
    [Parameter(Mandatory, Position=0)]
    [string[]]$Path
)

Get-ChildItem $Path |
    Group-Object -Property @{
        Expression={
            $_.Name `
                -replace '(_\d{4}_(\d{2}_){2}\d{4}_.*)?\.\w+$', '' `
                -replace '(^|[\W_])S\d+E\d+($|[\W_])', '$1$2' `
                -replace '[\s-_]+', ' ' `
                -replace '[^\w\s]', ''
        }
    } |
    Where-Object -Property Count -gt 1 |
    Select-Object -Property Count, Name,
        @{n='Size'; e={(($_.Group | Measure-Object -Property Size -Sum).Sum)/1MB}}
