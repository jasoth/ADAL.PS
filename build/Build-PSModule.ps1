param
(
    # Directory used to base all relative paths
    [parameter(Mandatory = $false)]
    [string] $BaseDirectory = "..\",
    #
    [parameter(Mandatory = $false)]
    [string] $OutputDirectory = ".\build\release\",
    #
    [parameter(Mandatory = $false)]
    [string] $SourceDirectory = ".\src\",
    #
    [parameter(Mandatory = $false)]
    [string] $ModuleManifestPath,
    #
    [parameter(Mandatory = $false)]
    [string] $PackagesConfigPath = ".\packages.config",
    #
    [parameter(Mandatory = $false)]
    [string] $PackagesDirectory = ".\build\packages",
    #
    [parameter(Mandatory = $false)]
    [string] $LicensePath = ".\LICENSE"
)

Write-Debug @"
Environment Variables
Processor_Architecture: $env:Processor_Architecture
      CurrentDirectory: $((Get-Location).ProviderPath)
          PSScriptRoot: $PSScriptRoot
"@

## Initialize
Import-Module "$PSScriptRoot\CommonFunctions.psm1" -Force -WarningAction SilentlyContinue -ErrorAction Stop

[System.IO.DirectoryInfo] $BaseDirectoryInfo = Get-PathInfo $BaseDirectory -InputPathType Directory -ErrorAction Stop
[System.IO.DirectoryInfo] $OutputDirectoryInfo = Get-PathInfo $OutputDirectory -InputPathType Directory -DefaultDirectory $BaseDirectoryInfo.FullName -ErrorAction SilentlyContinue
[System.IO.DirectoryInfo] $SourceDirectoryInfo = Get-PathInfo $SourceDirectory -InputPathType Directory -DefaultDirectory $BaseDirectoryInfo.FullName -ErrorAction Stop
[System.IO.FileInfo] $ModuleManifestFileInfo = Get-PathInfo $ModuleManifestPath -DefaultDirectory $SourceDirectoryInfo.FullName -DefaultFilename "*.psd1" -ErrorAction Stop
[System.IO.FileInfo] $PackagesConfigFileInfo = Get-PathInfo $PackagesConfigPath -DefaultDirectory $BaseDirectoryInfo.FullName -DefaultFilename "packages.config" -ErrorAction Stop
[System.IO.DirectoryInfo] $PackagesDirectoryInfo = Get-PathInfo $PackagesDirectory -InputPathType Directory -DefaultDirectory $BaseDirectoryInfo.FullName -ErrorAction SilentlyContinue
[System.IO.FileInfo] $LicenseFileInfo = Get-PathInfo $LicensePath -DefaultDirectory $BaseDirectoryInfo.FullName -DefaultFilename "LICENSE" -ErrorAction Stop

## Read Module Manifest
$ModuleManifest = Import-PowerShellDataFile $ModuleManifestFileInfo.FullName
[System.IO.DirectoryInfo] $ModuleOutputDirectoryInfo = Join-Path $OutputDirectoryInfo.FullName (Join-Path $ModuleManifestFileInfo.BaseName $ModuleManifest.ModuleVersion)

## Copy Source Module Code to Module Output Directory
Assert-DirectoryExists $ModuleOutputDirectoryInfo -ErrorAction Stop | Out-Null
Copy-Item ("{0}\*" -f $SourceDirectoryInfo.FullName) -Destination $ModuleOutputDirectoryInfo.FullName -Recurse -Force
Copy-Item $LicenseFileInfo.FullName -Destination (Join-Path $ModuleOutputDirectoryInfo.FullName License.txt) -Force

## NuGet Restore
&$PSScriptRoot\Restore-NugetPackages.ps1 -PackagesConfigPath $PackagesConfigFileInfo.FullName -OutputDirectory $PackagesDirectoryInfo.FullName

## Read Packages Configuration
$xmlPackagesConfig = New-Object xml
$xmlPackagesConfig.Load($PackagesConfigFileInfo.FullName)

## Copy Packages to Module Output Directory
foreach ($package in $xmlPackagesConfig.packages.package) {
    [System.IO.DirectoryInfo] $PackageDirectory = Join-Path $PackagesDirectoryInfo.FullName ("{0}.{1}\lib\{2}" -f $package.id, $package.version, $package.targetFramework)
    [System.IO.DirectoryInfo] $PackageOutputDirectory = "{0}\{1}.{2}" -f $ModuleOutputDirectoryInfo.FullName, $package.id, $package.version
    Assert-DirectoryExists $PackageOutputDirectory -ErrorAction Stop | Out-Null
    Copy-Item ("{0}\*" -f $PackageDirectory) -Destination $PackageOutputDirectory.FullName -Recurse -Force
}

## Update Module Manifest in Module Output Directory
&$PSScriptRoot\Update-PSModuleManifest.ps1 -ModuleManifestPath (Join-Path $ModuleOutputDirectoryInfo.FullName $ModuleManifestFileInfo.Name)
