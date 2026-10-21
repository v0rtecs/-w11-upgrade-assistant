# W11 Upgrade Assistant - Monitor Agent installer v0.3
# Run from an elevated PowerShell prompt.
# Installs the Agent files under ProgramData and registers a SYSTEM startup task.

[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)][string]$Endpoint,
    [Parameter(Mandatory=$true)][string]$AgentKey
)

$ErrorActionPreference = 'Stop'
$InstallDir = Join-Path $env:ProgramData 'W11UpgradeAssistant'
$AgentSource = Join-Path $PSScriptRoot 'W11MonitorAgent.ps1'
$AgentTarget = Join-Path $InstallDir 'W11MonitorAgent.ps1'
$ConfigFile = Join-Path $InstallDir 'monitor-config.json'
$TaskName = 'W11 Upgrade Assistant Monitor'

function Assert-Administrator {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)
    if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        throw 'Apri PowerShell come amministratore e rilancia lo script.'
    }
}

Assert-Administrator

if (-not (Test-Path $AgentSource)) {
    throw "Agent non trovato accanto all'installer: $AgentSource"
}

if (-not [Uri]::IsWellFormedUriString($Endpoint, [UriKind]::Absolute) -or -not $Endpoint.StartsWith('https://')) {
    throw 'Endpoint non valido: deve essere un URL HTTPS assoluto.'
}

if ([string]::IsNullOrWhiteSpace($AgentKey) -or $AgentKey.Length -lt 24) {
    throw 'AgentKey troppo corta: usa una chiave casuale di almeno 24 caratteri.'
}

New-Item -ItemType Directory -Path $InstallDir -Force | Out-Null
Copy-Item -Path $AgentSource -Destination $AgentTarget -Force

[ordered]@{
    endpoint = $Endpoint
    agentKey = $AgentKey
} | ConvertTo-Json | Set-Content -Path $ConfigFile -Encoding UTF8

# Restrict the config containing the Agent key to SYSTEM and local Administrators.
& icacls.exe $ConfigFile /inheritance:r /grant:r 'SYSTEM:(F)' 'Administrators:(F)' | Out-Null
if ($LASTEXITCODE -ne 0) { throw 'Impossibile proteggere monitor-config.json con ACL Windows.' }

$action = New-ScheduledTaskAction `
    -Execute 'powershell.exe' `
    -Argument "-NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -File `"$AgentTarget`""

$trigger = New-ScheduledTaskTrigger -AtStartup
$settings = New-ScheduledTaskSettingsSet `
    -StartWhenAvailable `
    -RestartCount 5 `
    -RestartInterval (New-TimeSpan -Minutes 1) `
    -ExecutionTimeLimit ([TimeSpan]::Zero)

$principal = New-ScheduledTaskPrincipal `
    -UserId 'SYSTEM' `
    -LogonType ServiceAccount `
    -RunLevel Highest

$task = New-ScheduledTask -Action $action -Trigger $trigger -Settings $settings -Principal $principal
Register-ScheduledTask -TaskName $TaskName -InputObject $task -Force | Out-Null

# Start now: no reboot is required to verify installation.
Start-ScheduledTask -TaskName $TaskName
Start-Sleep -Seconds 2
$info = Get-ScheduledTaskInfo -TaskName $TaskName

Write-Host ''
Write-Host 'W11 Monitor Agent installato.' -ForegroundColor Green
Write-Host "Cartella: $InstallDir"
Write-Host "Attivita: $TaskName"
Write-Host "Ultimo risultato task: $($info.LastTaskResult)"
Write-Host "Log: $(Join-Path $InstallDir 'monitor-agent.log')"
Write-Host 'L Agent partira automaticamente ad ogni avvio di Windows come SYSTEM.'
