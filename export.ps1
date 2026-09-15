<#
export.ps1
Capture the current VS Code settings, keybindings, and installed extensions into this repo,
then commit and push. Run it from a local clone of this repo.

Needs: git on PATH (restore.ps1 installs portable MinGit) and a GitHub token to push.

By default it reads from VS Code's standard locations:
  settings / keybindings : %APPDATA%\Code\User
  extensions             : %USERPROFILE%\.vscode\extensions

Usage:
    git clone https://github.com/MariusDinita/dev-environment-vdi
    cd dev-environment-vdi
    $env:GITHUB_TOKEN = 'github_pat_...'     # fine-grained token, Contents: read+write on this repo
    .\export.ps1
#>
[CmdletBinding()]
param(
  [string]$RepoDir   = $PSScriptRoot,
  [string]$UserDir   = (Join-Path $env:APPDATA 'Code\User'),
  [string]$ExtDir    = (Join-Path $env:USERPROFILE '.vscode\extensions'),
  [string]$VsCodeCli = ''
)
$ErrorActionPreference = 'Stop'

if (-not (Test-Path $UserDir)) { throw ("VS Code user dir not found: {0}" -f $UserDir) }

# --- settings + keybindings ---
foreach ($f in @('settings.json','keybindings.json','argv.json')) {
  $s = Join-Path $UserDir $f
  if (Test-Path $s) { Copy-Item -LiteralPath $s -Destination (Join-Path $RepoDir $f) -Force; Write-Host ('captured ' + $f) }
}

# --- extensions list ---
if (-not $VsCodeCli) {
  $candidates = @(
    (Join-Path $env:USERPROFILE 'dev-tools\code\bin\code.cmd'),
    (Join-Path $env:USERPROFILE 'dev-tools\code\Code.exe')
  )
  $VsCodeCli = @($candidates | Where-Object { Test-Path $_ })[0]
}
if ($VsCodeCli) {
  $ids = @(& $VsCodeCli --list-extensions --show-ids 2>&1 |
          ForEach-Object { $_.Trim() } | Where-Object { $_ })
  Set-Content -LiteralPath (Join-Path $RepoDir 'extensions.txt') -Value $ids -Encoding UTF8
  Write-Host ("captured {0} extension(s)" -f $ids.Count)
} else {
  Write-Warning 'Could not locate the VS Code CLI; extensions.txt not updated.'
}

# --- commit + push ---
Write-Host ''
Push-Location $RepoDir
try {
  git add settings.json keybindings.json extensions.txt 2>&1 | Out-Null
  if (@(git status --porcelain).Count -gt 0) {
    git commit -m ('update config: ' + (Get-Date -Format 'yyyy-MM-dd HH:mm')) | Out-Null
    Write-Host 'committed.'
    if ($env:GITHUB_TOKEN) {
      $remote = git remote get-url origin
      if ($remote -match '^https?://') {
        $auth = $remote -replace '^https?://', ('https://{0}@' -f $env:GITHUB_TOKEN)
        git -c credential.helper= push $auth main 2>&1 | ForEach-Object { Write-Host ('  ' + $_) }
      } else {
        git push 2>&1 | ForEach-Object { Write-Host ('  ' + $_) }
      }
    } else {
      Write-Host 'No GITHUB_TOKEN set; finish with:  git push origin main'
    }
  } else {
    Write-Host 'No changes to commit.'
  }
} finally {
  Pop-Location
}
