# Read-only boot identity probe for Windows PowerShell 5.1+
# Emits one JSON record. No installation, reboot, or Windows Update changes.
[CmdletBinding()]
param([string]$ComputerId = $env:COMPUTERNAME)
$ErrorActionPreference = 'Stop'
try {
    $os = Get-CimInstance -ClassName Win32_OperatingSystem
    $bootUtc = $os.LastBootUpTime.ToUniversalTime()
    $nowUtc = [DateTime]::UtcNow
    if ($bootUtc -gt $nowUtc.AddMinutes(2)) { throw 'Boot time is in the future' }
    $bootId = $bootUtc.ToString('yyyy-MM-ddTHH:mm:ss.fffffffZ', [Globalization.CultureInfo]::InvariantCulture)
    [pscustomobject]@{
        schema_version = 1
        computer_id = $ComputerId
        observed_at_utc = $nowUtc.ToString('o')
        boot_id = $bootId
        boot_at_utc = $bootId
        uptime_seconds = [math]::Max(0, [math]::Floor(($nowUtc - $bootUtc).TotalSeconds))
        probe_status = 'ok'
    } | ConvertTo-Json -Compress -Depth 3
} catch {
    [pscustomobject]@{
        schema_version = 1
        computer_id = $ComputerId
        observed_at_utc = [DateTime]::UtcNow.ToString('o')
        boot_id = $null
        boot_at_utc = $null
        uptime_seconds = $null
        probe_status = 'error'
        error_code = 'BOOT_PROBE_FAILED'
    } | ConvertTo-Json -Compress -Depth 3
    exit 1
}
