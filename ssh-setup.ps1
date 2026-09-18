<#
ssh-setup.ps1 - install an SSH key pair + config into %USERPROFILE%\.ssh via two Notepad pastes.

Run:   powershell -File .\ssh-setup.ps1
(or paste this whole block into a Windows PowerShell window)

Step 1 opens Notepad on the private key file (id_ed25519). Paste your FULL private key
(the -----BEGIN ... PRIVATE KEY----- through -----END ...----- block), Ctrl+S, close.
It then derives the public key, locks down permissions, and prints the public key.

Step 2 opens Notepad on the config file (config). Paste your SSH config, Ctrl+S, close.
It prints the saved config back so you can check it.

WARNING - the key step is destructive:
  - It DELETES any existing id_ed25519 and id_ed25519.pub and rebuilds from what you paste.
    If the key you want to keep is already in that file, don't run this.
  - The clipboard holds one thing at a time. Copy the key right before step 1, then copy
    the config right before step 2.
  - If the key is passphrase-protected, the public-key step will prompt for the passphrase.
  - Close any open Notepad windows first. Modern Notepad is single-instance, so a second
    launch can open the file in the existing window and the wait returns early, tripping
    the empty check.
#>

$sshDir = "$env:USERPROFILE\.ssh"
New-Item -ItemType Directory -Force -Path $sshDir | Out-Null

$key  = Join-Path $sshDir 'id_ed25519'
$pub  = "$key.pub"
$conf = Join-Path $sshDir 'config'

# --- Step 1: private key ---
Remove-Item $key, $pub -Force -ErrorAction SilentlyContinue
New-Item -ItemType File -Force -Path $key | Out-Null
Write-Host "STEP 1: Notepad is open. Paste your private key, Ctrl+S, close the window."
Start-Process notepad $key -Wait

$c = Get-Content $key -Raw
if ($null -eq $c) { $c = "" }
$c = $c.Replace("`r`n", "`n").TrimEnd()

if ($c.Length -eq 0) {
  Write-Host "Key file is empty, so nothing was pasted." -ForegroundColor Red
} else {
  Set-Content -NoNewline -Encoding ascii $key ($c + "`n")
  ssh-keygen -y -f $key | Set-Content -NoNewline -Encoding ascii $pub
  icacls $key /inheritance:r /grant "$($env:USERNAME):(F)"
  Write-Host "Public key:"
  Get-Content $pub
}

# --- Step 2: config ---
New-Item -ItemType File -Force -Path $conf | Out-Null
Write-Host "STEP 2: Notepad is open for the config. If it has content, Ctrl+A first. Paste your config, Ctrl+S, close the window."
Start-Process notepad $conf -Wait
Write-Host "Saved. Current config:"
Get-Content $conf
