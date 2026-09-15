<#
.SYNOPSIS
  Rebuild a no-admin dev environment on a Windows VDI (which resets nightly).

.DESCRIPTION
  - Downloads portable VS Code (latest stable x64 zip) into a user folder.
  - Downloads MinGit (portable git) and puts it on PATH.
  - Copies settings.json / keybindings.json into VS Code's user folder.
  - Installs every VS Code extension listed in extensions.txt.
  - Creates a Desktop shortcut for VS Code.

  No admin rights required. Needs only PowerShell + internet.

  Settings + extensions go to VS Code's standard locations, the same ones your
  everyday `code` uses:
    settings / keybindings : %APPDATA%\Code\User
    extensions             : %USERPROFILE%\.vscode\extensions

.PARAMETER RepoDir
  Folder holding settings.json, keybindings.json, extensions.txt. Defaults to this file's folder.
.PARAMETER Root
  Where the portable VS Code and git are unpacked. Default: %USERPROFILE%\dev-tools
  Set DEVENV_ROOT (or pass -Root) to a persistent drive to skip re-downloading after a reset.
.PARAMETER VsCodeUrl
  Override the VS Code download URL (e.g. to pin a version).
.PARAMETER Force
  Re-download VS Code and git even if already present.
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
  (New-Object Net.WebClient).DownloadFile($Url, $Out)
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

# --- VS Code settings + keybindings (standard user folder) ---
$userDir = Join-Path $env:APPDATA 'Code\User'
New-Item -ItemType Directory -Path $userDir -Force | Out-Null

$installed = @()
foreach ($f in @('settings.json','keybindings.json','argv.json')) {
  $s = Join-Path $RepoDir $f
  if (Test-Path $s) { Copy-Item -LiteralPath $s -Destination (Join-Path $userDir $f) -Force; $installed += $f }
}
Write-Host ('Config into ' + $userDir + ' : ' + $(if ($installed.Count) { $installed -join ', ' } else { '(none provided yet)' }))
Write-Host ''

# --- extensions (installed to VS Code's default extensions folder, same as a plain `code --install-extension`) ---
$extList = Join-Path $RepoDir 'extensions.txt'
if (Test-Path $extList) {
  $ids = @(Get-Content $extList | ForEach-Object { $_.Trim() } | Where-Object { $_ -and $_ -notmatch '^#' })
  Write-Host ('Installing {0} extension(s)...' -f $ids.Count)
  $cli = Get-VsCodeCli $codeDir
  # The VS Code CLI prints harmless warnings to stderr; with EAP=Stop that would abort the
  # script, so relax it for these calls and judge success by the exit code instead.
  $prevEAP = $ErrorActionPreference
  $ErrorActionPreference = 'Continue'
  foreach ($id in $ids) {
    & $cli --install-extension $id --force --skip-release-notes *> $null
    if ($LASTEXITCODE -eq 0) { Write-Host ('  ok   ' + $id) } else { Write-Host ('  FAIL ' + $id + " (exit $LASTEXITCODE)") }
  }
  $ErrorActionPreference = $prevEAP
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
