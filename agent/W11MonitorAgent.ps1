# W11 Upgrade Assistant - Monitor Agent prototype v0.2
# Lightweight PowerShell agent: identity + boot detection + authenticated heartbeat.
# It does not execute updates or remote-control the PC.

$ErrorActionPreference = 'Stop'
$AgentVersion = '0.2.0'
$HeartbeatSeconds = 30
$DataDir = Join-Path $env:ProgramData 'W11UpgradeAssistant'
$IdentityFile = Join-Path $DataDir 'agent.json'
$StateFile = Join-Path $DataDir 'state.json'
$ConfigFile = Join-Path $DataDir 'monitor-config.json'
$LogFile = Join-Path $DataDir 'monitor-agent.log'

function Ensure-DataDir {
    if (-not (Test-Path $DataDir)) { New-Item -ItemType Directory -Path $DataDir -Force | Out-Null }
}

function Write-AgentLog([string]$Message) {
    Ensure-DataDir
    $line = '{0} {1}' -f (Get-Date).ToUniversalTime().ToString('o'), $Message
    Add-Content -Path $LogFile -Value $line -Encoding UTF8
}

function Get-AgentIdentity {
    Ensure-DataDir
    if (Test-Path $IdentityFile) { return Get-Content $IdentityFile -Raw | ConvertFrom-Json }
    $identity = [ordered]@{
        agentId   = 'GG-' + ([guid]::NewGuid().ToString('N').Substring(0,8).ToUpper())
        createdAt = (Get-Date).ToUniversalTime().ToString('o')
    }
    $identity | ConvertTo-Json | Set-Content $IdentityFile -Encoding UTF8
    return [pscustomobject]$identity
}

function Get-MonitorConfig {
    if (-not (Test-Path $ConfigFile)) { return $null }
    try {
        $cfg = Get-Content $ConfigFile -Raw | ConvertFrom-Json
        if (-not $cfg.endpoint -or -not $cfg.agentKey) { return $null }
        return $cfg
    } catch { return $null }
}

function Get-BootTime { (Get-CimInstance Win32_OperatingSystem).LastBootUpTime }

function Get-PreviousState {
    if (Test-Path $StateFile) {
        try { return Get-Content $StateFile -Raw | ConvertFrom-Json } catch { }
    }
    return $null
}

function Save-State([datetime]$BootTime) {
    [ordered]@{
        bootTime = $BootTime.ToUniversalTime().ToString('o')
        savedAt  = (Get-Date).ToUniversalTime().ToString('o')
    } | ConvertTo-Json | Set-Content $StateFile -Encoding UTF8
}

function Get-AgentStatus([datetime]$BootTime, $PreviousState) {
    if ($null -eq $PreviousState -or -not $PreviousState.bootTime) { return 'ONLINE' }
    try {
        $oldBoot = [datetime]::Parse($PreviousState.bootTime).ToUniversalTime()
        if ([math]::Abs(($BootTime.ToUniversalTime() - $oldBoot).TotalSeconds) -gt 5) { return 'ONLINE_AFTER_REBOOT' }
    } catch { }
    return 'ONLINE'
}

function New-HeartbeatPayload($Identity, [datetime]$BootTime, [string]$Status, [string]$AgentKey) {
    $os = Get-CimInstance Win32_OperatingSystem
    [ordered]@{
        type         = 'heartbeat'
        agentKey     = $AgentKey
        agentId      = $Identity.agentId
        agentVersion = $AgentVersion
        hostName     = $env:COMPUTERNAME
        status       = $Status
        timestampUtc = (Get-Date).ToUniversalTime().ToString('o')
        bootTimeUtc  = $BootTime.ToUniversalTime().ToString('o')
        windows      = $os.Caption
        build        = $os.BuildNumber
    }
}

function Send-Heartbeat($Payload, $Config) {
    $json = $Payload | ConvertTo-Json -Compress
    try {
        $response = Invoke-RestMethod -Uri $Config.endpoint -Method Post -ContentType 'application/json' -Body $json -TimeoutSec 15
        if (-not $response.ok) { throw ('Backend rejected heartbeat: ' + ($response | ConvertTo-Json -Compress)) }
        Write-AgentLog ('Heartbeat OK status=' + $Payload.status)
        return $true
    } catch {
        # Network/backend failure must never stop the Agent. It simply retries at
        # the next heartbeat and leaves a local diagnostic without logging the key.
        Write-AgentLog ('Heartbeat FAILED: ' + $_.Exception.Message)
        return $false
    }
}

Ensure-DataDir
$identity = Get-AgentIdentity
$bootTime = Get-BootTime
$previous = Get-PreviousState
$status = Get-AgentStatus -BootTime $bootTime -PreviousState $previous
Save-State -BootTime $bootTime
$config = Get-MonitorConfig

if ($null -eq $config) {
    Write-AgentLog ('Agent ' + $AgentVersion + ' not configured: create monitor-config.json with endpoint and agentKey.')
    Write-Host "W11 Monitor Agent $AgentVersion non configurato. Vedi $ConfigFile"
    exit 2
}

Write-AgentLog ('Agent started id=' + $identity.agentId + ' host=' + $env:COMPUTERNAME + ' version=' + $AgentVersion)

while ($true) {
    $payload = New-HeartbeatPayload -Identity $identity -BootTime $bootTime -Status $status -AgentKey $config.agentKey
    $sent = Send-Heartbeat -Payload $payload -Config $config

    # ONLINE_AFTER_REBOOT is only consumed after a successful delivery. If the
    # network is not ready immediately after boot, we keep retrying that event.
    if ($sent -and $status -eq 'ONLINE_AFTER_REBOOT') { $status = 'ONLINE' }
    Start-Sleep -Seconds $HeartbeatSeconds
}
