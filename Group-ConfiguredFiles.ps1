#!/usr/bin/pwsh

$ErrorActionPreference = 'Stop'
$config = Import-PowerShellDataFile (Join-Path $HOME '.Group-Files.conf.psd1')
&(Join-Path $PSScriptRoot 'Group-Files.ps1') @config @args
