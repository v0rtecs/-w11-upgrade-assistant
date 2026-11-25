# Windows PowerShell 5.1+. Read-only Windows Update history probe.
[CmdletBinding()]
param([ValidateRange(1,100)][int]$Limit = 20)
$ErrorActionPreference = 'Stop'
$session = $null
$searcher = $null
$history = $null
try {
    $session = New-Object -ComObject Microsoft.Update.Session
    $searcher = $session.CreateUpdateSearcher()
    $total = $searcher.GetTotalHistoryCount()
    $items = @()
    if ($total -gt 0) {
        $history = $searcher.QueryHistory(0, [Math]::Min($Limit, $total))
        foreach ($entry in $history) {
            # Operation 1 = installation; do not confuse uninstall with install.
            if ([int]$entry.Operation -ne 1) { continue }
            $result = [int]$entry.ResultCode
            $status = switch ($result) {
                0 { 'not_started' }
                1 { 'in_progress' }
                2 { 'succeeded' }
                3 { 'succeeded_with_errors' }
                4 { 'failed' }
                5 { 'aborted' }
                default { 'unknown' }
            }
            $items += [pscustomobject]@{
                update_id = [string]$entry.UpdateIdentity.UpdateID
                revision = [int]$entry.UpdateIdentity.RevisionNumber
                recorded_at_utc = ([datetime]$entry.Date).ToUniversalTime().ToString('o')
                title = [string]$entry.Title
                result_code = $result
                status = $status
                hresult = ('0x{0:X8}' -f [int]$entry.HResult)
            }
        }
    }
    [pscustomobject]@{ schema_version = 1; probe_status = 'ok'; observed_at_utc = [datetime]::UtcNow.ToString('o'); history_total = $total; entries = @($items) } | ConvertTo-Json -Depth 5 -Compress
} catch {
    [pscustomobject]@{ schema_version = 1; probe_status = 'error'; observed_at_utc = [datetime]::UtcNow.ToString('o'); entries = @() } | ConvertTo-Json -Depth 5 -Compress
    exit 1
} finally {
    foreach ($obj in @($history,$searcher,$session)) {
        if ($null -ne $obj -and [Runtime.InteropServices.Marshal]::IsComObject($obj)) {
            [void][Runtime.InteropServices.Marshal]::ReleaseComObject($obj)
        }
    }
}
