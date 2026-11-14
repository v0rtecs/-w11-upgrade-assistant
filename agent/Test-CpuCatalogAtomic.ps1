# Test isolato della sostituzione atomica; non tocca il catalogo operativo.
[CmdletBinding()]
param()
$ErrorActionPreference = 'Stop'
$exe = if (Get-Command powershell.exe -ErrorAction SilentlyContinue) { 'powershell.exe' } elseif (Get-Command pwsh -ErrorAction SilentlyContinue) { 'pwsh' } else { throw 'PowerShell non trovato' }
$root = Join-Path ([IO.Path]::GetTempPath()) ('cpu-atomic-test-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $root -Force | Out-Null
$installer = Join-Path $root 'Install-CpuCatalogAtomic.ps1'
$validator = Join-Path $root 'Validate-CpuCatalog.ps1'
Copy-Item (Join-Path $PSScriptRoot 'Install-CpuCatalogAtomic.ps1') $installer
Copy-Item (Join-Path $PSScriptRoot 'Validate-CpuCatalog.ps1') $validator
$policy = 'exact-match-only; locally reviewed; not official Microsoft certification'
function New-Catalog([string]$path,[string]$version) {
  $obj = [ordered]@{ schemaVersion=1; catalogVersion=$version; policy=$policy; exactCpuNames=@() }
  $obj | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $path -Encoding UTF8
}
function Invoke-Install([string]$source,[string]$hash) {
  $output = & $exe -NoProfile -File $installer -SourcePath $source -DestinationPath $dest -ExpectedSha256 $hash 2>&1
  return @{ code=$LASTEXITCODE; output=($output | Out-String) }
}
try {
  $dest = Join-Path $root 'cpu-catalog.json'
  $source = Join-Path $root 'new.json'
  New-Catalog $dest '2026-11-01-old'
  New-Catalog $source '2026-11-14-new'
  $oldHash = (Get-FileHash $dest -Algorithm SHA256).Hash
  $newHash = (Get-FileHash $source -Algorithm SHA256).Hash
  $r = Invoke-Install $source $newHash
  if ($r.code -ne 0) { throw "Installazione valida fallita: $($r.output)" }
  if ((Get-FileHash $dest -Algorithm SHA256).Hash -ne $newHash) { throw 'Destinazione non aggiornata' }
  if ((Get-FileHash "$dest.bak" -Algorithm SHA256).Hash -ne $oldHash) { throw 'Backup diverso dal precedente' }
  Write-Output 'PASS: sostituzione valida e backup integro'
  $r = Invoke-Install $source $newHash
  if ($r.code -eq 0 -or (Get-FileHash $dest -Algorithm SHA256).Hash -ne $newHash) { throw 'Backup preesistente non bloccato' }
  Write-Output 'PASS: backup preesistente blocca la nuova installazione'
  Remove-Item "$dest.bak"
  $r = Invoke-Install $source ('0' * 64)
  if ($r.code -eq 0 -or (Get-FileHash $dest -Algorithm SHA256).Hash -ne $newHash) { throw 'Hash errato non bloccato' }
  if (Test-Path "$dest.bak") { throw 'Backup inatteso dopo hash errato' }
  Write-Output 'PASS: SHA-256 errato rifiutato senza alterazioni'
  Set-Content -LiteralPath $source -Value '{invalid json' -Encoding UTF8
  $badHash = (Get-FileHash $source -Algorithm SHA256).Hash
  $r = Invoke-Install $source $badHash
  if ($r.code -eq 0 -or (Get-FileHash $dest -Algorithm SHA256).Hash -ne $newHash) { throw 'JSON non valido non bloccato' }
  if (Test-Path "$dest.bak") { throw 'Backup inatteso dopo JSON invalido' }
  Write-Output 'PASS: JSON invalido rifiutato senza alterazioni'
  Write-Output 'RISULTATO: 4 controlli superati (solo ambiente temporaneo)'
} finally {
  Remove-Item -LiteralPath $root -Recurse -Force -ErrorAction SilentlyContinue
}
