# W11 Upgrade Assistant - read-only Pre-Check v0.1
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
if (-not $anyDesk) { $warnings.Add('AnyDesk non rilevato') }
if ($rebootPending) { $warnings.Add('Riavvio già pendente') }

$status = if ($reasons.Count -gt 0) { 'BLOCCATO' } elseif ($warnings.Count -gt 0) { 'ATTENZIONE' } else { 'OK' }

$result = [ordered]@{
    schemaVersion = 1
    scannedAtUtc = (Get-Date).ToUniversalTime().ToString('o')
    status = $status
    blockers = @($reasons)
    warnings = @($warnings)
    hostName = $env:COMPUTERNAME
    manufacturer = [string]$cs.Manufacturer
    model = [string]$cs.Model
    cpu = [string]$cpu.Name
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
