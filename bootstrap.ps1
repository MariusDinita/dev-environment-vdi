<#
bootstrap.ps1 - the one-liner entry point.

Run this after a nightly VDI reset. It needs only PowerShell + internet (no admin,
no git, no pre-installed tools). It downloads this repo and hands off to restore.ps1.

    irm https://raw.githubusercontent.com/MariusDinita/dev-environment-vdi/main/bootstrap.ps1 | iex

If you have a persistent drive (OneDrive, mapped share) that survives the reset, point the
portable tools at it so nightly restore skips the ~350 MB VS Code re-download:

    $env:DEVENV_ROOT='D:\dev-tools'
    irm https://raw.githubusercontent.com/MariusDinita/dev-environment-vdi/main/bootstrap.ps1 | iex
#>
$ErrorActionPreference = 'Stop'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
# The repo (and restore.ps1) arrive downloaded, so they carry the "from the internet"
# zone tag. A fresh VDI is often at Restricted/RemoteSigned, which would block running
# restore.ps1 directly. Bypass for this process only (no admin, not persisted).
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force

$repoZip = 'https://github.com/MariusDinita/dev-environment-vdi/archive/refs/heads/main.zip'
$tmp     = Join-Path $env:TEMP ('devenv-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $tmp | Out-Null
$zip     = Join-Path $tmp 'repo.zip'

Write-Host 'Downloading dev-environment-vdi repo...'
$wc = New-Object Net.WebClient
$wc.DownloadFile($repoZip, $zip)
Expand-Archive -LiteralPath $zip -DestinationPath $tmp -Force

$repoRoot = @(Get-ChildItem -Path $tmp -Directory)[0].FullName
Write-Host ('Repo extracted to ' + $repoRoot)
Write-Host ''

& (Join-Path $repoRoot 'restore.ps1') -RepoDir $repoRoot
