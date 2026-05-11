#Requires -RunAsAdministrator
# Stage 1: Host Setup — Install Hyper-V and download MSLab

$configPath = Join-Path $PSScriptRoot "..\config.ps1"
. $configPath

# Install Hyper-V if not already installed
$hyperv = Get-WindowsFeature -Name Hyper-V -ErrorAction SilentlyContinue
if (-not $hyperv) {
    $hyperv = Get-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V -ErrorAction SilentlyContinue
}

if (-not $hyperv) {
    Write-Error "Could not detect Hyper-V status. Neither Get-WindowsFeature nor Get-WindowsOptionalFeature returned results."
    return
} elseif ((-not $hyperv.Installed) -and ($hyperv.State -ne 'Enabled')) {
    Write-Host "Installing Hyper-V..." -ForegroundColor Cyan
    if (Get-Command Install-WindowsFeature -ErrorAction SilentlyContinue) {
        Install-WindowsFeature -Name Hyper-V -IncludeManagementTools -Restart:$false
    } else {
        Enable-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V-All -NoRestart
    }
    Write-Warning "Hyper-V installed. A reboot is required. Re-run this script after reboot."
    return
} else {
    Write-Host "Hyper-V is already installed." -ForegroundColor Green
}

# Download MSLab
if (-not (Test-Path $MSLabPath)) {
    New-Item -Path $MSLabPath -ItemType Directory -Force | Out-Null
}

$mslabZip = Join-Path $env:TEMP "mslab.zip"
if (-not (Test-Path (Join-Path $MSLabPath "1_Prereq.ps1"))) {
    Write-Host "Downloading MSLab..." -ForegroundColor Cyan
    Invoke-WebRequest -Uri "https://aka.ms/mslab/download" -OutFile $mslabZip
    Expand-Archive -Path $mslabZip -DestinationPath $MSLabPath -Force
    # MSLab zip may contain a single root folder — flatten it
    $extractedRoot = Get-ChildItem -Path $MSLabPath -Directory | Select-Object -First 1
    if ($extractedRoot -and -not (Test-Path (Join-Path $MSLabPath "1_Prereq.ps1"))) {
        Get-ChildItem -Path $extractedRoot.FullName | Move-Item -Destination $MSLabPath -Force
        Remove-Item $extractedRoot.FullName -Force
    }
    Get-ChildItem -Path $MSLabPath -Recurse | Unblock-File
    Remove-Item $mslabZip -Force
    Write-Host "MSLab downloaded to $MSLabPath" -ForegroundColor Green
} else {
    Write-Host "MSLab already present at $MSLabPath" -ForegroundColor Green
}

# Ensure execution policy allows scripts
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Force -ErrorAction SilentlyContinue

# Create ISOs directory
$isosDir = "C:\ISOs"
if (-not (Test-Path $isosDir)) {
    New-Item -Path $isosDir -ItemType Directory -Force | Out-Null
    Write-Host "Created $isosDir — place your ISO files here." -ForegroundColor Yellow
}

# Validate ISO files and show download guide if missing
$needWS = -not (Test-Path $WindowsServerISOPath)
$needAL = -not (Test-Path $AzureLocalISOPath)

if ($needWS -or $needAL) {
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "  ISO Download Guide" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host ""

    if ($needWS) {
        Write-Host "[1] Windows Server 2025 Evaluation ISO" -ForegroundColor Yellow
        Write-Host "    https://www.microsoft.com/en-us/evalcenter/evaluate-windows-server-2025" -ForegroundColor Green
        Write-Host "    -> Select '64-bit edition' ISO download (registration required)" -ForegroundColor Gray
        Write-Host "    Save to: $WindowsServerISOPath" -ForegroundColor White
        Write-Host ""
    }

    if ($needAL) {
        Write-Host "[2] Azure Local (Azure Stack HCI) ISO" -ForegroundColor Yellow
        Write-Host "    https://portal.azure.com/#view/Microsoft_Azure_StackHCI/HCIGetStarted.ReactView" -ForegroundColor Green
        Write-Host "    -> Azure subscription required, accept license terms, download English ISO" -ForegroundColor Gray
        Write-Host "    Save to: $AzureLocalISOPath" -ForegroundColor White
        Write-Host ""
    }

    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Download the ISO(s) above before running Stage 2 (Hydration)." -ForegroundColor Yellow
    Write-Host "Press Enter to continue setup, or Ctrl+C to stop and download first..." -ForegroundColor Yellow
    Read-Host | Out-Null
}

Write-Host "Host setup complete." -ForegroundColor Green
