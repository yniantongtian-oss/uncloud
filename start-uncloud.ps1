# Launch Uncloud on this PC: Node receiver + Windows app.
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$env:UNCLOUD_CORE = Join-Path $root 'core\bin\uncloud.js'
$exe = Join-Path $root 'app\build\windows\x64\runner\Release\uncloud.exe'
if (-not (Test-Path $exe)) {
  Write-Error "Build missing. From app/: flutter build windows --release"
}
Start-Process -FilePath $exe -WorkingDirectory (Join-Path $root 'app')
Write-Host "Uncloud started. Incoming files: $env:USERPROFILE\Documents\Uncloud"
