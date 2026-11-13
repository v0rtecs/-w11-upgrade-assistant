# Prototipo v1.2: sostituzione atomica del catalogo CPU su Windows/NTFS.
# Non sostituisce ancora Install-CpuCatalog.ps1; testare prima in ambiente isolato.
[CmdletBinding()]
param(
  [Parameter(Mandatory)][string]$SourcePath,
  [Parameter(Mandatory)][ValidatePattern('^[0-9a-fA-F]{64}$')][string]$ExpectedSha256,
  [string]$DestinationPath = (Join-Path $PSScriptRoot 'cpu-catalog.json')
)
$ErrorActionPreference = 'Stop'
$stage = $null
try {
  if (-not $IsWindows -and $PSVersionTable.PSEdition -eq 'Core') { throw 'Richiesto Windows' }
  $validator = Join-Path $PSScriptRoot 'Validate-CpuCatalog.ps1'
  if (-not (Test-Path -LiteralPath $validator -PathType Leaf)) { throw 'Validatore mancante' }
  $source = [IO.Path]::GetFullPath($SourcePath)
  $dest = [IO.Path]::GetFullPath($DestinationPath)
  if (-not (Test-Path -LiteralPath $source -PathType Leaf)) { throw 'Sorgente mancante' }
  if (-not (Test-Path -LiteralPath $dest -PathType Leaf)) { throw 'Catalogo attuale mancante: installazione iniziale non supportata' }
  if ($source -eq $dest) { throw 'Sorgente e destinazione coincidono' }
  $backup = "$dest.bak"
  if (Test-Path -LiteralPath $backup) { throw 'Backup esistente: archiviare prima di proseguire' }
  if ((Get-FileHash -LiteralPath $source -Algorithm SHA256).Hash -ine $ExpectedSha256) { throw 'SHA-256 non corrispondente' }
  & $validator -Path $dest | Out-Null
  if ($LASTEXITCODE -ne 0) { throw 'Catalogo attuale non valido' }
  $stage = Join-Path (Split-Path -Parent $dest) ('.cpu-catalog-' + [guid]::NewGuid().ToString('N') + '.tmp')
  Copy-Item -LiteralPath $source -Destination $stage -ErrorAction Stop
  if ((Get-FileHash -LiteralPath $stage -Algorithm SHA256).Hash -ine $ExpectedSha256) { throw 'Copia temporanea alterata' }
  & $validator -Path $stage | Out-Null
  if ($LASTEXITCODE -ne 0) { throw 'Nuovo catalogo non valido' }
  # File.Replace sostituisce in un'unica operazione di filesystem e conserva il precedente nel backup.
  [IO.File]::Replace($stage, $dest, $backup)
  $stage = $null
  Write-Output 'INSTALLATO: sostituzione atomica completata; backup .bak conservato.'
  exit 0
} catch {
  [Console]::Error.WriteLine("NON INSTALLATO / VERIFICARE: $($_.Exception.Message)")
  exit 1
} finally {
  if ($stage -and (Test-Path -LiteralPath $stage)) {
    Remove-Item -LiteralPath $stage -Force -ErrorAction SilentlyContinue
  }
}
