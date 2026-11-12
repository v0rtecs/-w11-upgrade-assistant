# Test-CpuCatalogConcurrency.ps1 - prova isolata, nessuna modifica al catalogo operativo
[CmdletBinding()]
param([ValidateRange(10,1000)][int]$ReadCount = 200)
$ErrorActionPreference = 'Stop'
$root = Join-Path ([IO.Path]::GetTempPath()) ('cpu-concurrency-' + [guid]::NewGuid().ToString('N'))
$catalog = Join-Path $root 'cpu-catalog.json'
$source = Join-Path $root 'incoming.json'
$job = $null
try {
  New-Item -ItemType Directory -Path $root -Force | Out-Null
  $old = '{"schemaVersion":1,"catalogVersion":"2026-11-11-test","policy":"exact-match-only; locally reviewed; not official Microsoft certification","exactCpuNames":[]}'
  $new = '{"schemaVersion":1,"catalogVersion":"2026-11-12-test","policy":"exact-match-only; locally reviewed; not official Microsoft certification","exactCpuNames":[]}'
  [IO.File]::WriteAllText($catalog, $old, [Text.UTF8Encoding]::new($false))
  [IO.File]::WriteAllText($source, $new, [Text.UTF8Encoding]::new($false))
  $job = Start-Job -ArgumentList $catalog,$ReadCount -ScriptBlock {
    param($path,$count)
    $ok = 0; $missing = 0; $invalid = 0
    for ($i=0; $i -lt $count; $i++) {
      try {
        $raw = [IO.File]::ReadAllText($path)
        $obj = $raw | ConvertFrom-Json -ErrorAction Stop
        if ($obj.catalogVersion -in @('2026-11-11-test','2026-11-12-test') -and $obj.schemaVersion -eq 1) { $ok++ } else { $invalid++ }
      } catch [IO.FileNotFoundException] { $missing++ }
      catch [IO.DirectoryNotFoundException] { $missing++ }
      catch { $invalid++ }
      Start-Sleep -Milliseconds 5
    }
    [pscustomobject]@{Valid=$ok;Missing=$missing;Invalid=$invalid;Total=$count}
  }
  Start-Sleep -Milliseconds 100
  $hash = (Get-FileHash -LiteralPath $source -Algorithm SHA256).Hash
  & (Join-Path $PSScriptRoot 'Install-CpuCatalog.ps1') -SourcePath $source -ExpectedSha256 $hash -DestinationPath $catalog
  if ($LASTEXITCODE -ne 0) { throw 'Installazione di prova fallita' }
  Wait-Job $job | Out-Null
  $stats = Receive-Job $job
  $stats | Format-List | Out-String | Write-Output
  if ($stats.Total -ne $ReadCount -or $stats.Invalid -gt 0) { throw 'Letture incoerenti rilevate' }
  if (-not (Test-Path "$catalog.bak")) { throw 'Backup di prova assente' }
  Write-Output 'TEST COMPLETATO: nessuna lettura JSON incoerente osservata. Le letture mancanti sono possibili.'
  exit 0
} catch {
  [Console]::Error.WriteLine("TEST FALLITO: $($_.Exception.Message)")
  exit 1
} finally {
  if ($job) { Stop-Job $job -ErrorAction SilentlyContinue; Remove-Job $job -Force -ErrorAction SilentlyContinue }
  Remove-Item -LiteralPath $root -Recurse -Force -ErrorAction SilentlyContinue
}
