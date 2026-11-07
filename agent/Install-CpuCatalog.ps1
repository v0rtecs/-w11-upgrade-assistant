# Install-CpuCatalog.ps1 - installazione locale controllata del catalogo CPU
# Eseguire con -SourcePath e -ExpectedSha256 (hash fornito da canale affidabile).
[CmdletBinding()]
param(
  [Parameter(Mandatory=$true)][string]$SourcePath,
  [Parameter(Mandatory=$true)][ValidatePattern('^[a-fA-F0-9]{64}$')][string]$ExpectedSha256,
  [string]$DestinationPath = (Join-Path $PSScriptRoot 'cpu-catalog.json')
)
$ErrorActionPreference = 'Stop'
$validator = Join-Path $PSScriptRoot 'Validate-CpuCatalog.ps1'
$destination = [IO.Path]::GetFullPath($DestinationPath)
$stage = "$destination.new"
$backup = "$destination.bak"
$hadOriginal = Test-Path -LiteralPath $destination -PathType Leaf
$backupCreated = $false
try {
  if (-not (Test-Path -LiteralPath $validator -PathType Leaf)) { throw 'Validatore assente' }
  if (-not (Test-Path -LiteralPath $SourcePath -PathType Leaf)) { throw 'Catalogo sorgente assente' }
  if (-not (Test-Path -LiteralPath (Split-Path -Parent $destination) -PathType Container)) { throw 'Cartella destinazione assente' }
  if (Test-Path -LiteralPath $stage) { throw 'File temporaneo .new gia presente: verificare manualmente' }
  if (Test-Path -LiteralPath $backup) { throw 'Backup .bak gia presente: verificare manualmente' }
  if ([IO.Path]::GetFullPath($SourcePath) -eq $destination) { throw 'Sorgente e destinazione coincidono' }
  $hash = (Get-FileHash -LiteralPath $SourcePath -Algorithm SHA256).Hash
  if ($hash -ine $ExpectedSha256) { throw 'SHA256 diverso da quello atteso: installazione annullata' }
  Copy-Item -LiteralPath $SourcePath -Destination $stage -ErrorAction Stop
  & $validator -Path $stage
  if ($LASTEXITCODE -ne 0) { throw 'Validazione del nuovo catalogo fallita' }
  if ($hadOriginal) {
    & $validator -Path $destination
    if ($LASTEXITCODE -ne 0) { throw 'Catalogo attuale non valido: intervento manuale richiesto' }
    Move-Item -LiteralPath $destination -Destination $backup -ErrorAction Stop
    $backupCreated = $true
  }
  Move-Item -LiteralPath $stage -Destination $destination -ErrorAction Stop
  & $validator -Path $destination
  if ($LASTEXITCODE -ne 0) { throw 'Verifica dopo installazione fallita' }
  Write-Output 'INSTALLATO: catalogo verificato. Backup precedente conservato come .bak.'
  exit 0
} catch {
  $reason = $_.Exception.Message
  if ($backupCreated) {
    try {
      if (Test-Path -LiteralPath $destination) { Remove-Item -LiteralPath $destination -Force }
      Move-Item -LiteralPath $backup -Destination $destination -ErrorAction Stop
      [Console]::Error.WriteLine('RIPRISTINO: catalogo precedente recuperato.')
    } catch {
      [Console]::Error.WriteLine("ERRORE CRITICO DI RIPRISTINO: $($_.Exception.Message)")
    }
  }
  [Console]::Error.WriteLine("NON INSTALLATO: $reason")
  exit 1
} finally {
  if (Test-Path -LiteralPath $stage) { Remove-Item -LiteralPath $stage -Force -ErrorAction SilentlyContinue }
}
