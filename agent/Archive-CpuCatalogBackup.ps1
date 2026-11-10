# Archive-CpuCatalogBackup.ps1 - archivia il backup dopo verifica del catalogo attivo
# Non elimina file: sposta .bak in archivio con nome univoco.
[CmdletBinding(SupportsShouldProcess=$true, ConfirmImpact='Medium')]
param(
  [string]$DestinationPath = (Join-Path $PSScriptRoot 'cpu-catalog.json'),
  [string]$ArchiveDirectory,
  [switch]$Force
)
$ErrorActionPreference = 'Stop'
$destination = [IO.Path]::GetFullPath($DestinationPath)
$backup = "$destination.bak"
$stage = "$destination.new"
$validator = Join-Path $PSScriptRoot 'Validate-CpuCatalog.ps1'
if (-not $ArchiveDirectory) { $ArchiveDirectory = Join-Path (Split-Path -Parent $destination) 'catalog-backups' }
$archiveRoot = [IO.Path]::GetFullPath($ArchiveDirectory)
if (-not (Test-Path -LiteralPath $destination -PathType Leaf)) { throw 'Catalogo attivo assente: non archiviare il backup' }
if (-not (Test-Path -LiteralPath $backup -PathType Leaf)) { throw 'Nessun backup .bak da archiviare' }
if (Test-Path -LiteralPath $stage) { throw 'Installazione forse incompleta: file .new presente' }
if (-not (Test-Path -LiteralPath $validator -PathType Leaf)) { throw 'Validatore assente' }
& $validator -Path $destination
if ($LASTEXITCODE -ne 0) { throw 'Catalogo attivo non valido: conservare il backup' }
& $validator -Path $backup
if ($LASTEXITCODE -ne 0) { throw 'Backup non valido: conservare per verifica manuale' }
$hash = (Get-FileHash -LiteralPath $backup -Algorithm SHA256).Hash.ToLowerInvariant()
$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$name = "cpu-catalog-$stamp-$($hash.Substring(0,12)).json.bak"
$target = Join-Path $archiveRoot $name
if (Test-Path -LiteralPath $target) { throw 'Archivio gia presente: riprovare piu tardi' }
if ($PSCmdlet.ShouldProcess($backup, "Archivia in $target")) {
  if (-not (Test-Path -LiteralPath $archiveRoot)) { New-Item -ItemType Directory -Path $archiveRoot -Force | Out-Null }
  Move-Item -LiteralPath $backup -Destination $target -ErrorAction Stop
  Write-Output "ARCHIVIATO: $target"
  Write-Output "SHA256: $hash"
}
