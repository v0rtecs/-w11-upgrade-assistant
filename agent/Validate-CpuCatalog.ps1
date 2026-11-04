# Validate-CpuCatalog.ps1 - controllo offline, nessuna modifica al PC
param([string]$Path = (Join-Path $PSScriptRoot 'cpu-catalog.json'))
$ErrorActionPreference = 'Stop'
try {
  if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { throw "File non trovato: $Path" }
  $raw = Get-Content -LiteralPath $Path -Raw -Encoding UTF8
  $catalog = ConvertFrom-Json -InputObject $raw -ErrorAction Stop
  $props = @($catalog.PSObject.Properties.Name)
  foreach ($key in @('schemaVersion','catalogVersion','policy','exactCpuNames')) {
    if ($props -cnotcontains $key) { throw "Campo obbligatorio mancante: $key" }
  }
  if ($catalog.schemaVersion -isnot [int] -or $catalog.schemaVersion -ne 1) { throw 'schemaVersion deve essere il numero intero 1' }
  if ($catalog.catalogVersion -isnot [string] -or $catalog.catalogVersion -notmatch '^\d{4}-\d{2}-\d{2}-[A-Za-z0-9._-]+$') { throw 'catalogVersion deve avere forma AAAA-MM-GG-etichetta' }
  if ($catalog.policy -cne 'exact-match-only; locally reviewed; not official Microsoft certification') { throw 'policy inattesa' }
  if ($null -eq $catalog.exactCpuNames -or $catalog.exactCpuNames -isnot [array]) { throw 'exactCpuNames deve essere un array JSON' }
  $seen = New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::OrdinalIgnoreCase)
  foreach ($name in $catalog.exactCpuNames) {
    if ($name -isnot [string] -or [string]::IsNullOrWhiteSpace($name)) { throw 'Nome CPU vuoto o non testuale' }
    if ($name.Length -gt 180 -or $name -cne $name.Trim() -or $name -match '[\r\n\t]') { throw "Nome CPU malformato: $name" }
    $normalized = ($name -replace '\s+', ' ').Trim()
    if (-not $seen.Add($normalized)) { throw "Nome CPU duplicato: $name" }
  }
  Write-Output "VALIDO: $($catalog.catalogVersion) - $($seen.Count) CPU; catalogo locale, non certificazione Microsoft."
  exit 0
} catch {
  [Console]::Error.WriteLine("NON VALIDO: $($_.Exception.Message)")
  exit 1
}
