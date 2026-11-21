# Windows PowerShell 5.1+; read-only heartbeat sender.
# Run with -ServerUrl https://monitor.example.org -TokenFile C:\ProgramData\W11Monitor\token.txt
[CmdletBinding()]
param(
 [Parameter(Mandatory=$true)][string]$ServerUrl,
 [Parameter(Mandatory=$true)][string]$TokenFile,
 [string]$ComputerId = $env:COMPUTERNAME,
 [int]$TimeoutSeconds = 10
)
$ErrorActionPreference = 'Stop'
try {
 $uri = [Uri]::new($ServerUrl.TrimEnd('/') + '/api/v1/heartbeat')
 if ($uri.Scheme -ne 'https' -and -not ($uri.Scheme -eq 'http' -and @('127.0.0.1','localhost','::1') -contains $uri.Host)) {
   throw 'Remote heartbeat requires HTTPS'
 }
 if ($TimeoutSeconds -lt 1 -or $TimeoutSeconds -gt 60) { throw 'TimeoutSeconds must be 1..60' }
 if ($ComputerId -notmatch '^[A-Za-z0-9][A-Za-z0-9._-]{0,127}$') { throw 'Invalid ComputerId' }
 $token = ([IO.File]::ReadAllText($TokenFile)).Trim()
 if ($token.Length -lt 32 -or $token.Length -gt 512) { throw 'Invalid token length' }
 $probePath = Join-Path $PSScriptRoot 'Get-W11BootIdentity.ps1'
 $probeText = & $probePath -ComputerId $ComputerId 2>$null
 if (-not $probeText) { throw 'Boot probe returned no data' }
 $payload = $probeText | ConvertFrom-Json
 if ($payload.computer_id -ne $ComputerId) { throw 'Probe identity mismatch' }
 $body = $payload | ConvertTo-Json -Compress -Depth 4
 $headers = @{ Authorization = 'Bearer ' + $token }
 $response = Invoke-RestMethod -Uri $uri.AbsoluteUri -Method Post -Headers $headers -Body ([Text.Encoding]::UTF8.GetBytes($body)) -ContentType 'application/json; charset=utf-8' -TimeoutSec $TimeoutSeconds -ErrorAction Stop
 [pscustomobject]@{ success = $true; server_status = $response.status; computer_id = $ComputerId } | ConvertTo-Json -Compress
 exit 0
} catch {
 # Deliberately omit exception details: HTTP errors may expose URLs or sensitive data.
 [pscustomobject]@{ success = $false; error_code = 'HEARTBEAT_SEND_FAILED'; computer_id = $ComputerId } | ConvertTo-Json -Compress
 exit 1
}
