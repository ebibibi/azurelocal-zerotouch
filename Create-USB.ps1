#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Creates a bootable USB drive for zero-touch Azure Local deployment.
.DESCRIPTION
    Takes a Windows Server ISO, Azure Local ISO, and this repo's scripts,
    and creates a USB drive that:
    1. Boots and auto-installs Windows Server 2025
    2. Copies Azure Local ISO and deployment scripts to C:\
    3. After first login, runs the full deployment pipeline

    If ISO paths are not provided, displays download instructions and waits
    for the user to place files before proceeding.

    USB layout (dual-partition for UEFI compatibility):
      Partition 1: FAT32  (~1GB)  - Boot files + autounattend.xml
      Partition 2: NTFS   (rest)  - install.wim + Azure Local ISO + scripts
.PARAMETER WindowsServerISO
    Path to Windows Server 2025 ISO file. If omitted, defaults to C:\ISOs\WindowsServer2025.iso
    and shows download instructions if the file is not found.
.PARAMETER AzureLocalISO
    Path to Azure Local (Azure Stack HCI) ISO file. If omitted, defaults to C:\ISOs\AzureLocal.iso
    and shows download instructions if the file is not found.
.PARAMETER USBDiskNumber
    Disk number of the USB drive (from Get-Disk). Required to prevent accidents.
.PARAMETER ConfigPath
    Path to config.ps1 with your Azure settings. If omitted, config.example.ps1 is used.
.EXAMPLE
    # Guided mode: shows download instructions, then creates USB
    .\Create-USB.ps1 -USBDiskNumber 2

.EXAMPLE
    # Direct mode: provide ISOs explicitly
    .\Create-USB.ps1 -WindowsServerISO "D:\ISOs\WinServer2025.iso" `
                     -AzureLocalISO "D:\ISOs\AzureLocal.iso" `
                     -USBDiskNumber 2
#>

[CmdletBinding()]
param(
    [string]$WindowsServerISO,
    [string]$AzureLocalISO,

    [Parameter(Mandatory)]
    [int]$USBDiskNumber,

    [string]$ConfigPath
)

$ErrorActionPreference = 'Stop'
$repoRoot = $PSScriptRoot

$defaultISODir = "C:\ISOs"
if (-not $WindowsServerISO) { $WindowsServerISO = Join-Path $defaultISODir "WindowsServer2025.iso" }
if (-not $AzureLocalISO)    { $AzureLocalISO    = Join-Path $defaultISODir "AzureLocal.iso" }

# --- ISO availability check with guided download ---
function Show-ISODownloadGuide {
    param([bool]$NeedWindowsServer, [bool]$NeedAzureLocal)

    Write-Host ""
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "  ISO Download Guide" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host ""

    if ($NeedWindowsServer) {
        Write-Host "[1] Windows Server 2025 Evaluation ISO" -ForegroundColor Yellow
        Write-Host ""
        Write-Host "    Download from Microsoft Evaluation Center:" -ForegroundColor White
        Write-Host "    https://www.microsoft.com/en-us/evalcenter/evaluate-windows-server-2025" -ForegroundColor Green
        Write-Host ""
        Write-Host "    - Select '64-bit edition' ISO download" -ForegroundColor Gray
        Write-Host "    - Registration (name/email) is required" -ForegroundColor Gray
        Write-Host "    - 180-day evaluation, no product key needed" -ForegroundColor Gray
        Write-Host ""
        Write-Host "    Save to: $WindowsServerISO" -ForegroundColor White
        Write-Host ""
    }

    if ($NeedAzureLocal) {
        Write-Host "[2] Azure Local (Azure Stack HCI) ISO" -ForegroundColor Yellow
        Write-Host ""
        Write-Host "    Download from Azure Portal:" -ForegroundColor White
        Write-Host "    https://portal.azure.com/#view/Microsoft_Azure_StackHCI/HCIGetStarted.ReactView" -ForegroundColor Green
        Write-Host ""
        Write-Host "    - Azure subscription required" -ForegroundColor Gray
        Write-Host "    - Accept the license terms, then click 'Download Azure Local'" -ForegroundColor Gray
        Write-Host "    - Select the latest version (24H2 recommended)" -ForegroundColor Gray
        Write-Host "    - English ISO is required for MSLab compatibility" -ForegroundColor Gray
        Write-Host ""
        Write-Host "    Save to: $AzureLocalISO" -ForegroundColor White
        Write-Host ""
    }

    Write-Host "========================================" -ForegroundColor Cyan
}

$needWS = -not (Test-Path $WindowsServerISO)
$needAL = -not (Test-Path $AzureLocalISO)

if ($needWS -or $needAL) {
    if (-not (Test-Path $defaultISODir)) {
        New-Item -Path $defaultISODir -ItemType Directory -Force | Out-Null
    }

    Show-ISODownloadGuide -NeedWindowsServer $needWS -NeedAzureLocal $needAL

    Write-Host "Place the ISO file(s) at the paths shown above." -ForegroundColor White
    Write-Host "Press Enter when ready (or Ctrl+C to cancel)..." -ForegroundColor Yellow
    Read-Host | Out-Null

    # Re-check after user says ready
    $errors = @()
    if (-not (Test-Path $WindowsServerISO)) {
        $errors += "Windows Server ISO not found at: $WindowsServerISO"
    }
    if (-not (Test-Path $AzureLocalISO)) {
        $errors += "Azure Local ISO not found at: $AzureLocalISO"
    }
    if ($errors.Count -gt 0) {
        foreach ($e in $errors) { Write-Error $e }
        return
    }

    Write-Host "Both ISOs found. Proceeding with USB creation." -ForegroundColor Green
    Write-Host ""
}

# --- Safety check ---
$usbDisk = Get-Disk -Number $USBDiskNumber
if ($usbDisk.BusType -ne 'USB') {
    Write-Error "Disk $USBDiskNumber is not a USB drive (BusType: $($usbDisk.BusType)). Aborting for safety."
    return
}

$usbSizeGB = [math]::Round($usbDisk.Size / 1GB, 1)
Write-Host "Target USB: Disk $USBDiskNumber - $($usbDisk.FriendlyName) ($($usbSizeGB) GB)" -ForegroundColor Yellow
Write-Host "ISOs:" -ForegroundColor Yellow
Write-Host "  Windows Server: $WindowsServerISO" -ForegroundColor Gray
Write-Host "  Azure Local:    $AzureLocalISO" -ForegroundColor Gray
Write-Host ""
Write-Host "WARNING: ALL DATA ON THIS DISK WILL BE ERASED." -ForegroundColor Red
$confirm = Read-Host "Type 'yes' to continue"
if ($confirm -ne 'yes') {
    Write-Host "Aborted." -ForegroundColor Yellow
    return
}

# --- Mount Windows Server ISO ---
Write-Host "Mounting Windows Server ISO..." -ForegroundColor Cyan
$wsISO = Mount-DiskImage -ImagePath (Resolve-Path $WindowsServerISO).Path -PassThru
$wsLetter = $null
for ($attempt = 0; $attempt -lt 10 -and -not $wsLetter; $attempt++) {
    Start-Sleep -Seconds 1
    $wsLetter = (Get-Volume -DiskImage $wsISO).DriveLetter
}
if (-not $wsLetter) { throw "Failed to get drive letter for mounted Windows Server ISO." }
$wsRoot = "$($wsLetter):\"

try {
    # --- Partition USB (FAT32 boot + NTFS data) ---
    Write-Host "Partitioning USB drive..." -ForegroundColor Cyan

    $usbDisk | Clear-Disk -RemoveData -RemoveOEM -Confirm:$false -ErrorAction SilentlyContinue
    $usbDisk | Initialize-Disk -PartitionStyle GPT -ErrorAction SilentlyContinue

    # Partition 1: FAT32 boot (1GB)
    $bootPart = New-Partition -DiskNumber $USBDiskNumber -Size 1GB -AssignDriveLetter
    Format-Volume -Partition $bootPart -FileSystem FAT32 -NewFileSystemLabel "BOOT" -Force | Out-Null
    $bootLetter = $bootPart.DriveLetter

    # Partition 2: NTFS data (remaining space)
    $dataPart = New-Partition -DiskNumber $USBDiskNumber -UseMaximumSize -AssignDriveLetter
    Format-Volume -Partition $dataPart -FileSystem NTFS -NewFileSystemLabel "ALDATA" -Force | Out-Null
    $dataLetter = $dataPart.DriveLetter

    Write-Host "  Boot: ${bootLetter}:\ (FAT32)" -ForegroundColor Gray
    Write-Host "  Data: ${dataLetter}:\ (NTFS)" -ForegroundColor Gray

    # --- Copy boot files to FAT32 partition ---
    Write-Host "Copying boot files to FAT32 partition..." -ForegroundColor Cyan

    $excludeItems = @("install.wim", "install.esd")
    robocopy "$wsRoot" "${bootLetter}:\" /E /XF $excludeItems /NFL /NDL /NJH /NJS /R:3 /W:1

    # --- Copy install.wim to NTFS partition ---
    Write-Host "Copying install.wim to NTFS partition (this may take a few minutes)..." -ForegroundColor Cyan
    $installWimPath = "$wsRoot\sources\install.wim"
    if (-not (Test-Path $installWimPath)) {
        throw "install.wim not found at $installWimPath. The ISO may use install.esd instead, which is not supported."
    }
    New-Item -Path "${dataLetter}:\sources" -ItemType Directory -Force | Out-Null
    Copy-Item -Path $installWimPath -Destination "${dataLetter}:\sources\install.wim" -Force

    # --- Copy autounattend.xml ---
    Write-Host "Adding autounattend.xml..." -ForegroundColor Cyan
    Copy-Item -Path "$repoRoot\unattend\autounattend.xml" -Destination "${bootLetter}:\autounattend.xml" -Force

    # --- Copy Azure Local ISO ---
    Write-Host "Copying Azure Local ISO (this may take several minutes)..." -ForegroundColor Cyan
    New-Item -Path "${dataLetter}:\payload\ISOs" -ItemType Directory -Force | Out-Null
    Copy-Item -Path $AzureLocalISO -Destination "${dataLetter}:\payload\ISOs\AzureLocal.iso" -Force

    # --- Copy deployment scripts ---
    Write-Host "Copying deployment scripts..." -ForegroundColor Cyan
    $payloadScripts = "${dataLetter}:\payload\azurelocal-zerotouch"
    New-Item -Path $payloadScripts -ItemType Directory -Force | Out-Null

    $filesToCopy = @(
        "Deploy-AzureLocal.ps1"
        "LabConfig.ps1"
        "config.example.ps1"
    )
    foreach ($f in $filesToCopy) {
        Copy-Item -Path "$repoRoot\$f" -Destination "$payloadScripts\$f" -Force
    }
    Copy-Item -Path "$repoRoot\scripts" -Destination "$payloadScripts\scripts" -Recurse -Force

    if ($ConfigPath -and (Test-Path $ConfigPath)) {
        Copy-Item -Path $ConfigPath -Destination "$payloadScripts\config.ps1" -Force
        Write-Host "  Included custom config.ps1" -ForegroundColor Gray
    }

    # --- Create SetupComplete.cmd ---
    Write-Host "Creating SetupComplete.cmd..." -ForegroundColor Cyan
    $setupDir = "${bootLetter}:\`$OEM`$\`$`$\Setup\Scripts"
    New-Item -Path $setupDir -ItemType Directory -Force | Out-Null

    $setupCompleteContent = @'
@echo off
REM Find the NTFS data partition (labeled ALDATA)
for %%d in (D E F G H I J K L) do (
    if exist "%%d:\payload\azurelocal-zerotouch\Deploy-AzureLocal.ps1" (
        echo Found payload on %%d:\
        xcopy "%%d:\payload\azurelocal-zerotouch" "C:\azurelocal-zerotouch\" /E /I /Y
        xcopy "%%d:\payload\ISOs" "C:\ISOs\" /E /I /Y
        echo Payload copied. Deployment will start after auto-logon.
        goto :done
    )
)
echo WARNING: Could not find payload partition.
:done
'@
    $setupCompleteContent | Set-Content -Path "$setupDir\SetupComplete.cmd" -Encoding ASCII

    Write-Host ""
    Write-Host "=== USB Creation Complete ===" -ForegroundColor Green
    Write-Host "Boot partition: ${bootLetter}:\ (FAT32, UEFI boot + autounattend.xml)" -ForegroundColor White
    Write-Host "Data partition: ${dataLetter}:\ (NTFS, install.wim + ISOs + scripts)" -ForegroundColor White
    Write-Host ""
    Write-Host "Next steps:" -ForegroundColor Yellow
    Write-Host "  1. Plug this USB into the target machine" -ForegroundColor White
    Write-Host "  2. Boot from USB (UEFI)" -ForegroundColor White
    Write-Host "  3. Windows Server installs automatically" -ForegroundColor White
    Write-Host "  4. After first login, deployment pipeline starts" -ForegroundColor White

} finally {
    $wsISO | Dismount-DiskImage
}
