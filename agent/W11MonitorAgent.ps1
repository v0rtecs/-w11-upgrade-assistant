# W11 Upgrade Assistant - Monitor Agent prototype v0.1
# Lightweight PowerShell agent: identity + boot detection + heartbeat payload.
# It does not execute updates or remote-control the PC.

$ErrorActionPreference = 'Stop'
$AgentVersion = '0.1.0'
$HeartbeatSeconds = 30
$DataDir = Join-Path $env:ProgramData 'W11UpgradeAssistant'
$IdentityFile = Join-Path $DataDir 'agent.json'
$StateFile = Join-Path $DataDir 'state.json'

function Ensure-DataDir {
    if (-not (Test-Path $DataDir)) {
        New-Item -ItemType Directory -Path $DataDir -Force | Out-Null
    }
}

function Get-AgentIdentity {
    Ensure-DataDir
    if (Test-Path $IdentityFile) {
        return Get-Content $IdentityFile -Raw | ConvertFrom-Json
    }

    $identity = [ordered]@{
        agentId   = 'GG-' + ([guid]::NewGuid().ToString('N').Substring(0,8).ToUpper())
        createdAt = (Get-Date).ToUniversalTime().ToString('o')
    }
    $identity | ConvertTo-Json | Set-Content $IdentityFile -Encoding UTF8
    return [pscustomobject]$identity
}

function Get-BootTime {
    (Get-CimInstance Win32_OperatingSystem).LastBootUpTime
}

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
        if ([math]::Abs(($BootTime.ToUniversalTime() - $oldBoot).TotalSeconds) -gt 5) {
            return 'ONLINE_AFTER_REBOOT'
        }
    } catch { }
    return 'ONLINE'
}

function New-HeartbeatPayload($Identity, [datetime]$BootTime, [string]$Status) {
    $os = Get-CimInstance Win32_OperatingSystem
    [ordered]@{
        type         = 'heartbeat'
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

function Send-Heartbeat($Payload) {
    # v0.1 intentionally prints JSON locally. In v0.2 this function will POST
    # to the backend after the monitor endpoint/authentication contract is added.
    $Payload | ConvertTo-Json -Compress
}

Ensure-DataDir
$identity = Get-AgentIdentity
$bootTime = Get-BootTime
$previous = Get-PreviousState
$status = Get-AgentStatus -BootTime $bootTime -PreviousState $previous
Save-State -BootTime $bootTime

Write-Host "W11 Monitor Agent $AgentVersion - $($identity.agentId) - $env:COMPUTERNAME"

while ($true) {
    $payload = New-HeartbeatPayload -Identity $identity -BootTime $bootTime -Status $status
    Send-Heartbeat -Payload $payload

    # ONLINE_AFTER_REBOOT is emitted once; following heartbeats become ONLINE.
    if ($status -eq 'ONLINE_AFTER_REBOOT') { $status = 'ONLINE' }
    Start-Sleep -Seconds $HeartbeatSeconds
}
