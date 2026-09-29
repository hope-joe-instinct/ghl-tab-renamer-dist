# GHL Tab Renamer installer for Windows PowerShell 5.1+
# Run once per PC; rerun the same line to update. No administrator rights needed.
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
$manifestUrl = 'https://raw.githubusercontent.com/hope-joe-instinct/ghl-tab-renamer-dist/main/update.json'
$manifest = Invoke-RestMethod -Uri $manifestUrl -UseBasicParsing
if ($manifest.version -notmatch '^\d+\.\d+\.\d+$' -or
    $manifest.asset -notmatch '^https://github\.com/hope-joe-instinct/ghl-tab-renamer-dist/releases/download/v\d+\.\d+\.\d+/GHL-Tab-Renamer-\d+\.\d+\.\d+\.zip$' -or
    $manifest.sha256 -notmatch '^[a-fA-F0-9]{64}$') {
  throw 'The update manifest has invalid fields.'
}
$folder = Join-Path $env:LOCALAPPDATA 'GHLTabRenamer'
$parent = Split-Path $folder
$zipPath = Join-Path $env:TEMP ('ghl-tab-' + [guid]::NewGuid().ToString('N') + '.zip')
$stage = Join-Path $parent ('GHLTabRenamer.stage-' + [guid]::NewGuid().ToString('N'))
$backup = Join-Path $parent ('GHLTabRenamer.backup-' + [guid]::NewGuid().ToString('N'))
$oldMoved = $false
try {
  Invoke-WebRequest -Uri $manifest.asset -OutFile $zipPath -UseBasicParsing
  $got = (Get-FileHash -Path $zipPath -Algorithm SHA256).Hash
  if ($got -ne $manifest.sha256) { throw 'Package SHA-256 mismatch; no installation was changed.' }
  Expand-Archive -LiteralPath $zipPath -DestinationPath $stage -Force
  $newManifest = Get-Content -LiteralPath (Join-Path $stage 'manifest.json') -Raw | ConvertFrom-Json
  if ($newManifest.version -ne $manifest.version -or $newManifest.name -ne 'GHL Tab Renamer' -or !$newManifest.key) {
    throw 'Package manifest is missing or does not match the update.'
  }
  if (Test-Path -LiteralPath $folder) {
    $oldManifestPath = Join-Path $folder 'manifest.json'
    if (Test-Path -LiteralPath $oldManifestPath) {
      $oldManifest = Get-Content -LiteralPath $oldManifestPath -Raw | ConvertFrom-Json
      if ($oldManifest.key -and $oldManifest.key -ne $newManifest.key) {
        throw 'The current extension has a different Chrome ID key; install stopped.'
      }
    }
    Move-Item -LiteralPath $folder -Destination $backup
    $oldMoved = $true
  }
  Move-Item -LiteralPath $stage -Destination $folder
  if ($oldMoved) { Remove-Item -LiteralPath $backup -Recurse -Force }
  Write-Host ('Installed GHL Tab Renamer v' + $manifest.version + ' to ' + $folder)
  Set-Clipboard -Value $folder
  Start-Process 'chrome://extensions' -ErrorAction SilentlyContinue
  Write-Host 'Chrome: first install: Developer mode > Load unpacked > paste the copied folder path > Select Folder.'
  Write-Host 'Existing install: click Reload on the GHL Tab Renamer card. Chrome storage and pairing remain intact.'
} catch {
  if ($oldMoved -and !(Test-Path -LiteralPath $folder) -and (Test-Path -LiteralPath $backup)) {
    Move-Item -LiteralPath $backup -Destination $folder
  }
  throw
} finally {
  if (Test-Path -LiteralPath $zipPath) { Remove-Item -LiteralPath $zipPath -Force }
  if (Test-Path -LiteralPath $stage) { Remove-Item -LiteralPath $stage -Recurse -Force }
}
