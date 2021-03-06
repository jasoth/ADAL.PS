param
(
    # Path to Module Manifest
    [Parameter(Mandatory = $false)]
    [string] $ModuleManifestPath = ".\release\*\*.*.*",
    # Module Version
    [Parameter(Mandatory = $false)]
    [string] $ModuleVersion
)

## Initialize
Import-Module "$PSScriptRoot\CommonFunctions.psm1" -Force -WarningAction SilentlyContinue -ErrorAction Stop
[hashtable] $paramUpdateModuleManifest = @{ }
if ($ModuleVersion) { $paramUpdateModuleManifest['ModuleVersion'] = $ModuleVersion }

[System.IO.FileInfo] $ModuleManifestFileInfo = Get-PathInfo $ModuleManifestPath -DefaultFilename "*.psd1" -ErrorAction Stop

## Read Module Manifest
$ModuleManifest = Import-PowerShellDataFile $ModuleManifestFileInfo.FullName
[System.IO.DirectoryInfo] $ModuleOutputDirectoryInfo = $ModuleManifestFileInfo.Directory

## Get Module Output FileList
$ModuleFileListFileInfo = Get-ChildItem $ModuleOutputDirectoryInfo.FullName -Recurse -File
$ModuleRequiredAssembliesFileInfo = $ModuleFileListFileInfo | Where-Object Extension -eq '.dll'

## Get Paths Relative to Module Base Directory
$ModuleFileList = Get-RelativePath $ModuleFileListFileInfo.FullName -WorkingDirectory $ModuleOutputDirectoryInfo.FullName -ErrorAction Stop
$paramUpdateModuleManifest['FileList'] = $ModuleFileList

if ($ModuleRequiredAssembliesFileInfo) {
    $ModuleRequiredAssemblies = Get-RelativePath $ModuleRequiredAssembliesFileInfo.FullName -WorkingDirectory $ModuleOutputDirectoryInfo.FullName -ErrorAction Stop
    $paramUpdateModuleManifest['RequiredAssemblies'] = $ModuleRequiredAssemblies
}

## Clear RequiredAssemblies
(Get-Content $ModuleManifestFileInfo.FullName -Raw) -replace "(?s)RequiredAssemblies\ =\ @\([^)]*\)", "# RequiredAssemblies = @()" | Set-Content $ModuleManifestFileInfo.FullName

## Update Module Manifest in Module Output Directory
Update-ModuleManifest -Path $ModuleManifestFileInfo.FullName -ErrorAction Stop @paramUpdateModuleManifest
