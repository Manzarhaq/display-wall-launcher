$ErrorActionPreference = 'Stop'
Set-Location $PSScriptRoot
dotnet publish DisplayWallLauncher.csproj -c Release -r win-x64 --self-contained true -p:PublishSingleFile=false -p:DebugType=none -o ../dist/windows-x64
if ($LASTEXITCODE -ne 0) { throw 'Windows build failed' }
Copy-Item ../README.md, ../LICENSE ../dist/windows-x64/
Compress-Archive -Path ../dist/windows-x64/* -DestinationPath ../dist/Display-Wall-Launcher-Windows-x64.zip -Force
Write-Output 'Built self-contained Windows x64 ZIP in dist/'
