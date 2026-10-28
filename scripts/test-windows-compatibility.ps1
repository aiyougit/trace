$ErrorActionPreference = 'Stop'
Set-Location (Join-Path $PSScriptRoot '..')
[xml]$Compatibility = Get-Content -Raw 'windows/Compatibility.props'
$Minimum = [version][string]$Compatibility.Project.PropertyGroup.TraceMinimumWindowsVersion
# This is the reported user machine. Keep this regression fixture when changing the supported baseline.
$Server2019 = [version]'10.0.17763.3532'
if ($Server2019 -lt $Minimum) { throw "Server 2019 regression: minimum $Minimum rejects $Server2019" }
$Properties = dotnet msbuild windows/Trace.Windows/Trace.Windows.csproj -nologo -getProperty:TargetFramework,SupportedOSPlatformVersion,Version
if ($LASTEXITCODE -ne 0) { throw 'Unable to evaluate Windows target metadata' }
$Resolved = ($Properties | Out-String | ConvertFrom-Json).Properties
if ([version]$Resolved.SupportedOSPlatformVersion -ne [version]("$Minimum.0")) { throw 'Application and installer minimum OS versions differ' }
if ($Resolved.TargetFramework -ne "net10.0-windows$Minimum.0") { throw 'Windows SDK target baseline has drifted' }
$Installer = Get-Content -Raw 'windows/Installer/Trace.iss'
if ($Installer -notmatch '(?m)^MinVersion=\{#TraceMinimumWindowsVersion\}\s*$') { throw 'Installer must use shared compatibility metadata' }
Write-Host "PASS - Server 2019 build $Server2019 meets shared minimum $Minimum; app target: $($Resolved.TargetFramework), version: $($Resolved.Version)"
