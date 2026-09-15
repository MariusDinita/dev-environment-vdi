<#
export.ps1
Capture the current VS Code settings, keybindings, and installed extensions into this repo,
then commit and push. Run it from a local clone of this repo.

Needs: git on PATH (restore.ps1 installs portable MinGit) and a GitHub token to push.

Usage:
    git clone https://github.com/MariusDinita/dev-environment-vdi
    cd dev-environment-vdi
    $env:GITHUB_TOKEN = 'ghp_yourtoken'     # a fine-grained or classic PAT with this repo's "Contents: read and write"
    .\export.ps1                             # defaults -CodeDir %USERPROFILE%\dev-tools\code
    # or, if you unpacked VS Code somewhere else:
    .\export.ps1 -CodeDir 'D:\code'
#>
[CmdletBinding()]
param(
  [string]$RepoDir = $PSScriptRoot,
  [string]$CodeDir = $env:DEVENV_ROOT
)
if (-not $CodeDir) { $CodeDir = Join-Path $env:USERPROFILE 'dev-tools\code' }

$ErrorActionPreference = 'Stop'

$userDir = Join-Path $CodeDir 'data\User'
$extDir  = Join-Path $CodeDir 'extensions'
if (-not (Test-Path $userDir)) { throw "VS Code data dir not found: $userDir (is -CodeDir right?)" }

# --- settings + keybindings ---
foreach ($f in @('settings.json','keybindings.json','argv.json')) {
  $s = Join-Path $userDir $f
  if (Test-Path $s) { Copy-Item -LiteralPath $s -Destination (Join-Path $RepoDir $f) -Force; Write-Host ('captured ' + $f) }
}

# --- extensions list ---
$cli = Join-Path $CodeDir 'bin\code.cmd'
if (-not (Test-Path $cli)) { $cli = (Join-Path $CodeDir 'Code.exe') }
try {
  $ids = @(& $cli --list-extensions --show-ids --extensionsDir $extDir 2>&1 |
          ForEach-Object { $_.Trim() } | Where-Object { $_ })
  Set-Content -LiteralPath (Join-Path $RepoDir 'extensions.txt') -Value $ids -Encoding UTF8
  Write-Host ("captured {0} extension(s)" -f $ids.Count)
} catch {
  Write-Warning ('could not list extensions: ' + $_.Exception.Message)
}

# --- commit + push ---
Write-Host ''
Push-Location $RepoDir
try {
  git add settings.json keybindings.json extensions.txt 2>&1 | Out-Null
  if ((git status --porcelain).Count -gt 0) {
    git commit -m ('update config: ' + (Get-Date -Format 'yyyy-MM-dd HH:mm')) | Out-Null
    Write-Host 'committed.'
    if ($env:GITHUB_TOKEN) {
      $remote = git remote get-url origin
      if ($remote -match '^https?://') {
        $auth = $remote -replace '^https?://', ('https://{0}@' -f $env:GITHUB_TOKEN)
        git push $auth main 2>&1 | ForEach-Object { Write-Host ('  ' + $_) }
      } else {
        Write-Host 'Remote is not https; pushing with your existing credential helper.'
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
