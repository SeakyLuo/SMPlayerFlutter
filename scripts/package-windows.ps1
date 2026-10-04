param([switch]$SkipBuild)

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
$projectRoot = Split-Path $PSScriptRoot -Parent
Set-Location -LiteralPath $projectRoot

# Codex terminals may only inherit PATH and USERPROFILE. Populate the Windows
# build environment before invoking Flutter, Visual Studio or the Windows SDK.
$env:WINDIR = $env:SystemRoot
$env:SystemDrive = [IO.Path]::GetPathRoot($env:SystemRoot).TrimEnd('\')
$env:APPDATA = Join-Path $env:USERPROFILE 'AppData\Roaming'
$env:LOCALAPPDATA = Join-Path $env:USERPROFILE 'AppData\Local'
$env:TEMP = Join-Path $env:LOCALAPPDATA 'Temp'
$env:TMP = $env:TEMP
$env:HOMEDRIVE = [IO.Path]::GetPathRoot($env:USERPROFILE).TrimEnd('\')
$env:HOMEPATH = $env:USERPROFILE.Substring($env:HOMEDRIVE.Length)
$env:ProgramData = Join-Path $env:SystemDrive 'ProgramData'
$env:ALLUSERSPROFILE = $env:ProgramData
$env:ProgramFiles = Join-Path $env:SystemDrive 'Program Files'
${env:ProgramFiles(x86)} = Join-Path $env:SystemDrive 'Program Files (x86)'
$env:ProgramW6432 = $env:ProgramFiles
$env:COMSPEC = Join-Path $env:SystemRoot 'System32\cmd.exe'
$env:PUB_HOSTED_URL = 'https://pub.flutter-io.cn'
$env:FLUTTER_STORAGE_BASE_URL = 'https://storage.flutter-io.cn'
$flutter = (Get-Command flutter.bat -ErrorAction Stop).Source
$env:FLUTTER_ROOT = Split-Path (Split-Path $flutter -Parent) -Parent
$env:PATH = "$env:FLUTTER_ROOT\bin;$env:SystemRoot\System32;$env:SystemRoot\System32\WindowsPowerShell\v1.0;$env:PATH"

function Invoke-Checked([string]$Executable, [string[]]$Arguments) {
    & $Executable @Arguments
    if ($LASTEXITCODE -ne 0) { throw "$Executable failed with exit code $LASTEXITCODE" }
}

$sdkRoot = Join-Path ${env:ProgramFiles(x86)} 'Windows Kits\10\bin'
$sdk = Get-ChildItem -LiteralPath $sdkRoot -Directory |
    Where-Object { $_.Name -match '^10\.0\.\d+\.0$' -and (Test-Path (Join-Path $_.FullName 'x64\makeappx.exe')) } |
    Sort-Object { [version]$_.Name } -Descending | Select-Object -First 1
if ($null -eq $sdk) { throw 'Install the Windows 10/11 SDK with MakeAppx.' }
$makeAppx = Join-Path $sdk.FullName 'x64\makeappx.exe'
$vswhere = Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio\Installer\vswhere.exe'
$vsPath = & $vswhere -latest -products '*' -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath
if ($LASTEXITCODE -ne 0 -or !$vsPath) { throw 'Install Visual Studio C++ desktop build tools.' }
$redist = Get-ChildItem -LiteralPath (Join-Path $vsPath 'VC\Redist\MSVC') -Directory |
    Where-Object { $_.Name -match '^\d+\.\d+\.\d+$' } |
    Sort-Object { [version]$_.Name } -Descending | Select-Object -First 1
if ($null -eq $redist) { throw 'Visual C++ redistributable DLLs are missing.' }
$crtDirectories = @(Get-ChildItem -LiteralPath (Join-Path $redist.FullName 'x64') -Directory -Filter 'Microsoft.VC*.CRT')
if ($crtDirectories.Count -ne 1) { throw 'Expected one x64 Visual C++ CRT directory.' }
$crt = $crtDirectories[0]

if (!$SkipBuild) {
    Invoke-Checked $flutter @('--no-version-check', 'pub', 'get', '--enforce-lockfile')
    Invoke-Checked $flutter @('--no-version-check', 'build', 'windows', '--release', '--no-pub')
}

$pubspec = Get-Content -LiteralPath 'pubspec.yaml' -Raw
if ($pubspec -notmatch '(?m)^version:\s*(\d+\.\d+\.\d+)(?:\+\d+)?\s*$') {
    throw 'pubspec.yaml must contain a release version major.minor.patch+build.'
}
# Store owns the fourth version component; Flutter's build number is not used.
$packageVersion = "$($Matches[1]).0"
$release = Join-Path $projectRoot 'build\windows\x64\runner\Release'
foreach ($required in @('smplayer_flutter.exe', 'flutter_windows.dll', 'data\app.so', 'data\icudtl.dat', 'data\flutter_assets')) {
    if (!(Test-Path -LiteralPath (Join-Path $release $required))) { throw "Missing Release payload: $required" }
}
$output = Join-Path $projectRoot 'build\store'
New-Item -ItemType Directory -Path $output -Force | Out-Null
# Keep each staging directory independent: no recursive deletion of old builds.
$stage = Join-Path $output ('staging-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $stage | Out-Null
Copy-Item -Path (Join-Path $release '*') -Destination $stage -Recurse
Get-ChildItem -LiteralPath $stage -Filter '*.pdb' | Remove-Item
Copy-Item -Path (Join-Path $crt.FullName '*.dll') -Destination $stage
Copy-Item -LiteralPath 'packaging\windows\Assets' -Destination $stage -Recurse
[xml]$manifest = Get-Content -LiteralPath 'packaging\windows\AppxManifest.xml' -Raw -Encoding UTF8
$manifest.Package.Identity.Version = $packageVersion
$manifest.Save((Join-Path $stage 'AppxManifest.xml'))
$package = Join-Path $output "SMPlayer-$packageVersion-x64.msix"
Invoke-Checked $makeAppx @('pack', '/d', $stage, '/p', $package, '/o')
$hash = Get-FileHash -LiteralPath $package -Algorithm SHA256
Write-Host "Unsigned Store package: $package"
Write-Host "SHA256: $($hash.Hash)"
Write-Host 'No certificate installed, no app installed, no Store submission performed.'
