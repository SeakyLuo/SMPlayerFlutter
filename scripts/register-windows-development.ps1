param([Parameter(Mandatory)][string]$ExecutableDirectory)

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path $PSScriptRoot -Parent
$packageDirectory = Join-Path $projectRoot 'build\windows-development-identity'
New-Item -ItemType Directory -Path $packageDirectory -Force | Out-Null
Copy-Item -LiteralPath (Join-Path $projectRoot 'packaging\windows\development\AppxManifest.xml') -Destination $packageDirectory
Copy-Item -LiteralPath (Join-Path $projectRoot 'packaging\windows\Assets') -Destination $packageDirectory -Recurse -Force
$manifest = Join-Path $packageDirectory 'AppxManifest.xml'
Add-AppxPackage -Register $manifest -ExternalLocation $ExecutableDirectory
Write-Host "Windows development identity registered for $ExecutableDirectory"
