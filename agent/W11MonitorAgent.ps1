# W11 Upgrade Assistant - Monitor Agent prototype v0.4
# Lightweight PowerShell agent: identity + boot detection + Windows Update state/result + authenticated heartbeat.
# It does not execute updates or remote-control the PC.

$ErrorActionPreference = 'Stop'
$AgentVersion = '0.4.0'
$HeartbeatSeconds = 30
$DataDir = Join-Path $env:ProgramData 'W11UpgradeAssistant'
$IdentityFile = Join-Path $DataDir 'agent.json'
$StateFile = Join-Path $DataDir 'state.json'
$ConfigFile = Join-Path $DataDir 'monitor-config.json'
$LogFile = Join-Path $DataDir 'monitor-agent.log'

function Ensure-DataDir { if (-not (Test-Path $DataDir)) { New-Item -ItemType Directory -Path $DataDir -Force | Out-Null } }
function Write-AgentLog([string]$Message) { Ensure-DataDir; Add-Content -Path $LogFile -Value ('{0} {1}' -f (Get-Date).ToUniversalTime().ToString('o'), $Message) -Encoding UTF8 }
function Get-AgentIdentity {
    Ensure-DataDir
    if (Test-Path $IdentityFile) { return Get-Content $IdentityFile -Raw | ConvertFrom-Json }
    $identity = [ordered]@{ agentId='GG-' + ([guid]::NewGuid().ToString('N').Substring(0,8).ToUpper()); createdAt=(Get-Date).ToUniversalTime().ToString('o') }
    $identity | ConvertTo-Json | Set-Content $IdentityFile -Encoding UTF8
    return [pscustomobject]$identity
}
function Get-MonitorConfig {
    if (-not (Test-Path $ConfigFile)) { return $null }
    try { $cfg=Get-Content $ConfigFile -Raw | ConvertFrom-Json; if (-not $cfg.endpoint -or -not $cfg.agentKey) { return $null }; return $cfg } catch { return $null }
}
function Get-BootTime { (Get-CimInstance Win32_OperatingSystem).LastBootUpTime }
function Get-PreviousState { if (Test-Path $StateFile) { try { return Get-Content $StateFile -Raw | ConvertFrom-Json } catch {} }; return $null }
function Save-State([datetime]$BootTime) { [ordered]@{bootTime=$BootTime.ToUniversalTime().ToString('o');savedAt=(Get-Date).ToUniversalTime().ToString('o')} | ConvertTo-Json | Set-Content $StateFile -Encoding UTF8 }
function Get-StartupStatus([datetime]$BootTime,$PreviousState) {
    if ($null -eq $PreviousState -or -not $PreviousState.bootTime) { return 'ONLINE' }
    try { $oldBoot=[datetime]::Parse($PreviousState.bootTime).ToUniversalTime(); if ([math]::Abs(($BootTime.ToUniversalTime()-$oldBoot).TotalSeconds) -gt 5) { return 'ONLINE_AFTER_REBOOT' } } catch {}
    return 'ONLINE'
}
function Test-WindowsUpdateRebootPending { return (Test-Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired') }
function Get-LiveStatus([string]$StartupStatus) {
    if ($StartupStatus -eq 'ONLINE_AFTER_REBOOT') { return $StartupStatus }
    if (Test-WindowsUpdateRebootPending) { return 'REBOOT_PENDING' }
    return 'ONLINE'
}

# Read the Windows Update Agent history through the supported COM API.
# ResultCode: 2=Succeeded, 3=SucceededWithErrors, 4=Failed, 5=Aborted.
# We inspect completed installation operations around the current boot and report evidence,
# rather than assuming every reboot means that an update succeeded.
function Get-WindowsUpdateResult([datetime]$BootTime) {
    try {
        $session = New-Object -ComObject 'Microsoft.Update.Session'
        $searcher = $session.CreateUpdateSearcher()
        $count = $searcher.GetTotalHistoryCount()
        if ($count -le 0) { return [ordered]@{status='DA_VERIFICARE'; title=$null; resultCode=$null; dateUtc=$null} }
        $take = [Math]::Min($count, 50)
        $history = $searcher.QueryHistory(0, $take) | Where-Object { $_.Operation -eq 1 -and $_.Date }
        # Allow a generous window before boot because Windows can record completion while shutting down/restarting.
        $from = $BootTime.ToUniversalTime().AddHours(-6)
        $candidate = $history | Where-Object { $_.Date.ToUniversalTime() -ge $from } | Sort-Object Date -Descending | Select-Object -First 1
        if ($null -eq $candidate) { return [ordered]@{status='DA_VERIFICARE'; title=$null; resultCode=$null; dateUtc=$null} }
        $status = switch ([int]$candidate.ResultCode) { 2 {'UPDATE_OK'} 3 {'UPDATE_OK_CON_ERRORI'} 4 {'UPDATE_FAILED'} 5 {'UPDATE_FAILED'} default {'DA_VERIFICARE'} }
        return [ordered]@{status=$status; title=[string]$candidate.Title; resultCode=[int]$candidate.ResultCode; dateUtc=$candidate.Date.ToUniversalTime().ToString('o')}
    } catch {
        Write-AgentLog ('Windows Update history read FAILED: '+$_.Exception.Message)
        return [ordered]@{status='DA_VERIFICARE'; title=$null; resultCode=$null; dateUtc=$null}
    }
}

function New-HeartbeatPayload($Identity,[datetime]$BootTime,[string]$Status,[string]$AgentKey,$UpdateResult) {
    $os=Get-CimInstance Win32_OperatingSystem
    $p=[ordered]@{type='heartbeat';agentKey=$AgentKey;agentId=$Identity.agentId;agentVersion=$AgentVersion;hostName=$env:COMPUTERNAME;status=$Status;timestampUtc=(Get-Date).ToUniversalTime().ToString('o');bootTimeUtc=$BootTime.ToUniversalTime().ToString('o');windows=$os.Caption;build=$os.BuildNumber}
    if ($null -ne $UpdateResult) { $p.updateStatus=$UpdateResult.status; $p.updateTitle=$UpdateResult.title; $p.updateResultCode=$UpdateResult.resultCode; $p.updateDateUtc=$UpdateResult.dateUtc }
    return $p
}
function Send-Heartbeat($Payload,$Config) {
    $json=$Payload | ConvertTo-Json -Compress
    try { $response=Invoke-RestMethod -Uri $Config.endpoint -Method Post -ContentType 'application/json' -Body $json -TimeoutSec 15; if (-not $response.ok) { throw ('Backend rejected heartbeat: '+($response|ConvertTo-Json -Compress)) }; Write-AgentLog ('Heartbeat OK status='+$Payload.status); return $true }
    catch { Write-AgentLog ('Heartbeat FAILED: '+$_.Exception.Message); return $false }
}

Ensure-DataDir
$identity=Get-AgentIdentity
$bootTime=Get-BootTime
$previous=Get-PreviousState
$startupStatus=Get-StartupStatus -BootTime $bootTime -PreviousState $previous
Save-State -BootTime $bootTime
$config=Get-MonitorConfig
if ($null -eq $config) { Write-AgentLog ('Agent '+$AgentVersion+' not configured: create monitor-config.json with endpoint and agentKey.'); Write-Host "W11 Monitor Agent $AgentVersion non configurato. Vedi $ConfigFile"; exit 2 }
Write-AgentLog ('Agent started id='+$identity.agentId+' host='+$env:COMPUTERNAME+' version='+$AgentVersion)

# Evaluate update history once per new boot. The result travels with ONLINE_AFTER_REBOOT and is
# consumed only after successful delivery, exactly like the reboot event itself.
$startupUpdateResult=$null
if ($startupStatus -eq 'ONLINE_AFTER_REBOOT') { $startupUpdateResult=Get-WindowsUpdateResult -BootTime $bootTime }

while ($true) {
    $status=Get-LiveStatus -StartupStatus $startupStatus
    $updateResult=if ($status -eq 'ONLINE_AFTER_REBOOT') { $startupUpdateResult } else { $null }
    $payload=New-HeartbeatPayload -Identity $identity -BootTime $bootTime -Status $status -AgentKey $config.agentKey -UpdateResult $updateResult
    $sent=Send-Heartbeat -Payload $payload -Config $config
    if ($sent -and $startupStatus -eq 'ONLINE_AFTER_REBOOT') { $startupStatus='ONLINE'; $startupUpdateResult=$null }
    Start-Sleep -Seconds $HeartbeatSeconds
}
