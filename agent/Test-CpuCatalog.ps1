# Test automatici offline del validatore CPU; nessuna modifica a Windows.
$ErrorActionPreference = 'Stop'
$validator = Join-Path $PSScriptRoot 'Validate-CpuCatalog.ps1'
if (-not (Test-Path -LiteralPath $validator)) { throw 'Validate-CpuCatalog.ps1 non trovato' }
$folder = Join-Path ([IO.Path]::GetTempPath()) ('cpu-test-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $folder | Out-Null
$policy = 'exact-match-only; locally reviewed; not official Microsoft certification'
$cases = @(
 @{name='Catalogo vuoto valido';names=@();expected=0},
 @{name='CPU singola';names=@('Intel Core i5-8500');expected=0},
 @{name='Duplicato maiuscole';names=@('Intel Core i5-8500','intel core i5-8500');expected=1},
 @{name='Duplicato spazi';names=@('Intel Core i5-8500','Intel  Core i5-8500');expected=1},
 @{name='Nome vuoto';names=@('');expected=1}
)
$failures = 0
try {
 foreach ($case in $cases) {
  $path = Join-Path $folder 'catalog.json'
  $json = @{schemaVersion=1;catalogVersion='2026-11-06-test';policy=$policy;exactCpuNames=@($case.names)} | ConvertTo-Json -Depth 4
  [IO.File]::WriteAllText($path,$json,(New-Object Text.UTF8Encoding($false)))
  & powershell.exe -NoProfile -File $validator -Path $path *> $null
  if ($LASTEXITCODE -ne $case.expected) { Write-Output "FAIL: $($case.name)"; $failures++ }
  else { Write-Output "PASS: $($case.name)" }
 }
} finally { Remove-Item -LiteralPath $folder -Recurse -Force -ErrorAction SilentlyContinue }
if ($failures) { exit 1 }
Write-Output 'Tutti i test superati.'
exit 0
