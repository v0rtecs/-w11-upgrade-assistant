# Test-InstallCpuCatalog.ps1 - test isolati, nessuna modifica al catalogo reale
# Eseguire su Windows PowerShell 5.1 o PowerShell 7.
$ErrorActionPreference = 'Stop'
$installer = Join-Path $PSScriptRoot 'Install-CpuCatalog.ps1'
if (-not (Test-Path -LiteralPath $installer)) { throw 'Installer assente' }
$hostExe = (Get-Process -Id $PID).Path
$root = Join-Path ([IO.Path]::GetTempPath()) ("W11CatalogTests-" + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $root -Force | Out-Null
$passed = 0
$failed = 0
function Catalog([string]$version) {
  return ('{"schemaVersion":1,"catalogVersion":"' + $version + '","policy":"exact-match-only; locally reviewed; not official Microsoft certification","exactCpuNames":[]}')
}
function Run-Case([string]$name, [bool]$shouldSucceed, [string]$sourceText, [bool]$wrongHash, [bool]$existingBackup, [bool]$existingStage) {
  $dir = Join-Path $root ([guid]::NewGuid().ToString('N'))
  New-Item -ItemType Directory -Path $dir | Out-Null
  $src = Join-Path $dir 'incoming.json'
  $dst = Join-Path $dir 'cpu-catalog.json'
  $original = Catalog '2026-11-01-original'
  [IO.File]::WriteAllText($dst, $original, (New-Object Text.UTF8Encoding($false)))
  [IO.File]::WriteAllText($src, $sourceText, (New-Object Text.UTF8Encoding($false)))
  if ($existingBackup) { [IO.File]::WriteAllText("$dst.bak", 'backup da conservare') }
  if ($existingStage) { [IO.File]::WriteAllText("$dst.new", 'stage da conservare') }
  $hash = (Get-FileHash -LiteralPath $src -Algorithm SHA256).Hash
  if ($wrongHash) { $hash = '0' * 64 }
  $output = & $hostExe -NoProfile -NonInteractive -File $installer -SourcePath $src -DestinationPath $dst -ExpectedSha256 $hash 2>&1
  $exitCode = $LASTEXITCODE
  $success = ($exitCode -eq 0)
  $newText = [IO.File]::ReadAllText($dst)
  $ok = ($success -eq $shouldSucceed)
  if ($shouldSucceed) {
    $ok = $ok -and ($newText -eq $sourceText) -and (Test-Path -LiteralPath "$dst.bak") -and ([IO.File]::ReadAllText("$dst.bak") -eq $original)
  } else {
    $ok = $ok -and ($newText -eq $original)
    if ($existingBackup) { $ok = $ok -and ([IO.File]::ReadAllText("$dst.bak") -eq 'backup da conservare') }
    if ($existingStage) { $ok = $ok -and ([IO.File]::ReadAllText("$dst.new") -eq 'stage da conservare') }
  }
  if ($ok) { $script:passed++; Write-Host "PASS: $name" }
  else { $script:failed++; Write-Host "FAIL: $name (exit=$exitCode) $output" }
}
try {
  Run-Case 'installazione valida e backup' $true (Catalog '2026-11-08-new') $false $false $false
  Run-Case 'SHA256 errato: nessuna modifica' $false (Catalog '2026-11-08-new') $true $false $false
  Run-Case 'JSON non valido: nessuna modifica' $false '{broken' $false $false $false
  Run-Case 'backup esistente: non sovrascrivere' $false (Catalog '2026-11-08-new') $false $true $false
  Run-Case 'stage esistente: non sovrascrivere' $false (Catalog '2026-11-08-new') $false $false $true
  Write-Host "Risultato: $passed superati, $failed falliti."
  if ($failed -gt 0) { exit 1 }
  exit 0
} finally {
  Remove-Item -LiteralPath $root -Recurse -Force -ErrorAction SilentlyContinue
}
