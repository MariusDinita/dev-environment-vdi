<#
.SYNOPSIS
  Rebuilds a portable, no-admin dev environment on a Windows VDI (which resets nightly).

.DESCRIPTION
  - Downloads portable VS Code (latest stable x64 zip) into a user folder.
  - Downloads MinGit (portable git) and puts it on PATH.
  - Copies settings.json / keybindings.json into the portable VS Code data dir.
  - Installs every VS Code extension listed in extensions.txt.
  - Creates a Desktop shortcut for VS Code (portable builds have no Start Menu entry).

  No admin rights required. Needs only PowerShell + internet.
  Normally you do not run this directly; the one-liner runs bootstrap.ps1, which runs this.

.PARAMETER RepoDir
  Folder holding settings.json, keybindings.json, extensions.txt. Defaults to this file's folder.
.PARAMETER Root
  Where the portable tools are unpacked. Default: %USERPROFILE%\dev-tools
  Set the DEVENV_ROOT environment variable (or pass -Root) to a persistent drive if you have one,
  so nightly restore skips the re-download.
.PARAMETER VsCodeUrl
  Override the VS Code download URL (e.g. to pin a specific version).
.PARAMETER Force
  Re-download VS Code and git even if they are already present.
#>
[CmdletBinding()]
param(
  [string]$RepoDir   = $PSScriptRoot,
  [string]$Root      = $env:DEVENV_ROOT,
  [string]$VsCodeUrl = 'https://update.code.visualstudio.com/latest/win32-x64-archive/stable',
  [switch]$Force
)

if (-not $Root) { $Root = Join-Path $env:USERPROFILE 'dev-tools' }

$ErrorActionPreference = 'Stop'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

function Download-File([string]$Url, [string]$Out) {
  $wc = New-Object Net.WebClient
  $wc.DownloadFile($Url, $Out)
}

function Get-VsCodeCli([string]$CodeDir) {
  $cli = Join-Path $CodeDir 'bin\code.cmd'
  if (-not (Test-Path $cli)) { $cli = (Join-Path $CodeDir 'Code.exe') }
  return $cli
}

function Install-VsCode([string]$Root, [string]$Url, [switch]$Force) {
  $codeDir = Join-Path $Root 'code'
  $exe     = Join-Path $codeDir 'Code.exe'
  if ((Test-Path $exe) -and -not $Force) {
    Write-Host ("VS Code already present: {0}" -f $codeDir)
    return $codeDir
  }
  Write-Host ("Installing portable VS Code -> {0}" -f $codeDir)
  $zip = Join-Path $env:TEMP ('vscode-' + [guid]::NewGuid().ToString('N') + '.zip')
  Download-File $Url $zip
  if (Test-Path $codeDir) { Remove-Item $codeDir -Recurse -Force }
  Expand-Archive -LiteralPath $zip -DestinationPath $codeDir -Force
  Remove-Item $zip -Force
  return $codeDir
}

function Install-MinGit([string]$Root, [switch]$Force) {
  $gitDir = Join-Path $Root 'git'
  $gitExe = Join-Path $gitDir 'cmd\git.exe'
  if ((Test-Path $gitExe) -and -not $Force) {
    Write-Host ("MinGit already present: {0}" -f $gitDir)
    return (Join-Path $gitDir 'cmd')
  }
  Write-Host ("Installing portable MinGit -> {0}" -f $gitDir)
  $rel   = Invoke-RestMethod -Uri 'https://api.github.com/repos/git-for-windows/git/releases/latest'
  $asset = @($rel.assets) | Where-Object { $_.name -match '^MinGit-.*-64-bit\.zip$' } | Select-Object -First 1
  if (-not $asset) { throw 'Could not find a MinGit 64-bit release asset.' }
  $zip = Join-Path $env:TEMP ('mingit-' + [guid]::NewGuid().ToString('N') + '.zip')
  Download-File $asset.browser_download_url $zip
  if (Test-Path $gitDir) { Remove-Item $gitDir -Recurse -Force }
  Expand-Archive -LiteralPath $zip -DestinationPath $gitDir -Force
  Remove-Item $zip -Force
  return (Join-Path $gitDir 'cmd')
}

Write-Host ''
Write-Host '=== dev-environment-vdi : restore ==='
Write-Host ('Tools root : ' + $Root)
Write-Host ('Repo files : ' + $RepoDir)
Write-Host ''

$codeDir = Install-VsCode -Root $Root -Url $VsCodeUrl -Force:$Force
$gitCmd  = Install-MinGit  -Root $Root -Force:$Force
$env:PATH = "$gitCmd;$env:PATH"
Write-Host ('git on PATH : ' + (Join-Path $gitCmd 'git.exe'))
Write-Host ''

# --- VS Code user settings + keybindings (portable data dir) ---
$userDir = Join-Path $codeDir 'data\User'
New-Item -ItemType Directory -Path $userDir -Force | Out-Null

$installed = @()
foreach ($f in @('settings.json','keybindings.json','argv.json')) {
  $s = Join-Path $RepoDir $f
  if (Test-Path $s) { Copy-Item -LiteralPath $s -Destination (Join-Path $userDir $f) -Force; $installed += $f }
}
foreach ($sub in @('snippets','tasks')) {
  $s = Join-Path $RepoDir $sub
  if (Test-Path $s) {
    Copy-Item -LiteralPath $s -Destination (Join-Path $userDir $sub) -Recurse -Force
    $installed += ($sub + '/')
  }
}
Write-Host ('Config into ' + $userDir + ' : ' + $(if ($installed.Count) { $installed -join ', ' } else { '(none provided yet)' }))
Write-Host ''

# --- extensions ---
$extDir  = Join-Path $codeDir 'extensions'
New-Item -ItemType Directory -Path $extDir -Force | Out-Null
$extList = Join-Path $RepoDir 'extensions.txt'
if (Test-Path $extList) {
  $ids = @(Get-Content $extList | ForEach-Object { $_.Trim() } | Where-Object { $_ -and $_ -notmatch '^#' })
  Write-Host ('Installing {0} extension(s) into {1} ...' -f $ids.Count, $extDir)
  $cli = Get-VsCodeCli $codeDir
  foreach ($id in $ids) {
    & $cli --install-extension $id --extensionsDir $extDir --force --skip-release-notes 2>&1 | Out-Null
    if ($LASTEXITCODE -eq 0) { Write-Host ('  ok   ' + $id) } else { Write-Host ('  FAIL ' + $id + " (exit $LASTEXITCODE)") }
  }
} else {
  Write-Host 'No extensions.txt found; skipping extensions.'
}
Write-Host ''

# --- Desktop shortcut ---
try {
  $desktop = [Environment]::GetFolderPath('Desktop')
  $shell   = New-Object -ComObject WScript.Shell
  $lnk     = $shell.CreateShortcut((Join-Path $desktop 'VS Code (portable).lnk'))
  $lnk.TargetPath       = (Join-Path $codeDir 'Code.exe')
  $lnk.WorkingDirectory = $codeDir
  $lnk.Save()
  Write-Host ('Desktop shortcut : ' + $lnk.Path)
} catch {
  Write-Host ('(skipped desktop shortcut: ' + $_.Exception.Message + ')')
}

Write-Host ''
Write-Host '=== done ==='
Write-Host ('Launch VS Code :  & "' + (Join-Path $codeDir 'Code.exe') + '"')
Write-Host ('git            :  ' + (Join-Path $gitCmd 'git.exe'))
Write-Host ''
