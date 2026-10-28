param(
    [ValidateSet('win-x64', 'win-arm64')][string]$Runtime = 'win-x64',
    [switch]$SkipChecks,
    [switch]$SkipInstaller
)
$ErrorActionPreference = 'Stop'
Set-Location (Join-Path $PSScriptRoot '..')
[xml]$Compatibility = Get-Content -Raw 'windows/Compatibility.props'
$Version = [string]$Compatibility.Project.PropertyGroup.TraceWindowsVersion
$MinimumWindowsVersion = [string]$Compatibility.Project.PropertyGroup.TraceMinimumWindowsVersion
if ($Version -notmatch '^\d+\.\d+\.\d+$' -or $MinimumWindowsVersion -notmatch '^\d+\.\d+\.\d+$') { throw 'Invalid Windows compatibility metadata' }
$Architecture = if ($Runtime -eq 'win-arm64') { 'arm64' } else { 'x64' }
$Output = Join-Path (Get-Location) "dist/windows/$Runtime"
$Publish = Join-Path $Output 'app'
if (-not $SkipChecks) {
    & "$PSScriptRoot/test-windows-compatibility.ps1"
    dotnet run --project windows/Trace.CoreChecks -c Release
    if ($LASTEXITCODE -ne 0) { throw 'Core checks failed' }
}
dotnet publish windows/Trace.Windows/Trace.Windows.csproj -c Release -r $Runtime --self-contained true -p:PublishSingleFile=true -p:IncludeNativeLibrariesForSelfExtract=true -o $Publish
if ($LASTEXITCODE -ne 0) { throw 'Windows publish failed' }
$Portable = Join-Path $Output "Trace-$Version-windows-$Architecture-portable.zip"
Compress-Archive -Path "$Publish/*" -DestinationPath $Portable -Force
if (-not $SkipInstaller) {
    $Compiler = Get-Command ISCC.exe -ErrorAction SilentlyContinue
    $CompilerPath = if ($Compiler) { $Compiler.Source } else { "${env:ProgramFiles(x86)}\Inno Setup 6\ISCC.exe" }
    if (-not (Test-Path $CompilerPath)) { throw 'Install Inno Setup 6.4+ from https://jrsoftware.org/isinfo.php or use -SkipInstaller for the portable build.' }
    & $CompilerPath "/DTraceVersion=$Version" "/DTraceMinimumWindowsVersion=$MinimumWindowsVersion" "/DTraceArchitecture=$Architecture" "/DTraceSource=$Publish" "/DTraceOutput=$Output" windows/Installer/Trace.iss
    if ($LASTEXITCODE -ne 0) { throw 'Windows installer build failed' }
}
$Checksums = @()
Get-ChildItem $Output -File | Where-Object { $_.Name -match '\.(zip|exe)$' } | Sort-Object Name | ForEach-Object {
    $Hash = (Get-FileHash $_.FullName -Algorithm SHA256).Hash.ToLowerInvariant()
    $Checksums += "$Hash  $($_.Name)"
}
$Checksums | Set-Content -Path (Join-Path $Output "SHA256SUMS-windows-$Architecture.txt") -Encoding utf8
Write-Host "Built Windows $Architecture packages in $Output"
