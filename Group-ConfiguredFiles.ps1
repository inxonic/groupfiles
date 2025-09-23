#!/usr/bin/pwsh

param (
    [PSDefaultValue()]
    [string]$ConfigPath = (Join-Path $HOME '.Group-Files.conf.psd1')
)

$ErrorActionPreference = 'Stop'
$config = Import-PowerShellDataFile $ConfigPath
Write-Host $args
&(Join-Path $PSScriptRoot 'Group-Files.ps1') @config @args
