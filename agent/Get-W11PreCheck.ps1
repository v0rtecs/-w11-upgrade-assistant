# W11 Upgrade Assistant - read-only Pre-Check v0.3
# Raccolta locale: non modifica registro, firmware, servizi o configurazione.

$ErrorActionPreference = 'SilentlyContinue'

function Get-RebootPending {
    $paths = @(
        'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired',
        'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending'
    )
    foreach ($p in $paths) { if (Test-Path $p) { return $true } }
    $sm = Get-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager' -Name PendingFileRenameOperations -ErrorAction SilentlyContinue
    return ($null -ne $sm.PendingFileRenameOperations)
}

function Get-SecureBootState {
    try { if (Confirm-SecureBootUEFI) { return 'ENABLED' } else { return 'DISABLED' } }
    catch { return 'NON_DISPONIBILE' }
}

function Get-TpmState {
    try {
        $t = Get-Tpm
        if (-not $t.TpmPresent) { return [ordered]@{present=$false;ready=$false;version=$null} }
        $ver = $null
        $wmi = Get-CimInstance -Namespace 'root\CIMV2\Security\MicrosoftTpm' -ClassName Win32_Tpm
        if ($wmi.SpecVersion) { $ver = ([string]$wmi.SpecVersion).Split(',')[0].Trim() }
        return [ordered]@{present=$true;ready=[bool]$t.TpmReady;version=$ver}
    } catch { return [ordered]@{present=$null;ready=$null;version=$null} }
}

function Get-CpuCompatibilityHint([string]$CpuName) {
    # Indicazione prudente, non certificazione Microsoft modello-per-modello.
    # Serve a evitare un falso verde: i casi non riconosciuti restano DA_VERIFICARE.
    $n = ($CpuName -replace '\(R\)|\(TM\)|®|™',' ' -replace '\s+',' ').Trim()

    if ($n -match '(?i)Intel.*Core.*i[3579][- ]?(\d{4,5})') {
        $model = $Matches[1]
        $gen = if ($model.Length -eq 5) { [int]$model.Substring(0,2) } else { [int]$model.Substring(0,1) }
        if ($gen -ge 8) { return [ordered]@{status='FAMIGLIA_COMPATIBILE'; detail="Intel Core generazione $gen"} }
        return [ordered]@{status='DA_VERIFICARE'; detail="Intel Core generazione $gen: modello da confrontare con elenco Microsoft"}
    }

    if ($n -match '(?i)AMD.*Ryzen.*[3579].*\b(\d{4})[A-Z0-9]*\b') {
        $model = [int]$Matches[1]
        if ($model -ge 3000) { return [ordered]@{status='FAMIGLIA_COMPATIBILE'; detail="AMD Ryzen serie $model"} }
        return [ordered]@{status='DA_VERIFICARE'; detail="AMD Ryzen serie $model: modello da confrontare con elenco Microsoft"}
    }

    if ($n -match '(?i)Snapdragon.*X') {
        return [ordered]@{status='FAMIGLIA_COMPATIBILE'; detail='Qualcomm Snapdragon X'}
    }

    return [ordered]@{status='DA_VERIFICARE'; detail='CPU non classificata automaticamente'}
}

function Get-CpuCatalogDecision([string]$CpuName) {
    # Catalogo locale aggiornabile indipendentemente dallo script.
    # Solo corrispondenze esatte e verificate; nessuna deduzione per generazione.
    $catalogPath = Join-Path $PSScriptRoot 'cpu-catalog.json'
    if (-not (Test-Path -LiteralPath $catalogPath)) {
        return [ordered]@{status='DA_VERIFICARE';detail='Catalogo CPU assente';catalogVersion='ASSENTE'}
    }
    try {
        $catalog = Get-Content -LiteralPath $catalogPath -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
        if ([int]$catalog.schemaVersion -ne 1 -or -not $catalog.catalogVersion -or $null -eq $catalog.exactCpuNames) {
            throw 'Schema catalogo non valido'
        }
        $name = ($CpuName -replace '\\s+', ' ').Trim()
        foreach ($entry in @($catalog.exactCpuNames)) {
            if ([string]::Equals($name, ([string]$entry -replace '\\s+', ' ').Trim(), [System.StringComparison]::OrdinalIgnoreCase)) {
                return [ordered]@{status='CATALOGO_LOCALE';detail='Corrispondenza esatta nel catalogo locale; verificare sempre requisiti Microsoft';catalogVersion=[string]$catalog.catalogVersion}
            }
        }
        return [ordered]@{status='DA_VERIFICARE';detail='CPU non presente nel catalogo locale verificato';catalogVersion=[string]$catalog.catalogVersion}
    } catch {
        return [ordered]@{status='DA_VERIFICARE';detail='Catalogo CPU non leggibile o non valido';catalogVersion='ERRORE'}
    }
}

$os = Get-CimInstance Win32_OperatingSystem
$cs = Get-CimInstance Win32_ComputerSystem
$cpu = Get-CimInstance Win32_Processor | Select-Object -First 1
$bios = Get-CimInstance Win32_BIOS
$disk = Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='C:'"
$fw = Get-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control' -Name PEFirmwareType -ErrorAction SilentlyContinue
$firmware = switch ([int]$fw.PEFirmwareType) { 2 {'UEFI'} 1 {'LEGACY'} default {'SCONOSCIUTO'} }
$systemDisk = Get-Disk | Where-Object IsSystem | Select-Object -First 1
$partitionStyle = if ($systemDisk) { [string]$systemDisk.PartitionStyle } else { 'SCONOSCIUTO' }
$tpm = Get-TpmState
$secureBoot = Get-SecureBootState
$freeGB = if ($disk) { [math]::Round($disk.FreeSpace / 1GB, 1) } else { $null }
$ramGB = [math]::Round($cs.TotalPhysicalMemory / 1GB, 1)
$anyDeskService = Get-Service -Name 'AnyDesk' -ErrorAction SilentlyContinue
$anyDeskExe = @(
    "$env:ProgramFiles\AnyDesk\AnyDesk.exe",
    "${env:ProgramFiles(x86)}\AnyDesk\AnyDesk.exe"
) | Where-Object { $_ -and (Test-Path $_) } | Select-Object -First 1
$anyDesk = [bool]($anyDeskService -or $anyDeskExe)
$rebootPending = Get-RebootPending
$cpuHint = Get-CpuCatalogDecision ([string]$cpu.Name)

$reasons = New-Object System.Collections.Generic.List[string]
$warnings = New-Object System.Collections.Generic.List[string]

if ($firmware -ne 'UEFI') { $reasons.Add('Firmware non UEFI') }
if ($partitionStyle -ne 'GPT') { $reasons.Add('Disco di sistema non GPT') }
if ($tpm.present -eq $false) { $reasons.Add('TPM non presente') }
elseif ($tpm.version -and -not $tpm.version.StartsWith('2.0')) { $reasons.Add('TPM inferiore a 2.0') }
elseif ($tpm.present -eq $null) { $warnings.Add('TPM non verificabile') }
if ($secureBoot -eq 'DISABLED') { $warnings.Add('Secure Boot disattivato') }
elseif ($secureBoot -eq 'NON_DISPONIBILE' -and $firmware -eq 'UEFI') { $warnings.Add('Secure Boot non verificabile') }
if ($freeGB -ne $null -and $freeGB -lt 30) { $reasons.Add('Meno di 30 GB liberi su C:') }
elseif ($freeGB -ne $null -and $freeGB -lt 45) { $warnings.Add('Spazio libero ridotto su C:') }
if ($ramGB -lt 4) { $reasons.Add('RAM inferiore a 4 GB') }
if ($cpuHint.status -eq 'DA_VERIFICARE') { $warnings.Add('Compatibilità CPU da verificare: ' + $cpuHint.detail) }
if (-not $anyDesk) { $warnings.Add('AnyDesk non rilevato') }
if ($rebootPending) { $warnings.Add('Riavvio già pendente') }

$status = if ($reasons.Count -gt 0) { 'BLOCCATO' } elseif ($warnings.Count -gt 0) { 'ATTENZIONE' } else { 'OK' }

$result = [ordered]@{
    schemaVersion = 3
    scannedAtUtc = (Get-Date).ToUniversalTime().ToString('o')
    status = $status
    blockers = @($reasons)
    warnings = @($warnings)
    hostName = $env:COMPUTERNAME
    manufacturer = [string]$cs.Manufacturer
    model = [string]$cs.Model
    cpu = [string]$cpu.Name
    cpuCompatibility = $cpuHint.status
    cpuCompatibilityDetail = $cpuHint.detail
    cpuCatalogVersion = $cpuHint.catalogVersion
    ramGB = $ramGB
    windows = [string]$os.Caption
    build = [string]$os.BuildNumber
    biosVersion = [string]$bios.SMBIOSBIOSVersion
    firmware = $firmware
    partitionStyle = $partitionStyle
    tpmPresent = $tpm.present
    tpmReady = $tpm.ready
    tpmVersion = $tpm.version
    secureBoot = $secureBoot
    systemDriveFreeGB = $freeGB
    anyDeskDetected = $anyDesk
    rebootPending = $rebootPending
}

$result | ConvertTo-Json -Depth 5
